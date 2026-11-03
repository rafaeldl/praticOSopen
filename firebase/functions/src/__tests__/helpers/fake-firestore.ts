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

/** Firestore filter semantics used by the tests: ==, in, array-contains, numeric > and text <, >= / <=. */
function matches(actual: unknown, op: string, value: unknown): boolean {
  if (op === '==') return actual === value;
  if (op === 'array-contains') return Array.isArray(actual) && actual.includes(value);
  if (op === 'in') return Array.isArray(value) && value.includes(actual);
  if (op === '>') return typeof actual === 'number' && typeof value === 'number' && actual > value;
  if (op === '<') return typeof actual === 'string' && typeof value === 'string' && actual < value;
  if (op === '>=') return typeof actual === 'string' && typeof value === 'string' && actual >= value;
  if (op === '<=') return typeof actual === 'string' && typeof value === 'string' && actual <= value;
  throw new Error(`FakeQuery: unsupported operator ${op}`);
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
  /** Like Firestore: fails with ALREADY_EXISTS (6) when the document exists. */
  async create(data: Data) {
    if (this.store.docs.has(this.path)) {
      throw Object.assign(new Error(`ALREADY_EXISTS: ${this.path}`), { code: 6 });
    }
    this.store.write(this.path, data, 'set');
  }
  async delete() {
    this.store.remove(this.path);
  }
}

/** Sort value of a document: `__name__` is the document id. */
function sortValue(d: { path: string; value: Data }, field: string): unknown {
  return field === '__name__' ? d.path.split('/').pop() : getField(d.value, field);
}

/** Firestore-like order across types: missing/null first, then numbers, then strings. */
function compareValues(a: unknown, b: unknown): number {
  const rank = (v: unknown) => (v === undefined || v === null ? 0 : typeof v === 'number' ? 1 : typeof v === 'string' ? 2 : 3);
  if (rank(a) !== rank(b)) return rank(a) - rank(b);
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  if (typeof a === 'string' && typeof b === 'string') return a < b ? -1 : a > b ? 1 : 0;
  return 0;
}

interface QueryState {
  filters: Array<[string, string, unknown]>;
  orders: Array<[string, 'asc' | 'desc']>;
  limit?: number;
  offset?: number;
  /** Values of the order fields (and the id) the results start after. */
  after?: unknown[];
}

class FakeQuery {
  constructor(
    protected store: FakeFirestore,
    public path: string,
    private state: QueryState = { filters: [], orders: [] },
    /** Collection-group query: `path` is the collection id, matched at any depth. */
    private group = false,
  ) {}
  private next(change: Partial<QueryState>) {
    return new FakeQuery(this.store, this.path, { ...this.state, ...change }, this.group);
  }
  where(field: string, op: string, value: unknown) {
    return this.next({ filters: [...this.state.filters, [field, op, value]] });
  }
  /** Sorts like Firestore, except that documents without the field are kept (sorted first). */
  orderBy(field: string, direction: 'asc' | 'desc' = 'asc') {
    return this.next({ orders: [...this.state.orders, [field, direction]] });
  }
  limit(n: number) {
    return this.next({ limit: n });
  }
  offset(n: number) {
    return this.next({ offset: n });
  }
  /** startAfter(snapshot) or startAfter(...values of the order fields). */
  startAfter(...values: unknown[]) {
    const [first] = values;
    if (first instanceof FakeSnapshot) {
      const doc = { path: first.ref.path, value: first.data() as Data };
      return this.next({ after: [...this.state.orders.map(([f]) => sortValue(doc, f)), sortValue(doc, '__name__')] });
    }
    return this.next({ after: values });
  }
  count() {
    return { get: async () => {
      const size = this.matching().length;
      return { data: () => ({ count: size }) };
    } };
  }
  private matching() {
    const source = this.group ? this.store.listCollectionGroup(this.path) : this.store.listCollection(this.path);
    return source.filter((d) => this.state.filters.every(([f, op, v]) => matches(getField(d.value, f), op, v)));
  }
  async get() {
    const orders: Array<[string, 'asc' | 'desc']> = this.state.orders.length > 0
      ? [...this.state.orders, ['__name__', this.state.orders[this.state.orders.length - 1][1]]]
      : [];
    let rows = this.matching();
    const compare = (a: { path: string; value: Data }, values: unknown[]) => {
      for (let i = 0; i < orders.length && i < values.length; i++) {
        const diff = compareValues(sortValue(a, orders[i][0]), values[i]) * (orders[i][1] === 'desc' ? -1 : 1);
        if (diff !== 0) return diff;
      }
      return 0;
    };
    if (orders.length > 0) {
      rows = [...rows].sort((a, b) => compare(a, orders.map(([f]) => sortValue(b, f))));
    }
    if (this.state.after) {
      const after = this.state.after;
      rows = rows.filter((d) => compare(d, after) > 0);
    }
    if (this.state.offset) rows = rows.slice(this.state.offset);
    if (this.state.limit !== undefined) rows = rows.slice(0, this.state.limit);
    const docs = rows.map((d) => new FakeSnapshot(new FakeDoc(this.store, d.path), d.value));
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
  /** Write counter per document path: a transaction whose reads changed is retried, like Firestore. */
  private versions = new Map<string, number>();
  private barrier: { size: number; waiting: Array<() => void> } | null = null;

  collection(name: string) {
    return new FakeCollection(this, name);
  }
  doc(path: string) {
    return new FakeDoc(this, path);
  }
  /** db.getAll(...refs), outside a transaction. */
  async getAll(...refs: FakeDoc[]) {
    return Promise.all(refs.map((ref) => ref.get()));
  }
  collectionGroup(collectionId: string) {
    return new FakeQuery(this, collectionId, { filters: [], orders: [] }, true);
  }

  private version(path: string): number {
    return this.versions.get(path) ?? 0;
  }
  private bump(path: string) {
    this.versions.set(path, this.version(path) + 1);
  }

  remove(path: string) {
    this.docs.delete(path);
    this.bump(path);
  }

  /**
   * Test helper: the next `size` transactions wait for each other right
   * before committing, so all of them read before any of them writes (the
   * race two clients saving at the same time would have).
   */
  holdCommitsUntil(size: number) {
    this.barrier = { size, waiting: [] };
  }

  private async atCommitPoint(): Promise<void> {
    const barrier = this.barrier;
    if (!barrier) return;
    const open = () => {
      if (this.barrier === barrier) this.barrier = null;
      barrier.waiting.splice(0).forEach((release) => release());
    };
    await new Promise<void>((resolve) => {
      barrier.waiting.push(resolve);
      if (barrier.waiting.length >= barrier.size) open();
      // Never hangs a test whose other transaction did not start.
      else setTimeout(open, 500).unref();
    });
  }

  write(path: string, data: Data, mode: 'set' | 'merge' | 'update') {
    this.bump(path);
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

  /**
   * Optimistic transaction like Firestore's server SDK: writes are applied
   * together at commit; when a document read in it changed meanwhile, the
   * whole function runs again (up to 5 times), then it fails with ABORTED.
   */
  async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      const reads = new Map<string, number>();
      const ops: Array<() => void> = [];
      let wrote = false;
      const remember = (path: string) => {
        if (!reads.has(path)) reads.set(path, this.version(path));
      };
      const tx = {
        get: async (ref: FakeDoc | FakeQuery) => {
          if (wrote) throw new Error('Firestore transactions require all reads before writes');
          if (ref instanceof FakeDoc) {
            remember(ref.path);
            return ref.get();
          }
          const result = await ref.get();
          result.docs.forEach((doc) => remember(doc.ref.path));
          return result;
        },
        // Same as Firestore: many documents in one read, in the order asked.
        getAll: async (...refs: FakeDoc[]) => {
          if (wrote) throw new Error('Firestore transactions require all reads before writes');
          refs.forEach((ref) => remember(ref.path));
          return Promise.all(refs.map((ref) => ref.get()));
        },
        set: (ref: FakeDoc, data: Data, opts?: { merge?: boolean }) =>
          ((wrote = true), ops.push(() => this.write(ref.path, data, opts?.merge ? 'merge' : 'set')), tx),
        create: (ref: FakeDoc, data: Data) => ((wrote = true), ops.push(() => {
          if (this.docs.has(ref.path)) throw Object.assign(new Error(`ALREADY_EXISTS: ${ref.path}`), { code: 6 });
          this.write(ref.path, data, 'set');
        }), tx),
        update: (ref: FakeDoc, data: Data) => ((wrote = true), ops.push(() => this.write(ref.path, data, 'update')), tx),
        delete: (ref: FakeDoc) => ((wrote = true), ops.push(() => this.remove(ref.path)), tx),
      };
      const result = await fn(tx);
      await this.atCommitPoint();
      // From here on nothing awaits: check and apply are atomic.
      const changed = [...reads].some(([path, version]) => this.version(path) !== version);
      if (changed) {
        if (attempt >= 5) throw Object.assign(new Error('ABORTED: too much contention'), { code: 10 });
        continue;
      }
      const before = new Map(this.docs);
      try {
        ops.forEach((op) => op());
      } catch (error) {
        this.docs = before;
        throw error;
      }
      return result;
    }
  }

  /** Deletes a document and everything below it (mirrors Firestore's recursiveDelete). */
  async recursiveDelete(ref: FakeDoc) {
    for (const path of [...this.docs.keys()]) {
      if (path === ref.path || path.startsWith(`${ref.path}/`)) this.remove(path);
    }
  }

  /** Test helper: list documents directly under a collection path. */
  list(collectionPath: string): Array<{ id: string; data: Data }> {
    return this.listCollection(collectionPath).map((d) => ({ id: d.path.split('/').pop() as string, data: clone(d.value) as Data }));
  }
  /** Test helper: drop every document. */
  reset() {
    this.docs.clear();
    this.versions.clear();
    this.barrier = null;
    this.autoId = 0;
  }

  /** Test helper: read a document's data synchronously. */
  read(path: string): Data | undefined {
    return clone(this.docs.get(path));
  }
  /** Test helper: seed a document. */
  seed(path: string, data: Data) {
    this.docs.set(path, clone(data));
    this.bump(path);
  }
}

/** Storage stand-in: records what the code deleted. */
export class FakeStorage {
  deleted: string[] = [];
  deletedPrefixes: string[] = [];
  bucket() {
    return {
      file: (path: string) => ({ delete: async () => void this.deleted.push(path) }),
      deleteFiles: async ({ prefix }: { prefix: string }) => void this.deletedPrefixes.push(prefix),
    };
  }
  reset() {
    this.deleted = [];
    this.deletedPrefixes = [];
  }
}

/**
 * Builds a replacement for `services/firestore.service` backed by `fake`.
 * Usage: jest.mock('../firestore.service', () => require('<path>/fake-firestore').fakeFirestoreModule())
 */
export function fakeFirestoreModule(fake: FakeFirestore = new FakeFirestore(), storage: FakeStorage = new FakeStorage()) {
  return {
    __fake: fake,
    db: fake,
    storage,
    runTransaction: <T>(fn: (tx: unknown) => Promise<T>) => fake.runTransaction(fn),
    FieldValue: FakeFieldValue,
    Timestamp: {
      now: () => SERVER_TIMESTAMP,
      // Plain object (survives the JSON clone of the fake), same shape as Firestore's.
      fromDate: (date: Date) => ({ seconds: Math.floor(date.getTime() / 1000), nanoseconds: (date.getTime() % 1000) * 1e6 }),
    },
    // Same as firestore.service: companies/{id}.nextOrderNumber, in a transaction.
    getNextOrderNumber: (companyId: string) => fake.runTransaction(async (tx: any) => {
      const ref = fake.collection('companies').doc(companyId);
      const snap = await tx.get(ref);
      const current = (snap.exists ? snap.data()?.nextOrderNumber : undefined) || 1;
      tx.update(ref, { nextOrderNumber: current + 1 });
      return current;
    }),
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
export const fakeStorage = new FakeStorage();

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
  fakeStorage.reset();
}

/**
 * Drop-in module for `services/firestore.service` backed by the shared `fakeDb`:
 * jest.mock('../../firestore.service', () => jest.requireActual('<path>/helpers/fake-firestore').firestoreServiceMock);
 */
export const firestoreServiceMock = fakeFirestoreModule(fakeDb, fakeStorage);
