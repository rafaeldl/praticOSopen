/**
 * Offline check: the Firestore RBAC matrix agrees with the app permissions.
 *
 * For every case that names a `permission`, the roles the rules allow must be
 * the roles that have that permission in lib/models/permission.dart (golden
 * copy in rbac/app-permissions.json, checked by the Flutter test
 * test/models/permission_matrix_test.dart). A known difference must be
 * written down as `gap`; a gap that is no longer true fails too.
 */

import appPermissions from './rbac/app-permissions.json';
import { CASES, ROLE_ACTORS, type RoleActor } from './rbac/firestore-matrix';

type AppRole = keyof typeof appPermissions.roles;

// 'owner' is read as admin by the app (rolesTypeFromJson).
const appRoleOf = (actor: RoleActor): AppRole => (actor === 'owner' ? 'admin' : actor);

const appAllows = (actor: RoleActor, permission: string) =>
  (appPermissions.roles[appRoleOf(actor)] as string[]).includes(permission);

const knownPermissions = new Set(Object.values(appPermissions.roles).flat());

describe('RBAC matrix × app permissions', () => {
  it('case ids are unique', () => {
    const ids = CASES.map((c) => c.id);
    expect(ids.filter((id, i) => ids.indexOf(id) !== i)).toEqual([]);
  });

  it("the 'owner' claim keeps every power of 'admin'", () => {
    const missing = CASES.filter((c) => c.allow.includes('admin') && !c.allow.includes('owner')).map((c) => c.id);
    expect(missing).toEqual([]);
  });

  it('no case gives anything in company c1 to outsiders (except the control case)', () => {
    const leaking = CASES.filter(
      (c) => c.id !== 'crossTenant.control' && c.id !== 'segments.read'
        && c.allow.some((a) => a === 'otherCompany' || a === 'noCompany' || a === 'anonymous'),
    ).map((c) => c.id);
    expect(leaking).toEqual([]);
  });

  for (const c of CASES.filter((x) => x.permission)) {
    it(`${c.id} follows ${c.permission}`, () => {
      expect(knownPermissions.has(c.permission!)).toBe(true);

      const differences = ROLE_ACTORS.filter((actor) => appAllows(actor, c.permission!) !== c.allow.includes(actor))
        .map((actor) => `${actor}: app ${appAllows(actor, c.permission!) ? 'permite' : 'nega'}, regras ${c.allow.includes(actor) ? 'permitem' : 'negam'}`);

      if (c.gap) {
        // The documented gap must still exist; otherwise remove it from the matrix.
        expect(differences).not.toEqual([]);
      } else {
        expect(differences).toEqual([]);
      }
    });
  }
});
