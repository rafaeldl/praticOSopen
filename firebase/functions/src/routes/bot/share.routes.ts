/**
 * Bot Share Routes
 * Endpoints for magic link management via Bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, ShareTokenPermission, Order } from '../../models/types';
import * as shareTokenService from '../../services/share-token.service';
import * as orderService from '../../services/order.service';
import { getUserAggr } from '../../middleware/company.middleware';

const router: Router = Router();

/**
 * POST /bot/orders/:number/share
 * Generate a magic link for an order
 */
router.post('/:number/share', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const numberParam = req.params.number;
    const orderNumber = parseInt(Array.isArray(numberParam) ? numberParam[0] : numberParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido.' },
      });
      return;
    }

    const { permissions = ['view', 'approve', 'comment'], expiresInDays = 7 } = req.body;

    // Validate permissions
    const validPermissions: ShareTokenPermission[] = ['view', 'approve', 'comment'];
    const requestedPermissions = permissions.filter(
      (p: string) => validPermissions.includes(p as ShareTokenPermission)
    ) as ShareTokenPermission[];

    if (requestedPermissions.length === 0) {
      requestedPermissions.push('view');
    }

    // Get order by number
    const order = await orderService.getOrderByNumber(companyId, orderNumber) as Order | null;

    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada.` },
      });
      return;
    }

    // Verify order has a customer
    if (!order.customer) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'OS precisa ter um cliente para gerar link de compartilhamento.' },
      });
      return;
    }

    const createdBy = getUserAggr(req);

    // Generate share token
    const shareToken = await shareTokenService.generateShareToken(
      order.id,
      companyId,
      order.customer,
      requestedPermissions,
      createdBy,
      expiresInDays
    );

    // Persist shareLink on the order document (consistent with v1 route)
    await orderService.updateOrderShareLink(companyId, order.id, {
      token: shareToken.token,
      expiresAt: shareToken.expiresAt,
      permissions: requestedPermissions,
    });

    // Build share URL
    const baseUrl = process.env.SHARE_BASE_URL || 'https://praticos.web.app';
    const shareUrl = `${baseUrl}/q/${shareToken.token}`;

    // Format expiration date
    const expiresAt = new Date(shareToken.expiresAt);
    const expiresFormatted = expiresAt.toLocaleDateString('pt-BR');

    // Format permissions for message
    const permissionLabels: Record<string, string> = {
      view: 'visualizar',
      approve: 'aprovar',
      comment: 'comentar',
    };
    const permissionsText = requestedPermissions.map((p) => permissionLabels[p]).join(', ');

    // Build formatted message for WhatsApp
    const message = `✅ Link gerado para OS #${orderNumber}

🔗 ${shareUrl}

📋 Permissões: ${permissionsText}
⏰ Válido até: ${expiresFormatted}

Envie este link para o cliente acompanhar a OS.`;

    res.status(201).json({
      success: true,
      data: {
        url: shareUrl,
        token: shareToken.token,
        expiresAt: shareToken.expiresAt,
        permissions: shareToken.permissions,
        message,
      },
    });
  } catch (error) {
    console.error('Bot generate share link error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao gerar link de compartilhamento.' },
    });
  }
});

/**
 * GET /bot/orders/:number/share
 * List existing share tokens for an order
 */
router.get('/:number/share', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const numberParam = req.params.number;
    const orderNumber = parseInt(Array.isArray(numberParam) ? numberParam[0] : numberParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido.' },
      });
      return;
    }

    // Get order by number
    const order = await orderService.getOrderByNumber(companyId, orderNumber) as Order | null;

    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada.` },
      });
      return;
    }

    // Get all tokens for this order
    const tokens = await shareTokenService.getTokensForOrder(order.id, companyId);

    const baseUrl = process.env.SHARE_BASE_URL || 'https://praticos.web.app';
    const now = new Date();

    // Filter to only active (non-expired) tokens
    const activeTokens = tokens.filter((t) => new Date(t.expiresAt) > now);

    if (activeTokens.length === 0) {
      res.json({
        success: true,
        data: {
          tokens: [],
          message: `🔗 Nenhum link ativo para OS #${orderNumber}.`,
        },
      });
      return;
    }

    // Build formatted list for WhatsApp
    const tokenLines = activeTokens.map((t, index) => {
      const createdAt = new Date(t.createdAt).toLocaleDateString('pt-BR');
      const expiresAt = new Date(t.expiresAt).toLocaleDateString('pt-BR');
      const url = `${baseUrl}/q/${t.token}`;

      return `${index + 1}. Criado em ${createdAt} - Expira ${expiresAt}
   Visualizações: ${t.viewCount || 0}
   ${url}`;
    });

    const message = `🔗 Links ativos para OS #${orderNumber}:

${tokenLines.join('\n\n')}`;

    res.json({
      success: true,
      data: {
        tokens: activeTokens.map((t) => ({
          token: t.token,
          url: `${baseUrl}/q/${t.token}`,
          permissions: t.permissions,
          createdAt: t.createdAt,
          expiresAt: t.expiresAt,
          viewCount: t.viewCount,
          lastViewedAt: t.lastViewedAt,
          approvedAt: t.approvedAt,
          rejectedAt: t.rejectedAt,
        })),
        message,
      },
    });
  } catch (error) {
    console.error('Bot list share tokens error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao listar links de compartilhamento.' },
    });
  }
});

/**
 * DELETE /bot/orders/:number/share/:token
 * Revoke a share token
 */
router.delete('/:number/share/:token', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const numberParam = req.params.number;
    const orderNumber = parseInt(Array.isArray(numberParam) ? numberParam[0] : numberParam, 10);
    const token = String(req.params.token);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido.' },
      });
      return;
    }

    // Verify token exists and belongs to this company
    const shareToken = await shareTokenService.getShareToken(token);
    if (!shareToken || shareToken.companyId !== companyId) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Link de compartilhamento não encontrado.' },
      });
      return;
    }

    // Revoke the token
    await shareTokenService.revokeShareToken(token);

    const message = `✅ Link revogado com sucesso.
O cliente não poderá mais acessar a OS por este link.`;

    res.json({
      success: true,
      data: {
        message,
      },
    });
  } catch (error) {
    console.error('Bot revoke share token error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao revogar link de compartilhamento.' },
    });
  }
});

export default router;
