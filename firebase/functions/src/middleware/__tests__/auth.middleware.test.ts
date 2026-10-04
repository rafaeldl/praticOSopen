jest.mock('../../services/firestore.service', () => ({ db: {}, auth: {} }));

import { getRolePermissions, hasPermission } from '../auth.middleware';

describe('getRolePermissions — manage:payments', () => {
  it.each(['owner', 'admin', 'manager'])('%s pode gerenciar pagamentos', (role) => {
    const permissions = getRolePermissions(role);
    expect(permissions).toContain('manage:payments');
    expect(hasPermission({ permissions }, 'manage:payments')).toBe(true);
  });

  it.each(['supervisor', 'consultant', 'technician'])('%s não pode', (role) => {
    expect(hasPermission({ permissions: getRolePermissions(role) }, 'manage:payments')).toBe(false);
  });
});
