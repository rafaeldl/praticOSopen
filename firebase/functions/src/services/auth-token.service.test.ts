jest.mock('./firestore.service', () => ({ db: {} }));

import { generateToken } from './auth-token.service';

describe('generateToken', () => {
  it('carries more than 128 bits in the known format', () => {
    expect(generateToken()).toMatch(/^LT_[A-Z0-9]{26}$/);
  });

  it('does not repeat', () => {
    const tokens = new Set(Array.from({ length: 1000 }, () => generateToken()));
    expect(tokens.size).toBe(1000);
  });
});
