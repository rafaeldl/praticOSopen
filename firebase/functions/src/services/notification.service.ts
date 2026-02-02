/**
 * Notification Service
 * Handles push notifications for magic link events
 *
 * FCM is now enabled. The Flutter app registers FCM tokens in user documents,
 * and this service sends push notifications and saves them to Firestore for
 * in-app notification history.
 */

import { getMessaging } from 'firebase-admin/messaging';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from './firestore.service';
import { Order, OrderComment, Company, UserAggr, RoleType } from '../models/types';

// Types for notification recipients
interface NotificationRecipient {
  userId: string;
  name: string;
  fcmTokens?: string[];
}

interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

// Roles that should receive notifications
const NOTIFICATION_ROLES: RoleType[] = ['owner', 'admin', 'supervisor', 'manager'];

/**
 * Get users who should be notified for an order event
 * Returns the assigned user + admins/owners
 */
async function getNotificationRecipients(
  companyId: string,
  order: Order
): Promise<NotificationRecipient[]> {
  const recipients: NotificationRecipient[] = [];
  const addedUserIds = new Set<string>();

  // Add assigned user if exists
  if (order.assignedTo?.id) {
    recipients.push({
      userId: order.assignedTo.id,
      name: order.assignedTo.name,
    });
    addedUserIds.add(order.assignedTo.id);
  }

  // Add order creator
  if (order.createdBy?.id && !addedUserIds.has(order.createdBy.id)) {
    recipients.push({
      userId: order.createdBy.id,
      name: order.createdBy.name,
    });
    addedUserIds.add(order.createdBy.id);
  }

  // Get company to find admins/owners
  try {
    const companyDoc = await db.collection('companies').doc(companyId).get();
    if (companyDoc.exists) {
      const company = companyDoc.data() as Company;

      // Add owner if not already added
      if (company.owner?.id && !addedUserIds.has(company.owner.id)) {
        recipients.push({
          userId: company.owner.id,
          name: company.owner.name,
        });
        addedUserIds.add(company.owner.id);
      }

      // Add users with admin/manager roles
      if (company.users) {
        for (const userRole of company.users) {
          if (
            userRole.user?.id &&
            NOTIFICATION_ROLES.includes(userRole.role) &&
            !addedUserIds.has(userRole.user.id)
          ) {
            recipients.push({
              userId: userRole.user.id,
              name: userRole.user.name,
            });
            addedUserIds.add(userRole.user.id);
          }
        }
      }
    }
  } catch (error) {
    console.error('Error getting company for notifications:', error);
  }

  return recipients;
}

/**
 * Send notification to recipients via FCM and save to Firestore for in-app display
 */
async function sendNotification(
  recipients: NotificationRecipient[],
  payload: NotificationPayload,
  companyId: string
): Promise<void> {
  // Log notification for debugging
  console.log(`[NOTIFICATION] ${payload.title}`);
  console.log(`[NOTIFICATION] ${payload.body}`);
  console.log(`[NOTIFICATION] Recipients: ${recipients.map(r => r.name).join(', ')}`);
  console.log(`[NOTIFICATION] Data:`, payload.data);

  const allTokens: string[] = [];

  // Save notification to Firestore and collect FCM tokens
  for (const recipient of recipients) {
    // Save notification to Firestore for in-app display
    try {
      await db.collection('companies').doc(companyId).collection('notifications').add({
        title: payload.title,
        body: payload.body,
        type: payload.data?.type,
        orderId: payload.data?.orderId,
        orderNumber: payload.data?.orderNumber,
        recipientId: recipient.userId,
        read: false,
        readAt: null,
        data: payload.data,
        createdAt: FieldValue.serverTimestamp(),
        company: { id: companyId },
      });
    } catch (error) {
      console.error(`[NOTIFICATION] Error saving notification for ${recipient.name}:`, error);
    }

    // Fetch FCM tokens from user document
    try {
      const userDoc = await db.collection('users').doc(recipient.userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData?.fcmTokens && Array.isArray(userData.fcmTokens)) {
          const tokens = userData.fcmTokens
            .filter((t: { token?: string }) => t.token)
            .map((t: { token: string }) => t.token);
          allTokens.push(...tokens);
        }
      }
    } catch (error) {
      console.error(`[NOTIFICATION] Error fetching tokens for ${recipient.name}:`, error);
    }
  }

  // Send FCM push notifications
  if (allTokens.length > 0) {
    try {
      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast({
        tokens: allTokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'orders_channel',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      console.log(`[NOTIFICATION] FCM sent: ${response.successCount} success, ${response.failureCount} failed`);

      // Handle invalid tokens
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered') {
            console.log(`[NOTIFICATION] Invalid token at index ${idx}: ${allTokens[idx]}`);
            // TODO: Remove invalid token from user document
          }
        }
      });
    } catch (error) {
      console.error('[NOTIFICATION] Error sending FCM:', error);
    }
  } else {
    console.log('[NOTIFICATION] No FCM tokens available for recipients');
  }
}

/**
 * Notify when a customer approves a quote via magic link
 */
export async function notifyOrderApproved(
  order: Order,
  companyId: string,
  customerName: string
): Promise<void> {
  try {
    const recipients = await getNotificationRecipients(companyId, order);

    if (recipients.length === 0) {
      console.log('[NOTIFICATION] No recipients for order approval notification');
      return;
    }

    const payload: NotificationPayload = {
      title: 'Orçamento Aprovado! ✅',
      body: `${customerName} aprovou o orçamento da OS #${order.number}`,
      data: {
        type: 'order_approved',
        orderId: order.id,
        orderNumber: String(order.number),
        companyId,
      },
    };

    await sendNotification(recipients, payload, companyId);
  } catch (error) {
    console.error('Error sending order approved notification:', error);
  }
}

/**
 * Notify when a customer rejects a quote via magic link
 */
export async function notifyOrderRejected(
  order: Order,
  companyId: string,
  customerName: string,
  reason?: string
): Promise<void> {
  try {
    const recipients = await getNotificationRecipients(companyId, order);

    if (recipients.length === 0) {
      console.log('[NOTIFICATION] No recipients for order rejection notification');
      return;
    }

    let body = `${customerName} rejeitou o orçamento da OS #${order.number}`;
    if (reason) {
      body += `. Motivo: ${reason}`;
    }

    const payload: NotificationPayload = {
      title: 'Orçamento Rejeitado ❌',
      body,
      data: {
        type: 'order_rejected',
        orderId: order.id,
        orderNumber: String(order.number),
        companyId,
        ...(reason && { reason }),
      },
    };

    await sendNotification(recipients, payload, companyId);
  } catch (error) {
    console.error('Error sending order rejected notification:', error);
  }
}

/**
 * Notify when a customer adds a comment via magic link
 */
export async function notifyNewComment(
  order: Order,
  comment: OrderComment,
  companyId: string
): Promise<void> {
  try {
    const recipients = await getNotificationRecipients(companyId, order);

    if (recipients.length === 0) {
      console.log('[NOTIFICATION] No recipients for new comment notification');
      return;
    }

    // Truncate comment text for notification
    const maxLength = 100;
    let commentPreview = comment.text;
    if (commentPreview.length > maxLength) {
      commentPreview = commentPreview.substring(0, maxLength) + '...';
    }

    const payload: NotificationPayload = {
      title: `Nova mensagem na OS #${order.number} 💬`,
      body: `${comment.author.name}: ${commentPreview}`,
      data: {
        type: 'new_comment',
        orderId: order.id,
        orderNumber: String(order.number),
        companyId,
        commentId: comment.id,
      },
    };

    await sendNotification(recipients, payload, companyId);
  } catch (error) {
    console.error('Error sending new comment notification:', error);
  }
}

/**
 * Notify when order status changes (for internal use)
 */
export async function notifyOrderStatusChanged(
  order: Order,
  companyId: string,
  oldStatus: string,
  newStatus: string,
  changedBy: UserAggr
): Promise<void> {
  try {
    const recipients = await getNotificationRecipients(companyId, order);

    if (recipients.length === 0) {
      console.log('[NOTIFICATION] No recipients for status change notification');
      return;
    }

    // Translate status for display
    const statusLabels: Record<string, string> = {
      quote: 'Orçamento',
      approved: 'Aprovado',
      progress: 'Em Andamento',
      done: 'Concluído',
      canceled: 'Cancelado',
    };

    const payload: NotificationPayload = {
      title: `OS #${order.number} - Status Atualizado`,
      body: `${changedBy.name} alterou o status para ${statusLabels[newStatus] || newStatus}`,
      data: {
        type: 'status_changed',
        orderId: order.id,
        orderNumber: String(order.number),
        companyId,
        oldStatus,
        newStatus,
      },
    };

    await sendNotification(recipients, payload, companyId);
  } catch (error) {
    console.error('Error sending status change notification:', error);
  }
}

/**
 * Notify when a customer rates the completed order via magic link
 */
export async function notifyOrderRated(
  order: Order,
  companyId: string,
  customerName: string,
  score: number
): Promise<void> {
  try {
    const recipients = await getNotificationRecipients(companyId, order);

    if (recipients.length === 0) {
      console.log('[NOTIFICATION] No recipients for order rating notification');
      return;
    }

    // Generate stars based on score
    const stars = '⭐'.repeat(score);

    const payload: NotificationPayload = {
      title: `Nova Avaliação! ${stars}`,
      body: `${customerName} avaliou a OS #${order.number} com ${score} estrelas`,
      data: {
        type: 'order_rated',
        orderId: order.id,
        orderNumber: String(order.number),
        companyId,
        score: String(score),
      },
    };

    await sendNotification(recipients, payload, companyId);
  } catch (error) {
    console.error('Error sending order rating notification:', error);
  }
}
