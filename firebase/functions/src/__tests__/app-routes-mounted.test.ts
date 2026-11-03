/**
 * Every route the API mounts is on purpose. The #526 review (M1) found two
 * write routes that no screen uses and that entered production without a
 * flag: order photos by API and the form templates CRUD. They stay out until
 * a screen needs them, and then behind a flag that starts off.
 */
import { readFileSync } from 'fs';
import path from 'path';

const index = readFileSync(path.join(__dirname, '..', 'index.ts'), 'utf8');

describe('routes mounted by index.ts', () => {
  it('no order photos route by API (the app and the web upload to Storage)', () => {
    expect(index).not.toMatch(/order-photos\.routes/);
    expect(index).not.toMatch(/orderPhotosRoutes/);
  });

  it('no form templates CRUD by API (the app and the web write Firestore)', () => {
    expect(index).not.toMatch(/forms\/templates/);
    expect(index).not.toMatch(/form-templates\.routes/);
  });
});
