/**
 * PraticOS Cloud Functions
 * - Firestore Triggers (OS numbering, User claims)
 * - HTTP API (Bot integration, external integrations)
 */

import * as functionsV1 from 'firebase-functions/v1';
import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

// Initialize Firebase Admin (singleton)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ============================================================================
// FIRESTORE TRIGGERS
// ============================================================================

/**
 * [V2] Order Number Assignment for Multi-Tenant Structure
 * Trigger: /companies/{companyId}/orders/{orderId}
 *
 * Uses transaction to prevent race conditions in numbering.
 */
export const firestoreUpdateTenantOSNumber = functionsV1
  .region('southamerica-east1')
  .firestore.document('companies/{companyId}/orders/{orderId}')
  .onCreate(async (snapshot: FirebaseFirestore.DocumentSnapshot, context: functionsV1.EventContext) => {
    const data = snapshot.data();
    if (!data || data.number) return;

    const companyId = context.params.companyId;
    const companyRef = db.collection('companies').doc(companyId);
    const orderRef = snapshot.ref;

    await db.runTransaction(async (transaction) => {
      const companyDoc = await transaction.get(companyRef);

      if (!companyDoc.exists) {
        console.error(`Company ${companyId} not found.`);
        return;
      }

      const companyData = companyDoc.data();
      const currentNumber = companyData?.nextOrderNumber || 1;

      transaction.update(orderRef, { number: currentNumber });
      transaction.update(companyRef, { nextOrderNumber: currentNumber + 1 });

      console.log(`OS #${currentNumber} assigned to order ${orderRef.id} of company ${companyId}`);
    });
  });

/**
 * [GLOBAL] Custom Claims Management
 * Trigger: /users/{userId}
 *
 * Updates authentication claims (companies, roles) whenever user is modified.
 * Essential for Security Rules of the multi-tenant structure.
 */
export const updateUserClaims = functionsV1
  .region('southamerica-east1')
  .firestore.document('users/{userId}')
  .onWrite(async (change: functionsV1.Change<FirebaseFirestore.DocumentSnapshot>, context: functionsV1.EventContext) => {
    const userId = context.params.userId;

    // If user was deleted, remove claims
    if (!change.after.exists) {
      console.log(`User ${userId} deleted, removing claims.`);
      return admin.auth().setCustomUserClaims(userId, null);
    }

    const userData = change.after.data();

    // Build roles map from companies array
    const roles: Record<string, string> = {};
    const seenCompanies = new Set<string>();

    if (userData?.companies && Array.isArray(userData.companies)) {
      userData.companies.forEach((item: { company?: { id?: string }; role?: string }) => {
        if (item.company?.id && item.role) {
          const companyId = item.company.id;

          // Detect and ignore duplicates
          if (seenCompanies.has(companyId)) {
            console.warn(`[Claims] Duplicate company detected for user ${userId}: ${companyId}. Ignoring duplicate entry.`);
            return;
          }

          seenCompanies.add(companyId);
          roles[companyId] = String(item.role).toLowerCase();
        }
      });
    }

    const claims = { roles };

    console.log(`Updating claims for user ${userId}:`, JSON.stringify(claims));

    try {
      await admin.auth().setCustomUserClaims(userId, claims);
      console.log(`Claims updated successfully for ${userId}`);
    } catch (error) {
      console.error(`Error updating claims for ${userId}:`, error);
    }
  });

// ============================================================================
// HTTP API (Express)
// ============================================================================

// Middleware
import { apiKeyAuth, botAuth, bearerAuth } from './middleware/auth.middleware';
import { resolveCompanyContext } from './middleware/company.middleware';

// Routes - API Core v1
import authRoutes from './routes/v1/auth.routes';
import ordersRoutes from './routes/v1/orders.routes';
import customersRoutes from './routes/v1/customers.routes';
import devicesRoutes from './routes/v1/devices.routes';
import servicesRoutes from './routes/v1/services.routes';
import productsRoutes from './routes/v1/products.routes';
import companyRoutes from './routes/v1/company.routes';
import analyticsRoutes from './routes/v1/analytics.routes';

// Routes - API Bot
import linkRoutes from './routes/bot/link.routes';
import inviteRoutes from './routes/bot/invite.routes';
import searchRoutes from './routes/bot/search.routes';
import summaryRoutes from './routes/bot/summary.routes';
import botOrdersRoutes from './routes/bot/orders.routes';
import botOrdersManagementRoutes from './routes/bot/orders-management.routes';
import botAnalyticsRoutes from './routes/bot/analytics.routes';
import botCatalogRoutes from './routes/bot/catalog.routes';
import botPhotosRoutes from './routes/bot/photos.routes';
import botUnifiedSearchRoutes from './routes/bot/unified-search.routes';
import botEntitiesRoutes from './routes/bot/entities.routes';

// Initialize Express app
const app = express();

// CORS configuration
app.use(cors({
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key', 'X-API-Secret', 'X-WhatsApp-Number'],
  credentials: true,
}));

// Parse JSON bodies (larger limit for base64 image uploads)
app.use(express.json({ limit: '15mb' }));

// Parse URL-encoded bodies
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// Request logging (Moved after body parsers to ensure body is captured)
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();
  const timestamp = new Date().toISOString();
  
  // Log request
  console.log(`\n--- [${timestamp}] INCOMING REQUEST ---`);
  console.log(`${req.method} ${req.path}`);
  console.log(`HEADERS:`, JSON.stringify({
    'x-api-key': req.headers['x-api-key'],
    'x-api-secret': req.headers['x-api-secret'],
    'x-whatsapp-number': req.headers['x-whatsapp-number'],
    'authorization': req.headers['authorization'] ? 'Bearer [HIDDEN]' : undefined,
    'content-type': req.headers['content-type']
  }, null, 2));
  if (Object.keys(req.query).length) console.log(`QUERY:`, JSON.stringify(req.query, null, 2));
  if (req.body && Object.keys(req.body).length) console.log(`BODY:`, JSON.stringify(req.body, null, 2));
  
  // Capture the original send to log response
  const originalSend = res.send;
  res.send = function(body): Response {
    const duration = Date.now() - start;
    console.log(`--- [${timestamp}] RESPONSE (${duration}ms) ---`);
    console.log(`STATUS: ${res.statusCode}`);
    console.log(`RESULT:`, typeof body === 'string' ? body : JSON.stringify(body, null, 2));
    console.log(`---------------------------------------\n`);
    return originalSend.call(this, body);
  };

  next();
});

// Rate limiter for API Core
const apiCoreLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later',
    },
  },
  keyGenerator: (req: Request) => {
    return req.headers['x-api-key'] as string || req.ip || 'unknown';
  },
});

// Rate limiter for Bot API
const botLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later',
    },
  },
  keyGenerator: (req: Request) => {
    return req.headers['x-whatsapp-number'] as string || req.ip || 'unknown';
  },
});

// Health Check
app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// API Core v1 Routes
app.use('/v1/auth', authRoutes);
app.use('/v1/orders', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, ordersRoutes);
app.use('/v1/customers', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, customersRoutes);
app.use('/v1/devices', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, devicesRoutes);
app.use('/v1/services', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, servicesRoutes);
app.use('/v1/products', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, productsRoutes);
app.use('/v1/company', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, companyRoutes);
app.use('/v1/analytics', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, analyticsRoutes);

// Bearer token routes (for Flutter app)
app.use('/v1/app/orders', apiCoreLimiter, bearerAuth, resolveCompanyContext, ordersRoutes);
app.use('/v1/app/customers', apiCoreLimiter, bearerAuth, resolveCompanyContext, customersRoutes);
app.use('/v1/app/devices', apiCoreLimiter, bearerAuth, resolveCompanyContext, devicesRoutes);

// API Bot Routes
app.use('/bot/link', botLimiter, botAuth, linkRoutes);
app.use('/bot/invite', botLimiter, botAuth, inviteRoutes);
app.use('/bot/customers', botLimiter, botAuth, searchRoutes);
app.use('/bot/devices', botLimiter, botAuth, searchRoutes);
app.use('/bot/orders', botLimiter, botAuth, botOrdersRoutes);
app.use('/bot/orders', botLimiter, botAuth, botOrdersManagementRoutes);
app.use('/bot/orders', botLimiter, botAuth, botPhotosRoutes);
app.use('/bot/summary', botLimiter, botAuth, summaryRoutes);
app.use('/bot/analytics', botLimiter, botAuth, botAnalyticsRoutes);
app.use('/bot/catalog', botLimiter, botAuth, botCatalogRoutes);
app.use('/bot/search', botLimiter, botAuth, botUnifiedSearchRoutes);
app.use('/bot', botLimiter, botAuth, botEntitiesRoutes);

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: 'Endpoint not found',
    },
  });
});

// Global error handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Unhandled error:', err);

  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: err.message,
      },
    });
  }

  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Invalid or missing authentication',
      },
    });
  }

  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: process.env.NODE_ENV === 'development'
        ? err.message
        : 'An unexpected error occurred',
    },
  });
});

// Export HTTP API function
export const api = onRequest(
  {
    region: 'southamerica-east1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 100,
  },
  app
);
