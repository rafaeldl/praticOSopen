/**
 * Minimal in-memory Firestore for unit tests of server-side write flows
 * (documents, merge/update/delete, batches, transactions, simple queries).
 * Not a full emulator: only the operations used by the services under test.
 */

type Data = Record<string, unknown>;

export const SERVER_TIMESTAMP = '__SERVER_TIMESTAMP__';
const DELETE = Symbol('delete');

export const FakeFieldValue = {
  serverTimestamp: () => SERVER_TIMESTAMP,
  delete: () => DELETE,
};

function clone<T>(value: T): T {
  return value === undefined ? value : JSON.parse(JSON.stringify(value));
}

function isPlainObject(value: unknown): value is Data {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function mergeDeep(target: Data, source: Data): Data {
  const out: Data = { ...target };
  for (const [key, value] of Object.entries(source)) {
    if (value === DELETE) delete out[key];
    else if (isPlainObject(value) && isPlainObject(out[key])) out[key] = mergeDeep(out[key] as Data, value);
    else if (isPlainObject(value)) out[key] = mergeDeep({}, value);
    else out[key] = clone(value);
  }
  return out;
}

function stripDeletes(data: Data): Data {
  return mergeDeep({}, data);
}

function getField(data: Data | undefined, path: string): unknown {
  return path.split('.').reduce<unknown>((acc, key) => (isPlainObject(acc) ? acc[key] : undefined), data);
}

export class FakeSnapshot {
  constructor(
    public ref: FakeDoc,
    private value: Data | undefined,
  ) {}
  get exists() {
    return this.value !== undefined;
  }
  get id() {
    return this.ref.id;
  }
  data() {
    return clone(this.value);
  }
  get(field: string) {
    return clone(getField(this.value, field));
  }
}

export class FakeDoc {
  constructor(
    public store: FakeFirestore,
    public path: string,
  ) {}
  get id() {
    return this.path.split('/').pop() as string;
  }
  collection(name: string) {
    return new FakeCollection(this.store, `${this.path}/${name}`);
  }
  async get() {
    return new FakeSnapshot(this, this.store.docs.get(this.path));
  }
  async set(data: Data, opts?: { merge?: boolean }) {
    this.store.write(this.path, data, opts?.merge ? 'merge' : 'set');
  }
  async update(data: Data) {
    this.store.write(this.path, data, 'update');
  }
  async delete() {
    this.store.docs.delete(this.path);
  }
}

class FakeQuery {
  constructor(
    protected store: FakeFirestore,
    public path: string,
    private filters: Array<[string, string, unknown]> = [],
    /** Collection-group query: `path` is the collection id, matched at any depth. */
    private group = false,
  ) {}
  where(field: string, op: string, value: unknown) {
    return new FakeQuery(this.store, this.path, [...this.filters, [field, op, value]], this.group);
  }
  orderBy() {
    return this;
  }
  limit() {
    return this;
  }
  async get() {
    const source = this.group ? this.store.listCollectionGroup(this.path) : this.store.listCollection(this.path);
    const docs = source
      .filter((d) =>
        this.filters.every(([f, op, v]) =>
          op === '==' ? getField(d.value, f) === v : op === 'in' && Array.isArray(v) && v.includes(getField(d.value, f)),
        ),
      )
      .map((d) => new FakeSnapshot(new FakeDoc(this.store, d.path), d.value));
    return { empty: docs.length === 0, size: docs.length, docs };
  }
}

export class FakeCollection extends FakeQuery {
  doc(id?: string) {
    return new FakeDoc(this.store, `${this.path}/${id ?? `auto${++this.store.autoId}`}`);
  }
  async add(data: Data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
}

export class FakeFirestore {
  docs = new Map<string, Data>();
  autoId = 0;

  collection(name: string) {
    return new FakeCollection(this, name);
  }
  doc(path: string) {
    return new FakeDoc(this, path);
  }
  collectionGroup(collectionId: string) {
    return new FakeQuery(this, collectionId, [], true);
  }

  write(path: string, data: Data, mode: 'set' | 'merge' | 'update') {
    const current = this.docs.get(path);
    if (mode === 'update') {
      if (!current) throw new Error(`NOT_FOUND: ${path}`);
      const next: Data = clone(current);
      for (const [key, value] of Object.entries(data)) {
        const parts = key.split('.');
        let target = next;
        for (const p of parts.slice(0, -1)) {
          if (!isPlainObject(target[p])) target[p] = {};
          target = target[p] as Data;
        }
        const last = parts[parts.length - 1];
        if (value === DELETE) delete target[last];
        else target[last] = isPlainObject(value) ? stripDeletes(value) : clone(value);
      }
      this.docs.set(path, next);
    } else if (mode === 'merge') {
      this.docs.set(path, mergeDeep(current ?? {}, data));
    } else {
      this.docs.set(path, stripDeletes(data));
    }
  }

  listCollection(path: string) {
    const depth = path.split('/').length + 1;
    return [...this.docs.entries()]
      .filter(([p]) => p.startsWith(`${path}/`) && p.split('/').length === depth)
      .map(([p, value]) => ({ path: p, value }));
  }

  listCollectionGroup(collectionId: string) {
    return [...this.docs.entries()]
      .filter(([p]) => {
        const parts = p.split('/');
        return parts.length % 2 === 0 && parts[parts.length - 2] === collectionId;
      })
      .map(([p, value]) => ({ path: p, value }));
  }

  batch() {
    const ops: Array<() => Promise<void>> = [];
    const batch = {
      set: (ref: FakeDoc, data: Data, opts?: { merge?: boolean }) => (ops.push(() => ref.set(data, opts)), batch),
      update: (ref: FakeDoc, data: Data) => (ops.push(() => ref.update(data)), batch),
      delete: (ref: FakeDoc) => (ops.push(() => ref.delete()), batch),
      commit: async () => {
        for (const op of ops) await op();
      },
    };
    return batch;
  }

  async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
    const snapshot = new Map(this.docs);
    const ops: Array<() => Promise<void>> = [];
    let wrote = false;
    const tx = {
      get: async (ref: FakeDoc) => {
        if (wrote) throw new Error('Firestore transactions require all reads before writes');
        return ref.get();
      },
      set: (ref: FakeDoc, data: Data, opts?: { merge?: boolean }) => ((wrote = true), ops.push(() => ref.set(data, opts)), tx),
      update: (ref: FakeDoc, data: Data) => ((wrote = true), ops.push(() => ref.update(data)), tx),
      delete: (ref: FakeDoc) => ((wrote = true), ops.push(() => ref.delete()), tx),
    };
    try {
      const result = await fn(tx);
      for (const op of ops) await op();
      return result;
    } catch (error) {
      this.docs = snapshot;
      throw error;
    }
  }

  /** Deletes a document and everything below it (mirrors Firestore's recursiveDelete). */
  async recursiveDelete(ref: FakeDoc) {
    for (const path of [...this.docs.keys()]) {
      if (path === ref.path || path.startsWith(`${ref.path}/`)) this.docs.delete(path);
    }
  }

  /** Test helper: list documents directly under a collection path. */
  list(collectionPath: string): Array<{ id: string; data: Data }> {
    return this.listCollection(collectionPath).map((d) => ({ id: d.path.split('/').pop() as string, data: clone(d.value) as Data }));
  }
  /** Test helper: drop every document. */
  reset() {
    this.docs.clear();
    this.autoId = 0;
  }

  /** Test helper: read a document's data synchronously. */
  read(path: string): Data | undefined {
    return clone(this.docs.get(path));
  }
  /** Test helper: seed a document. */
  seed(path: string, data: Data) {
    this.docs.set(path, clone(data));
  }
}

/**
 * Builds a replacement for `services/firestore.service` backed by `fake`.
 * Usage: jest.mock('../firestore.service', () => require('<path>/fake-firestore').fakeFirestoreModule())
 */
export function fakeFirestoreModule(fake: FakeFirestore = new FakeFirestore()) {
  return {
    __fake: fake,
    db: fake,
    FieldValue: FakeFieldValue,
    Timestamp: {
      now: () => SERVER_TIMESTAMP,
      // Plain object (survives the JSON clone of the fake), same shape as Firestore's.
      fromDate: (date: Date) => ({ seconds: Math.floor(date.getTime() / 1000), nanoseconds: (date.getTime() % 1000) * 1e6 }),
    },
    getRootCollection: (name: string) => fake.collection(name),
    getTenantCollection: (companyId: string, name: string) => fake.collection(`companies/${companyId}/${name}`),
    getDocument: async (collection: FakeCollection, id: string) => {
      const snap = await collection.doc(id).get();
      return snap.exists ? { ...snap.data(), id } : null;
    },
    updateDocument: async (collection: FakeCollection, id: string, data: Data) => {
      await collection.doc(id).update({ ...data, updatedAt: new Date().toISOString() });
    },
  };
}

/** Shared instance used by the module-level helpers below (Asaas service tests). */
export const fakeDb = new FakeFirestore();

/** Seeds a document by full path, e.g. seed('companies/c1/private/asaas', {...}). */
export function seed(path: string, data: Data) {
  fakeDb.seed(path, data);
}
/** Reads a document by full path (undefined when missing). */
export function read(path: string): Data | undefined {
  return fakeDb.read(path);
}
/** Lists the documents directly under a collection path. */
export function list(collectionPath: string) {
  return fakeDb.list(collectionPath);
}
export function resetFakeDb() {
  fakeDb.reset();
}

/**
 * Drop-in module for `services/firestore.service` backed by the shared `fakeDb`:
 * jest.mock('../../firestore.service', () => jest.requireActual('<path>/helpers/fake-firestore').firestoreServiceMock);
 */
export const firestoreServiceMock = fakeFirestoreModule(fakeDb);
