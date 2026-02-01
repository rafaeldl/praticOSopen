/**
 * Comment Service
 * Manages order comments for customer communication
 */

import { getTenantCollection, FieldValue } from './firestore.service';
import { OrderComment, CommentAuthorType, CommentSource, CommentAuthor } from '../models/types';

/**
 * Add a comment to an order
 */
export async function addComment(
  companyId: string,
  orderId: string,
  text: string,
  authorType: CommentAuthorType,
  author: CommentAuthor,
  source: CommentSource,
  isInternal = false,
  shareToken?: string
): Promise<OrderComment> {
  // Clean author object to remove undefined values (Firestore doesn't accept undefined)
  const cleanAuthor: CommentAuthor = { name: author.name };
  if (author.email) cleanAuthor.email = author.email;
  if (author.phone) cleanAuthor.phone = author.phone;
  if (author.userId) cleanAuthor.userId = author.userId;

  const commentData: Record<string, unknown> = {
    text,
    authorType,
    author: cleanAuthor,
    source,
    isInternal,
    createdAt: FieldValue.serverTimestamp(),
  };

  if (shareToken) {
    commentData.shareToken = shareToken;
  }

  const commentsCollection = getTenantCollection(companyId, 'orders')
    .doc(orderId)
    .collection('comments');

  const docRef = await commentsCollection.add(commentData);

  // Get the created document to return with actual timestamp
  const doc = await docRef.get();
  const data = doc.data();

  return {
    id: docRef.id,
    ...data,
  } as OrderComment;
}

/**
 * Get all comments for an order
 * Uses simple query + in-memory filter to avoid composite index requirements
 */
export async function getComments(
  companyId: string,
  orderId: string,
  includeInternal = true
): Promise<OrderComment[]> {
  const commentsCollection = getTenantCollection(companyId, 'orders')
    .doc(orderId)
    .collection('comments');

  // Simple query - get all comments ordered by createdAt
  const snapshot = await commentsCollection.orderBy('createdAt', 'asc').get();

  // Filter in memory to avoid composite index requirements
  return snapshot.docs
    .map((doc) => doc.data() as OrderComment)
    .filter((comment) => {
      if (comment.deleted) return false;
      if (!includeInternal && comment.isInternal) return false;
      return true;
    });
}

/**
 * Get only customer-visible comments (non-internal)
 */
export async function getCustomerVisibleComments(
  companyId: string,
  orderId: string
): Promise<OrderComment[]> {
  return getComments(companyId, orderId, false);
}

/**
 * Update a comment
 */
export async function updateComment(
  companyId: string,
  orderId: string,
  commentId: string,
  text: string
): Promise<void> {
  const commentRef = getTenantCollection(companyId, 'orders')
    .doc(orderId)
    .collection('comments')
    .doc(commentId);

  await commentRef.update({
    text,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Soft delete a comment
 */
export async function deleteComment(
  companyId: string,
  orderId: string,
  commentId: string
): Promise<void> {
  const commentRef = getTenantCollection(companyId, 'orders')
    .doc(orderId)
    .collection('comments')
    .doc(commentId);

  await commentRef.update({
    deleted: true,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Get a single comment by ID
 */
export async function getComment(
  companyId: string,
  orderId: string,
  commentId: string
): Promise<OrderComment | null> {
  const commentRef = getTenantCollection(companyId, 'orders')
    .doc(orderId)
    .collection('comments')
    .doc(commentId);

  const doc = await commentRef.get();

  if (!doc.exists) {
    return null;
  }

  return doc.data() as OrderComment;
}

/**
 * Count comments for an order
 * Uses getComments to reuse the same filtering logic
 */
export async function countComments(
  companyId: string,
  orderId: string,
  includeInternal = true
): Promise<number> {
  const comments = await getComments(companyId, orderId, includeInternal);
  return comments.length;
}
