/**
 * Bot Catalog Routes
 * Endpoints for searching and listing services and products via Bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as catalogService from '../../services/catalog.service';

const router: Router = Router();

/**
 * GET /api/bot/catalog/search
 * Search or list services and products
 * Query: ?q=termo&type=service|product|all&limit=20
 *
 * If q is provided: searches by prefix
 * If q is omitted: lists all items (with pagination)
 */
router.get('/search', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const query = (req.query.q as string)?.trim() || '';
    const type = (req.query.type as string) || 'all';
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    // Validate type
    const validTypes = ['service', 'product', 'all'];
    if (!validTypes.includes(type)) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_TYPE',
          message: 'Tipo inválido. Use: service, product ou all.',
        },
      });
      return;
    }

    // If query provided, validate minimum length
    if (query && query.length < 2) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_QUERY',
          message: 'Informe ao menos 2 caracteres para buscar.',
        },
      });
      return;
    }

    let services: Array<{ id: string; name: string; value: number }> = [];
    let products: Array<{ id: string; name: string; value: number }> = [];

    // Get services
    if (type === 'service' || type === 'all') {
      if (query) {
        // Search by prefix
        const serviceResults = await catalogService.searchServices(companyId, query, limit);
        services = serviceResults.map((s) => ({
          id: s.id,
          name: s.name || '',
          value: s.value || 0,
        }));
      } else {
        // List all
        const serviceResults = await catalogService.listServices(companyId, { limit });
        services = serviceResults.data.map((s) => ({
          id: s.id,
          name: s.name || '',
          value: s.value || 0,
        }));
      }
    }

    // Get products
    if (type === 'product' || type === 'all') {
      if (query) {
        // Search by prefix
        const productResults = await catalogService.searchProducts(companyId, query, limit);
        products = productResults.map((p) => ({
          id: p.id,
          name: p.name || '',
          value: p.value || 0,
        }));
      } else {
        // List all
        const productResults = await catalogService.listProducts(companyId, { limit });
        products = productResults.data.map((p) => ({
          id: p.id,
          name: p.name || '',
          value: p.value || 0,
        }));
      }
    }

    res.json({
      success: true,
      data: {
        query: query || null,
        type,
        services,
        products,
        totalResults: services.length + products.length,

      },
    });
  } catch (error) {
    console.error('Bot Catalog search error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao buscar no catálogo.' },
    });
  }
});

export default router;
