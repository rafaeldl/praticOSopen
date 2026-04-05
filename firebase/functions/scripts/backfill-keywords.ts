/**
 * Backfill Keywords Script
 * Adds the `keywords` field to all services, products, devices and customers that don't have it.
 *
 * Usage (production - uses default credentials):
 *   npx ts-node scripts/backfill-keywords.ts
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 npx ts-node scripts/backfill-keywords.ts
 *
 * Dry run (no writes):
 *   npx ts-node scripts/backfill-keywords.ts --dry-run
 */

import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const DRY_RUN = process.argv.includes('--dry-run');

// --- Inlined from search.utils.ts to avoid import issues ---

function removeAccents(text: string): string {
  return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function generateKeywords(name: string | null | undefined): string[] {
  if (!name) return [];
  let normalized = removeAccents(name).toLowerCase();
  normalized = normalized.replace(/[^a-z0-9\s]/g, '');
  return normalized.split(/\s+/).filter((w) => w.length > 0);
}

const STOPWORDS = new Set([
  'de', 'da', 'do', 'das', 'dos',
  'e', 'ou', 'em', 'no', 'na', 'nos', 'nas',
  'um', 'uma', 'uns', 'umas',
  'o', 'a', 'os', 'as',
  'para', 'por', 'com', 'sem',
]);

function generateSearchKeywords(text: string | null | undefined): string[] {
  if (!text) return [];
  const allWords = generateKeywords(text);
  if (allWords.length === 0) return [];
  const meaningfulWords = allWords.filter((w) => !STOPWORDS.has(w));
  if (meaningfulWords.length === 0) return allWords;
  const keywords: string[] = [...meaningfulWords];
  if (meaningfulWords.length > 1) {
    keywords.push(meaningfulWords.join(' '));
  }
  return keywords;
}

// --- Script ---

async function backfillCollection(companyId: string, collectionName: string): Promise<number> {
  const collRef = db.collection(`companies/${companyId}/${collectionName}`);
  const snapshot = await collRef.get();

  let updated = 0;
  const batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();

    // Skip if already has keywords
    if (data.keywords && Array.isArray(data.keywords) && data.keywords.length > 0) {
      continue;
    }

    const name = data.name as string | undefined;
    if (!name) continue;

    const keywords = generateSearchKeywords(name);
    const nameLower = name.toLowerCase();

    if (DRY_RUN) {
      console.log(`  [DRY] ${collectionName}/${doc.id} "${name}" → keywords: [${keywords.join(', ')}]`);
    } else {
      batch.update(doc.ref, { keywords, nameLower });
      batchCount++;
    }

    updated++;

    // Firestore batch limit is 500
    if (batchCount >= 400) {
      await batch.commit();
      batchCount = 0;
    }
  }

  if (!DRY_RUN && batchCount > 0) {
    await batch.commit();
  }

  return updated;
}

async function main() {
  console.log(`\n🔧 Backfill Keywords ${DRY_RUN ? '(DRY RUN)' : '(LIVE)'}\n`);

  // Get all companies
  const companiesSnapshot = await db.collection('companies').get();
  console.log(`Found ${companiesSnapshot.size} companies\n`);

  const totals = { services: 0, products: 0, devices: 0, customers: 0 };
  const collections = ['services', 'products', 'devices', 'customers'] as const;

  for (const companyDoc of companiesSnapshot.docs) {
    const companyName = companyDoc.data().name || companyDoc.id;
    console.log(`📦 ${companyName} (${companyDoc.id})`);

    const results: Record<string, number> = {};
    let anyUpdated = false;
    for (const col of collections) {
      const count = await backfillCollection(companyDoc.id, col);
      results[col] = count;
      totals[col] += count;
      if (count > 0) anyUpdated = true;
    }

    if (anyUpdated) {
      console.log(`   ✅ ${collections.map((c) => `${c}: ${results[c]}`).join(', ')}`);
    } else {
      console.log(`   ⏭️  all up to date`);
    }
  }

  console.log(`\n✨ Done! Updated ${collections.map((c) => `${totals[c]} ${c}`).join(' + ')}\n`);
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
