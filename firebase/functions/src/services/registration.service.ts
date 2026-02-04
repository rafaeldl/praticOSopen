/**
 * Registration Service
 * Manages self-registration flow for new users via WhatsApp (RG_ tokens)
 *
 * Flow:
 * 1. User starts registration -> creates RG_ token
 * 2. User provides company name -> updates state
 * 3. User selects segment -> updates state
 * 4. User selects subspecialties (if applicable) -> updates state
 * 5. User chooses bootstrap option -> updates state
 * 6. User confirms -> completes registration (creates user, company, links)
 */

import { v4 as uuidv4 } from 'uuid';
import {
  db,
  auth,
} from './firestore.service';
import {
  RoleType,
  UserAggr,
  CompanyAggr,
} from '../models/types';
import * as channelLinkService from './channel-link.service';
import { addCompanyToUserDoc } from './invite.service';
import { executeServerBootstrap } from './bootstrap-server.service';

// Token expiration time (24 hours)
const REGISTRATION_TOKEN_EXPIRATION = 24 * 60 * 60 * 1000;

// Rate limit: max registrations per phone per day
const MAX_REGISTRATIONS_PER_DAY = 3;

// ============================================================================
// Types
// ============================================================================

export type RegistrationState =
  | 'started'
  | 'awaiting_company_name'
  | 'awaiting_segment'
  | 'awaiting_subspecialties'
  | 'awaiting_bootstrap'
  | 'awaiting_confirm'
  | 'completed'
  | 'cancelled';

export interface RegistrationData {
  companyName?: string;
  segmentId?: string;
  subspecialties?: string[];
  includeBootstrap?: boolean;
  locale?: string;
}

export interface RegistrationToken {
  token: string;
  whatsappNumber: string;
  state: RegistrationState;
  data: RegistrationData;
  createdAt: string;
  expiresAt: string;
  completedAt?: string;
  userId?: string;
  companyId?: string;
}

export interface Segment {
  id: string;
  name: string;
  icon?: string;
  active: boolean;
  nameI18n?: Record<string, string>;
  subspecialties?: Subspecialty[];
}

export interface Subspecialty {
  id: string;
  name: string;
  nameI18n?: Record<string, string>;
}

export interface CreateRegistrationResult {
  success: true;
  token: string;
  segments: Segment[];
}

export interface CompleteRegistrationResult {
  success: true;
  userId: string;
  userName: string;
  companyId: string;
  companyName: string;
  bootstrapResult?: {
    servicesCreated: number;
    productsCreated: number;
    customersCreated: number;
  };
}

export interface RegistrationError {
  success: false;
  error: string;
  code: string;
}

// ============================================================================
// Token Generation
// ============================================================================

/**
 * Generate a unique registration token
 * Format: RG_ + UUID (no dashes)
 */
function generateToken(): string {
  return `RG_${uuidv4().replace(/-/g, '')}`;
}

/**
 * Get reference to registrations collection
 */
function getRegistrationsCollection() {
  return db.collection('links').doc('registrations').collection('tokens');
}

/**
 * Normalize phone number to E.164 format
 */
function normalizePhone(phone: string): string {
  let normalized = phone.replace(/[^\d+]/g, '');
  if (!normalized.startsWith('+')) {
    normalized = '+' + normalized;
  }
  return normalized;
}

// ============================================================================
// Rate Limiting
// ============================================================================

/**
 * Check if phone has exceeded registration attempts
 */
async function checkRateLimit(phone: string): Promise<boolean> {
  const normalizedPhone = normalizePhone(phone);
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const snapshot = await getRegistrationsCollection()
    .where('whatsappNumber', '==', normalizedPhone)
    .where('createdAt', '>=', oneDayAgo)
    .get();

  return snapshot.size < MAX_REGISTRATIONS_PER_DAY;
}

// ============================================================================
// Registration Operations
// ============================================================================

/**
 * Start a new registration
 * Creates RG_ token and returns list of available segments
 */
export async function startRegistration(
  whatsappNumber: string,
  locale?: string
): Promise<CreateRegistrationResult | RegistrationError> {
  const normalizedPhone = normalizePhone(whatsappNumber);

  // Check if phone is already linked
  const existingLink = await channelLinkService.getWhatsAppLink(normalizedPhone);
  if (existingLink) {
    return {
      success: false,
      error: 'This WhatsApp number is already linked to an account',
      code: 'ALREADY_LINKED',
    };
  }

  // Check rate limit
  const withinLimit = await checkRateLimit(normalizedPhone);
  if (!withinLimit) {
    return {
      success: false,
      error: 'Too many registration attempts. Please try again later.',
      code: 'RATE_LIMIT_EXCEEDED',
    };
  }

  // Check for existing active registration
  const existingReg = await getActiveByPhone(normalizedPhone);
  if (existingReg) {
    // Return existing registration with segments
    const segments = await getActiveSegments();
    return {
      success: true,
      token: existingReg.token,
      segments,
    };
  }

  // Generate token
  const token = generateToken();
  const expiresAt = new Date(Date.now() + REGISTRATION_TOKEN_EXPIRATION);

  const registrationData: RegistrationToken = {
    token,
    whatsappNumber: normalizedPhone,
    state: 'awaiting_company_name',
    data: {
      locale: locale || 'pt-BR',
    },
    createdAt: new Date().toISOString(),
    expiresAt: expiresAt.toISOString(),
  };

  await getRegistrationsCollection().doc(token).set(registrationData);

  // Fetch segments
  const segments = await getActiveSegments();

  console.log(`[REGISTRATION] Started for ${normalizedPhone}: ${token}`);

  return {
    success: true,
    token,
    segments,
  };
}

/**
 * Get active registration by phone number
 */
export async function getActiveByPhone(
  whatsappNumber: string
): Promise<RegistrationToken | null> {
  const normalizedPhone = normalizePhone(whatsappNumber);

  const snapshot = await getRegistrationsCollection()
    .where('whatsappNumber', '==', normalizedPhone)
    .where('state', 'not-in', ['completed', 'cancelled'])
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const data = snapshot.docs[0].data() as RegistrationToken;

  // Check if expired
  if (new Date(data.expiresAt) < new Date()) {
    // Mark as cancelled
    await snapshot.docs[0].ref.update({ state: 'cancelled' });
    return null;
  }

  return data;
}

/**
 * Get registration by token
 */
export async function getByToken(
  token: string
): Promise<RegistrationToken | null> {
  const doc = await getRegistrationsCollection().doc(token).get();
  if (!doc.exists) return null;

  const data = doc.data() as RegistrationToken;

  // Check if expired
  if (new Date(data.expiresAt) < new Date()) {
    await doc.ref.update({ state: 'cancelled' });
    return null;
  }

  return data;
}

/**
 * Update registration state and data
 */
export async function updateRegistration(
  token: string,
  updates: {
    state?: RegistrationState;
    data?: Partial<RegistrationData>;
  }
): Promise<RegistrationToken | RegistrationError> {
  const registration = await getByToken(token);

  if (!registration) {
    return {
      success: false,
      error: 'Registration not found or expired',
      code: 'NOT_FOUND',
    };
  }

  if (registration.state === 'completed' || registration.state === 'cancelled') {
    return {
      success: false,
      error: 'Registration is no longer active',
      code: 'INACTIVE',
    };
  }

  const updateData: Record<string, unknown> = {};

  if (updates.state) {
    updateData.state = updates.state;
  }

  if (updates.data) {
    // Merge data
    updateData.data = {
      ...registration.data,
      ...updates.data,
    };
  }

  await getRegistrationsCollection().doc(token).update(updateData);

  console.log(`[REGISTRATION] Updated ${token}: state=${updates.state || registration.state}`);

  // Return updated registration
  return (await getByToken(token)) as RegistrationToken;
}

/**
 * Complete registration - creates user, company, and links
 */
export async function completeRegistration(
  token: string
): Promise<CompleteRegistrationResult | RegistrationError> {
  const registration = await getByToken(token);

  if (!registration) {
    return {
      success: false,
      error: 'Registration not found or expired',
      code: 'NOT_FOUND',
    };
  }

  if (registration.state !== 'awaiting_confirm') {
    return {
      success: false,
      error: 'Registration is not ready for completion',
      code: 'INVALID_STATE',
    };
  }

  const { companyName, segmentId, subspecialties, includeBootstrap, locale } = registration.data;

  if (!companyName) {
    return {
      success: false,
      error: 'Company name is required',
      code: 'MISSING_DATA',
    };
  }

  console.log(`[REGISTRATION] Completing registration for ${registration.whatsappNumber}`);

  try {
    // Create user in Firebase Auth
    const userRecord = await auth.createUser({
      phoneNumber: registration.whatsappNumber,
      displayName: companyName, // Use company name as display name initially
    });

    const userId = userRecord.uid;
    const userName = companyName;

    // Create user document
    await db.collection('users').doc(userId).set({
      id: userId,
      name: userName,
      phone: registration.whatsappNumber,
      createdAt: new Date().toISOString(),
      createdVia: 'whatsapp_self_registration',
      companies: [],
    });

    const userAggr: UserAggr = {
      id: userId,
      name: userName,
    };

    // Create company
    const companyRef = db.collection('companies').doc();
    const companyId = companyRef.id;

    const companyData: Record<string, unknown> = {
      id: companyId,
      name: companyName,
      owner: userAggr,
      users: [],
      segment: segmentId || 'other',
      subspecialties: subspecialties || [],
      country: locale?.split('-')[1] || 'BR',
      nextOrderNumber: 1,
      createdAt: new Date().toISOString(),
      createdBy: userAggr,
      updatedAt: new Date().toISOString(),
      updatedBy: userAggr,
    };

    await companyRef.set(companyData);

    const companyAggr: CompanyAggr = {
      id: companyId,
      name: companyName,
      country: companyData.country as string,
    };

    // Add company to user's companies array
    await addCompanyToUserDoc(userId, { id: companyId, name: companyName }, 'owner');

    // Link WhatsApp
    await channelLinkService.linkWhatsApp(
      registration.whatsappNumber,
      userId,
      companyId,
      'owner' as RoleType,
      userName,
      companyName
    );

    // Execute bootstrap if requested
    let bootstrapResult;
    if (includeBootstrap && segmentId) {
      try {
        const result = await executeServerBootstrap({
          companyId,
          segmentId,
          subspecialties: subspecialties || [],
          userAggr,
          companyAggr,
          locale: locale || 'pt-BR',
        });

        bootstrapResult = {
          servicesCreated: result.createdServices.length,
          productsCreated: result.createdProducts.length,
          customersCreated: result.createdCustomers.length,
        };

        console.log(`[REGISTRATION] Bootstrap completed: ${JSON.stringify(bootstrapResult)}`);
      } catch (bootstrapError) {
        console.error('[REGISTRATION] Bootstrap error (non-fatal):', bootstrapError);
        // Continue even if bootstrap fails - user can add data later
      }
    }

    // Mark registration as completed
    await getRegistrationsCollection().doc(token).update({
      state: 'completed',
      completedAt: new Date().toISOString(),
      userId,
      companyId,
    });

    console.log(`[REGISTRATION] Completed: user=${userId}, company=${companyId}`);

    return {
      success: true,
      userId,
      userName,
      companyId,
      companyName,
      bootstrapResult,
    };
  } catch (error) {
    console.error('[REGISTRATION] Error completing registration:', error);

    // If Auth user was created, try to clean up
    // (We don't have the uid here if it failed partway through)

    return {
      success: false,
      error: 'Failed to complete registration. Please try again.',
      code: 'INTERNAL_ERROR',
    };
  }
}

/**
 * Cancel registration
 */
export async function cancelRegistration(
  token: string
): Promise<boolean> {
  const registration = await getByToken(token);

  if (!registration) return false;

  if (registration.state === 'completed') {
    return false; // Cannot cancel completed registrations
  }

  await getRegistrationsCollection().doc(token).update({
    state: 'cancelled',
  });

  console.log(`[REGISTRATION] Cancelled: ${token}`);
  return true;
}

/**
 * Cancel registration by phone
 */
export async function cancelRegistrationByPhone(
  whatsappNumber: string
): Promise<boolean> {
  const registration = await getActiveByPhone(whatsappNumber);
  if (!registration) return false;

  return cancelRegistration(registration.token);
}

// ============================================================================
// Segment Operations
// ============================================================================

/**
 * Get all active segments
 */
export async function getActiveSegments(): Promise<Segment[]> {
  const snapshot = await db
    .collection('segments')
    .where('active', '==', true)
    .orderBy('name')
    .get();

  return snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name,
      icon: data.icon,
      active: data.active,
      nameI18n: data.nameI18n,
      subspecialties: data.subspecialties,
    };
  });
}

/**
 * Get segment by ID
 */
export async function getSegmentById(segmentId: string): Promise<Segment | null> {
  const doc = await db.collection('segments').doc(segmentId).get();

  if (!doc.exists) return null;

  const data = doc.data()!;
  return {
    id: doc.id,
    name: data.name,
    icon: data.icon,
    active: data.active,
    nameI18n: data.nameI18n,
    subspecialties: data.subspecialties,
  };
}

/**
 * Get localized segment name
 */
export function getLocalizedName(
  item: { name: string; nameI18n?: Record<string, string> },
  locale: string
): string {
  if (item.nameI18n) {
    // Try exact match
    if (item.nameI18n[locale]) {
      return item.nameI18n[locale];
    }

    // Try language only (pt from pt-BR)
    const langCode = locale.split('-')[0];
    const fallbackKey = Object.keys(item.nameI18n).find((key) =>
      key.startsWith(langCode)
    );

    if (fallbackKey && item.nameI18n[fallbackKey]) {
      return item.nameI18n[fallbackKey];
    }

    // Try pt-BR as final fallback
    if (item.nameI18n['pt-BR']) {
      return item.nameI18n['pt-BR'];
    }
  }

  return item.name;
}
