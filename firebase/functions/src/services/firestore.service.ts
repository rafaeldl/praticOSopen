/**
 * Firestore Service
 * Base service for Firestore operations with multi-tenant support
 */

import * as admin from 'firebase-admin';
import { getFirestore, Timestamp as FirestoreTimestamp, FieldValue as FirestoreFieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

// Initialize Firebase Admin (singleton)
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = getFirestore();
export const auth = getAuth();

// Re-export Timestamp and FieldValue from the modular SDK
export const Timestamp = FirestoreTimestamp;
export const FieldValue = FirestoreFieldValue;

// ============================================================================
// Collection References
// ============================================================================

/**
 * Get reference to a tenant subcollection
 */
export function getTenantCollection(companyId: string, collection: string) {
  return db.collection('companies').doc(companyId).collection(collection);
}

/**
 * Get reference to a root collection
 */
export function getRootCollection(collection: string) {
  return db.collection(collection);
}

// ============================================================================
// Query Helpers
// ============================================================================

export interface QueryOptions {
  limit?: number;
  offset?: number;
  orderBy?: string;
  orderDirection?: 'asc' | 'desc';
  filters?: QueryFilter[];
}

export interface QueryFilter {
  field: string;
  operator: FirebaseFirestore.WhereFilterOp;
  value: unknown;
}

/**
 * Execute a paginated query on a collection
 */
export async function paginatedQuery<T>(
  collectionRef: FirebaseFirestore.CollectionReference,
  options: QueryOptions = {}
): Promise<{ data: T[]; total: number; hasMore: boolean }> {
  const { limit = 20, offset = 0, orderBy = 'createdAt', orderDirection = 'desc', filters = [] } = options;

  // Build query
  let query: FirebaseFirestore.Query = collectionRef;

  // Apply filters
  for (const filter of filters) {
    query = query.where(filter.field, filter.operator, filter.value);
  }

  // Get total count (without pagination)
  const countSnapshot = await query.count().get();
  const total = countSnapshot.data().count;

  // Apply ordering and pagination
  query = query.orderBy(orderBy, orderDirection);

  if (offset > 0) {
    // Get the document at offset position for cursor-based pagination
    const offsetSnapshot = await query.limit(offset).get();
    if (!offsetSnapshot.empty) {
      const lastDoc = offsetSnapshot.docs[offsetSnapshot.docs.length - 1];
      query = query.startAfter(lastDoc);
    }
  }

  query = query.limit(limit);

  // Execute query
  const snapshot = await query.get();
  const data = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as T[];

  return {
    data,
    total,
    hasMore: offset + data.length < total,
  };
}

/**
 * Get a single document by ID
 */
export async function getDocument<T>(
  collectionRef: FirebaseFirestore.CollectionReference,
  id: string
): Promise<T | null> {
  const doc = await collectionRef.doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() } as T;
}

/**
 * Create a document with auto-generated ID
 */
export async function createDocument<T extends Record<string, unknown>>(
  collectionRef: FirebaseFirestore.CollectionReference,
  data: T
): Promise<string> {
  const docRef = await collectionRef.add({
    ...data,
    createdAt: Timestamp.now(),
  });
  return docRef.id;
}

/**
 * Create a document with a specific ID
 */
export async function setDocument<T extends Record<string, unknown>>(
  collectionRef: FirebaseFirestore.CollectionReference,
  id: string,
  data: T
): Promise<void> {
  await collectionRef.doc(id).set({
    ...data,
    createdAt: Timestamp.now(),
  });
}

/**
 * Update a document
 */
export async function updateDocument<T extends Record<string, unknown>>(
  collectionRef: FirebaseFirestore.CollectionReference,
  id: string,
  data: Partial<T>
): Promise<void> {
  await collectionRef.doc(id).update({
    ...data,
    updatedAt: Timestamp.now(),
  });
}

/**
 * Delete a document
 */
export async function deleteDocument(
  collectionRef: FirebaseFirestore.CollectionReference,
  id: string
): Promise<void> {
  await collectionRef.doc(id).delete();
}

// ============================================================================
// Search Helpers
// ============================================================================

/**
 * Search by prefix (for autocomplete)
 */
export async function searchByPrefix<T>(
  collectionRef: FirebaseFirestore.CollectionReference,
  field: string,
  prefix: string,
  limit = 10
): Promise<T[]> {
  const normalizedPrefix = prefix.toLowerCase();
  const endPrefix = normalizedPrefix + '\uf8ff';

  const snapshot = await collectionRef
    .where(field, '>=', normalizedPrefix)
    .where(field, '<=', endPrefix)
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as T[];
}

/**
 * Find document by exact field match
 */
export async function findByField<T>(
  collectionRef: FirebaseFirestore.CollectionReference,
  field: string,
  value: unknown
): Promise<T | null> {
  const snapshot = await collectionRef
    .where(field, '==', value)
    .limit(1)
    .get();

  if (snapshot.empty) return null;
  const doc = snapshot.docs[0];
  return { id: doc.id, ...doc.data() } as T;
}

/**
 * Find all documents by field match
 */
export async function findAllByField<T>(
  collectionRef: FirebaseFirestore.CollectionReference,
  field: string,
  value: unknown
): Promise<T[]> {
  const snapshot = await collectionRef
    .where(field, '==', value)
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as T[];
}

// ============================================================================
// Transaction Helpers
// ============================================================================

/**
 * Run a transaction
 */
export async function runTransaction<T>(
  updateFunction: (transaction: FirebaseFirestore.Transaction) => Promise<T>
): Promise<T> {
  return db.runTransaction(updateFunction);
}

/**
 * Get next sequential number for orders
 */
export async function getNextOrderNumber(companyId: string): Promise<number> {
  const counterRef = db.collection('companies').doc(companyId);

  return runTransaction(async (transaction) => {
    const doc = await transaction.get(counterRef);
    const currentCounter = doc.exists ? (doc.data()?.orderCounter || 0) : 0;
    const nextNumber = currentCounter + 1;

    transaction.update(counterRef, { orderCounter: nextNumber });

    return nextNumber;
  });
}
