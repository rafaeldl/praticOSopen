#!/usr/bin/env node
/**
 * Rebuilds the data of the three demo accounts (docs/DEMO_ACCOUNTS.md) for
 * store screenshots: fictional customers and vehicles, orders in every
 * status with dates relative to today, payments this month, a completed
 * checklist with photos and a customer rating.
 *
 * Touches ONLY the demo companies below. Deletes their orders (with the
 * order forms), customers and devices, and the files under
 * tenants/{companyId}/orders/ and /devices/ in Storage, then writes the
 * new data. Services, products and checklist templates stay.
 *
 * Photos come from ./demo_store_photos (public domain, see CREDITS.md).
 *
 * Usage (Application Default Credentials with access to project praticos):
 *   node seed_demo_store_data.js            # dry run: prints what it would do
 *   node seed_demo_store_data.js --apply    # writes
 *   node seed_demo_store_data.js --apply --locale pt-BR
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const path = require('path');

const PHOTOS_DIR = path.join(__dirname, 'demo_store_photos');

const DEMO = {
  'pt-BR': {
    email: 'demo-pt@praticos.com.br',
    companyId: '9q6xWooL73LdmgeJJo7L',
    userName: 'Paulo Andrade',
    customers: [
      ['Marcos Pereira', '(11) 90000-1001'],
      ['Juliana Costa', '(11) 90000-1002'],
      ['Ricardo Almeida', '(11) 90000-1003'],
      ['Fernanda Lima', '(11) 90000-1004'],
      ['Carlos Souza', '(11) 90000-1005'],
      ['Patrícia Rocha', '(11) 90000-1006'],
    ],
    vehicles: [
      ['Corolla 2.0 2021', 'Toyota', 'Sedã'],
      ['Onix 1.0 2020', 'Chevrolet', 'Hatch'],
      ['HB20 1.6 2019', 'Hyundai', 'Hatch'],
      ['Compass 2.0 2022', 'Jeep', 'SUV'],
      ['Gol 1.6 2016', 'Volkswagen', 'Hatch'],
      ['Kwid 1.0 2021', 'Renault', 'Hatch'],
    ],
    note: {
      fuel: '3/4',
      belongings: 'Estepe e triângulo no porta-malas',
      rating: 'Serviço rápido e explicaram tudo. Recomendo!',
      partial: 'Sinal',
    },
  },
  'en-US': {
    email: 'demo-en@praticos.com.br',
    companyId: '2KYAWVNBILJOeT92FRU9',
    userName: 'Michael Johnson',
    customers: [
      ['Mark Peterson', '(555) 010-1001'],
      ['Julia Carter', '(555) 010-1002'],
      ['Richard Allen', '(555) 010-1003'],
      ['Emily Brooks', '(555) 010-1004'],
      ['Chris Sullivan', '(555) 010-1005'],
      ['Patricia Reed', '(555) 010-1006'],
    ],
    vehicles: [
      ['Camry 2.5 2021', 'Toyota', 'Sedan'],
      ['Civic 2.0 2020', 'Honda', 'Sedan'],
      ['F-150 3.5 2019', 'Ford', 'Pickup'],
      ['Wrangler 3.6 2022', 'Jeep', 'SUV'],
      ['Malibu 1.5 2017', 'Chevrolet', 'Sedan'],
      ['Altima 2.5 2019', 'Nissan', 'Sedan'],
    ],
    note: {
      fuel: '3/4',
      belongings: 'Spare tire and jack in the trunk',
      rating: 'Quick job and they explained everything. Recommended!',
      partial: 'Deposit',
    },
  },
  'es-ES': {
    email: 'demo-es@praticos.com.br',
    companyId: 'xL2GRPiVF8LAnz8524iu',
    userName: 'Carlos Rodríguez',
    customers: [
      ['Marcos Pérez', '600 000 101'],
      ['Julia Martín', '600 000 102'],
      ['Ricardo Gómez', '600 000 103'],
      ['Elena Navarro', '600 000 104'],
      ['Javier Ruiz', '600 000 105'],
      ['Lucía Moreno', '600 000 106'],
    ],
    vehicles: [
      ['León 1.5 2021', 'Seat', 'Compacto'],
      ['Clio 1.0 2020', 'Renault', 'Compacto'],
      ['Golf 2.0 2019', 'Volkswagen', 'Compacto'],
      ['Corolla 1.8 2022', 'Toyota', 'Berlina'],
      ['308 1.2 2018', 'Peugeot', 'Compacto'],
      ['Sandero 1.0 2021', 'Dacia', 'Compacto'],
    ],
    note: {
      fuel: '3/4',
      belongings: 'Rueda de repuesto y triángulos en el maletero',
      rating: 'Rápidos y me lo explicaron todo. ¡Muy recomendables!',
      partial: 'Señal',
    },
  },
};

// Service names per locale, matched against the company's catalog by name.
const SERVICES = {
  oil: ['Troca de óleo', 'Oil Change', 'Cambio de aceite'],
  alignment: ['Alinhamento', 'Wheel Alignment', 'Alineación'],
  balancing: ['Balanceamento', 'Wheel Balancing', 'Balanceo'],
  diagnosis: ['Diagnóstico eletrônico', 'Electronic Diagnosis', 'Diagnóstico electrónico'],
  brakeCheck: ['Revisão de freios', 'Brake Inspection', 'Revisión de frenos'],
  timingBelt: ['Troca de correia dentada', 'Timing Belt Replacement', 'Cambio de correa de distribución'],
  ac: ['Higienização do ar', 'AC Sanitization', 'Higienización del aire'],
  pads: ['Troca de pastilhas de freio', 'Brake Pad Replacement', 'Cambio de pastillas de freno'],
};
const PRODUCTS = {
  oil: ['Óleo 5W30 Sintético (1L)', '5W30 Synthetic Oil (1L)', 'Aceite 5W30 Sintético (1L)'],
  oilFilter: ['Filtro de óleo', 'Oil Filter', 'Filtro de aceite'],
  airFilter: ['Filtro de ar', 'Air Filter', 'Filtro de aire'],
  pads: ['Pastilha de freio dianteira (jogo)', 'Front Brake Pads (set)', 'Pastillas de freno delanteras (juego)'],
  plug: ['Vela de ignição', 'Spark Plug', 'Bujía'],
  fluid: ['Fluido de freio DOT 4 (500ml)', 'DOT 4 Brake Fluid (500ml)', 'Líquido de frenos DOT 4 (500ml)'],
};
const LOCALE_INDEX = { 'pt-BR': 0, 'en-US': 1, 'es-ES': 2 };

/**
 * The orders, newest first. `day` is relative to today, `at` is the time
 * of day ("HH:MM"). The first order (it tops Início and carries the
 * checklist) is due tomorrow and none is late; rerun the script on the day
 * of the screenshots.
 */
const ORDERS = [
  {
    key: 'hero', customer: 0, vehicle: 0, status: 'progress',
    services: ['oil', 'brakeCheck'], products: [['oil', 4], ['oilFilter', 1]],
    created: -1, scheduled: [0, '08:30'], due: [1, '12:00'],
    photos: ['engine_bay_1', 'spark_plugs'], paid: 100, checklist: true,
  },
  {
    key: 'quote', customer: 1, vehicle: 1, status: 'quote',
    services: ['pads'], products: [['pads', 1], ['fluid', 1]],
    created: 0, due: [3, '18:00'], photos: ['wheel_white'],
  },
  {
    key: 'approved', customer: 2, vehicle: 2, status: 'approved',
    services: ['timingBelt'], products: [],
    created: -2, scheduled: [1, '09:00'], due: [2, '18:00'],
    photos: ['engine_bay_3'],
  },
  {
    key: 'diagnosis', customer: 3, vehicle: 3, status: 'progress',
    services: ['diagnosis'], products: [['plug', 4]],
    created: -1, scheduled: [0, '14:00'], due: [1, '17:00'],
    photos: ['engine_bay_2', 'battery'],
  },
  {
    key: 'tires', customer: 4, vehicle: 4, status: 'approved',
    services: ['alignment', 'balancing'], products: [],
    created: -1, scheduled: [2, '10:30'], due: [2, '16:00'],
    photos: ['worn_tire'],
  },
  {
    key: 'doneUnpaid', customer: 5, vehicle: 5, status: 'done',
    services: ['ac'], products: [['airFilter', 1]],
    created: -6, scheduled: [-5, '11:00'], due: [-4, '17:00'], done: -4,
    photos: ['engine_bay_4'],
  },
  {
    key: 'donePaid', customer: 1, vehicle: 1, status: 'done',
    services: ['oil'], products: [['oil', 4], ['oilFilter', 1]],
    created: -9, due: [-8, '17:00'], done: -8, paid: 'all', paidDay: -8,
    photos: ['wheel_alloy'], rating: true,
  },
  {
    key: 'donePaid2', customer: 0, vehicle: 0, status: 'done',
    services: ['pads'], products: [['pads', 1]],
    created: -12, due: [-11, '17:00'], done: -11, paid: 'all', paidDay: -11,
    photos: ['wheel_red'],
  },
];

const APPLY = process.argv.includes('--apply');
const ONLY = (() => {
  const i = process.argv.indexOf('--locale');
  return i > 0 ? process.argv[i + 1] : null;
})();

admin.initializeApp({ projectId: 'praticos', storageBucket: 'praticos.appspot.com' });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const pad = (n) => String(n).padStart(2, '0');
/** Local ISO string without zone, the format the app writes. */
function iso(dayOffset, time = '12:00') {
  const [h, m] = time.split(':').map(Number);
  const d = new Date();
  d.setDate(d.getDate() + dayOffset);
  d.setHours(h, m, 0, 0);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    `T${pad(d.getHours())}:${pad(d.getMinutes())}:00.000`;
}
const newId = () => db.collection('_').doc().id;

async function uploadPhoto(storagePath, name) {
  const token = crypto.randomUUID();
  await bucket.upload(path.join(PHOTOS_DIR, `${name}.jpg`), {
    destination: storagePath,
    metadata: {
      contentType: 'image/jpeg',
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
}

async function deleteCollection(ref) {
  const snap = await ref.get();
  for (const doc of snap.docs) {
    for (const sub of await doc.ref.listCollections()) await deleteCollection(sub);
    await doc.ref.delete();
  }
  return snap.size;
}

async function seed(locale) {
  const cfg = DEMO[locale];
  const li = LOCALE_INDEX[locale];
  const cid = cfg.companyId;
  const companyRef = db.doc(`companies/${cid}`);
  const company = (await companyRef.get()).data();
  const user = await admin.auth().getUserByEmail(cfg.email);
  if (!company || company.owner?.id !== user.uid) {
    throw new Error(`${locale}: company ${cid} is not owned by ${cfg.email}`);
  }
  const by = { id: user.uid, email: cfg.email, name: cfg.userName, photo: null };
  const companyAggr = { id: cid, name: company.name, country: company.country };

  const catalog = async (col) => {
    const snap = await db.collection(`companies/${cid}/${col}`).get();
    return Object.fromEntries(snap.docs.map((d) => [d.data().name, { id: d.id, ...d.data() }]));
  };
  const services = await catalog('services');
  const products = await catalog('products');
  const pick = (table, map, key) => {
    const item = map[table[key][li]];
    if (!item) throw new Error(`${locale}: "${table[key][li]}" not in catalog`);
    return item;
  };
  const checklist = (await db.doc(`companies/${cid}/forms/checklist_entrada_auto`).get()).data();
  if (!checklist) throw new Error(`${locale}: checklist_entrada_auto missing`);

  console.log(`\n== ${locale} · ${company.name} (${cid})`);
  console.log(`   ${cfg.customers.length} customers, ${cfg.vehicles.length} vehicles, ${ORDERS.length} orders`);
  for (const o of ORDERS) {
    console.log(`   - ${o.status.padEnd(8)} ${cfg.customers[o.customer][0]} · ${cfg.vehicles[o.vehicle][0]}` +
      ` · ${o.services.map((s) => pick(SERVICES, services, s).name).join(' + ')}` +
      (o.scheduled ? ` · agenda ${iso(...o.scheduled).slice(0, 16)}` : ''));
  }
  if (!APPLY) return;

  // 1. Clean up the demo company's records and files.
  for (const col of ['orders', 'customers', 'devices']) {
    const n = await deleteCollection(db.collection(`companies/${cid}/${col}`));
    console.log(`   deleted ${n} ${col}`);
  }
  for (const prefix of [`tenants/${cid}/orders/`, `tenants/${cid}/devices/`]) {
    await bucket.deleteFiles({ prefix, force: true });
  }

  // 2. Customers and vehicles.
  const now = iso(0, '08:00');
  const audit = { createdAt: now, updatedAt: now, createdBy: by, updatedBy: by };
  const customers = [];
  for (const [name, phone] of cfg.customers) {
    const ref = db.collection(`companies/${cid}/customers`).doc();
    await ref.set({ ...audit, id: ref.id, name, phone, email: null, address: null, company: null });
    customers.push({ id: ref.id, name, phone, email: null });
  }
  const vehicles = [];
  for (const [name, manufacturer, category] of cfg.vehicles) {
    const ref = db.collection(`companies/${cid}/devices`).doc();
    await ref.set({
      ...audit, id: ref.id, name, manufacturer, category,
      serial: null, description: null, photo: null, company: null,
    });
    vehicles.push({ id: ref.id, name, serial: null, photo: null });
  }

  // 3. Orders, oldest number first.
  const ordered = [...ORDERS].sort((a, b) => a.created - b.created);
  let number = 1;
  for (const o of ordered) {
    const ref = db.collection(`companies/${cid}/orders`).doc();
    const svc = o.services.map((k) => {
      const s = pick(SERVICES, services, k);
      return { service: { id: s.id, name: s.name, value: s.value, photo: null }, value: s.value, description: null, photo: null };
    });
    const prods = o.products.map(([k, qty]) => {
      const p = pick(PRODUCTS, products, k);
      return {
        product: { id: p.id, name: p.name, value: p.value, photo: null },
        value: p.value, quantity: qty, total: p.value * qty, description: null, photo: null,
      };
    });
    const total = svc.reduce((s, x) => s + x.value, 0) + prods.reduce((s, x) => s + x.total, 0);
    const created = iso(o.created, '09:15');

    const photos = [];
    for (const name of o.photos) {
      const id = `${Date.now()}-${photos.length}`;
      const storagePath = `tenants/${cid}/orders/${ref.id}/photos/${id}.jpg`;
      photos.push({ id, storagePath, url: await uploadPhoto(storagePath, name), createdAt: created, createdBy: by });
    }

    let transactions = null;
    let paidAmount = null;
    let payment = o.status === 'quote' ? null : 'unpaid';
    if (o.paid) {
      const amount = o.paid === 'all' ? total : o.paid;
      transactions = [{
        id: newId(), type: 'payment', amount,
        description: o.paid === 'all' ? null : cfg.note.partial,
        createdAt: iso(o.paidDay ?? o.created, '17:30'), createdBy: by, receiptDocumentId: null,
      }];
      paidAmount = amount;
      if (amount >= total) payment = 'paid';
    }

    const doc = {
      id: ref.id, number: number++, company: companyAggr,
      customer: customers[o.customer], device: vehicles[o.vehicle],
      services: svc, products: prods, total, discount: 0,
      status: o.status, payment, paidAmount, paid: null, transactions,
      photos, assignedTo: null, rating: null, shareLink: null,
      createdAt: created, updatedAt: created, createdBy: by, updatedBy: by,
      scheduledDate: o.scheduled ? iso(...o.scheduled) : null,
      dueDate: o.due ? iso(...o.due) : null,
      done: null,
    };
    if (o.rating) {
      doc.rating = {
        score: 5, comment: cfg.note.rating,
        createdAt: iso(o.done + 1, '10:00'), customerName: customers[o.customer].name,
      };
    }
    await ref.set(doc);

    if (o.checklist) {
      const formRef = ref.collection('forms').doc();
      const shots = [];
      for (const name of ['wheel_alloy', 'engine_bay_2']) {
        const sp = `tenants/${cid}/orders/${ref.id}/forms/${formRef.id}/items/lataria_fotos/${name}.jpg`;
        shots.push(await uploadPhoto(sp, name));
      }
      const items = checklist.items.map((i) => ({ labelI18n: null, optionsI18n: null, options: null, ...i }));
      const fuelOptions = items.find((i) => i.id === 'nivel_combustivel')?.options || [];
      await formRef.set({
        formDefinitionId: 'checklist_entrada_auto',
        title: checklist.title, titleI18n: null, items,
        status: 'completed',
        startedAt: iso(0, '08:35'), completedAt: iso(0, '08:42'), updatedAt: iso(0, '08:42'),
        responses: [
          { itemId: 'lataria_fotos', value: null, photoUrls: shots },
          { itemId: 'nivel_combustivel', value: fuelOptions[3] ?? cfg.note.fuel, photoUrls: [] },
          { itemId: 'luzes_painel', value: [], photoUrls: [] },
          { itemId: 'km_atual', value: 48210, photoUrls: [] },
          { itemId: 'pertences', value: cfg.note.belongings, photoUrls: [] },
        ],
      });
    }
  }

  // 4. Company counters, the demo user's name (no real names) and AI on.
  await companyRef.update({
    nextOrderNumber: number,
    lastOrderDate: iso(0, '09:15'),
    'owner.name': cfg.userName,
  });
  await db.doc(`users/${user.uid}`).update({ name: cfg.userName, photo: null });
  await db.doc(`companies/${cid}/memberships/${user.uid}`).update({
    'user.name': cfg.userName, 'user.photo': null,
  });
  await db.doc(`companies/${cid}/settings/ai`).set({ enabled: true }, { merge: true });
  console.log(`   ✓ seeded ${ORDERS.length} orders`);
}

(async () => {
  const locales = ONLY ? [ONLY] : Object.keys(DEMO);
  console.log(APPLY ? 'APPLY: writing demo data' : 'DRY RUN (pass --apply to write)');
  for (const l of locales) await seed(l);
  process.exit(0);
})().catch((e) => {
  console.error('❌', e.message);
  process.exit(1);
});
