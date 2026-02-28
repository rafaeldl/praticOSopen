/**
 * Seed script for public profile test data.
 *
 * Usage:
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
 *   npx tsx scripts/seed-profile.ts
 *
 * This creates:
 *   - profileSlugs/{slug} → { companyId }
 *   - companies/{companyId}/publicProfile/config → profile settings
 *   - companies/{companyId}/services → sample services
 *   - companies/{companyId}/orders → sample orders with ratings
 */

import { initializeApp, cert } from 'firebase-admin/app'
import { getFirestore, FieldValue } from 'firebase-admin/firestore'

const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS
if (!serviceAccount) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS env var to your service account JSON path')
  process.exit(1)
}

const app = initializeApp({ credential: cert(serviceAccount) })
const db = getFirestore(app)

const SLUG = 'tech-solutions-demo'
const COMPANY_ID = 'demo-profile-company'

async function seed() {
  console.log('Seeding profile data...')

  // 1. Create slug mapping
  await db.collection('profileSlugs').doc(SLUG).set({
    companyId: COMPANY_ID,
  })
  console.log(`  ✓ profileSlugs/${SLUG}`)

  // 2. Create company
  await db.collection('companies').doc(COMPANY_ID).set({
    name: 'Tech Solutions',
    description: 'Especialistas em manutenção e reparo de eletrônicos. Mais de 10 anos de experiência com smartphones, tablets, notebooks e muito mais.',
    segment: { id: 'electronics', name: 'Eletrônica' },
    phone: '+5511999887766',
    whatsapp: '+5511999887766',
    country: 'BR',
    city: 'São Paulo',
    state: 'SP',
    logo: '',
    address: {
      city: 'São Paulo',
      state: 'SP',
      country: 'BR',
    },
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true })
  console.log(`  ✓ companies/${COMPANY_ID}`)

  // 3. Create public profile config
  await db.collection('companies').doc(COMPANY_ID)
    .collection('publicProfile').doc('config').set({
      slug: SLUG,
      active: true,
      bio: 'Especialistas em manutenção e reparo de eletrônicos. Mais de 10 anos de experiência com smartphones, tablets, notebooks e muito mais.\n\nOferecemos garantia em todos os serviços e usamos apenas peças originais.',
      showAddress: true,
      showPhone: true,
      showWhatsapp: true,
      showPrices: true,
      portfolioPhotos: [
        { url: 'https://images.unsplash.com/photo-1588508065123-287b28e013da?w=400', description: 'Reparo de placa' },
        { url: 'https://images.unsplash.com/photo-1517404215738-15263e9f9178?w=400', description: 'Troca de tela' },
        { url: 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=400', description: 'Manutenção preventiva' },
        { url: 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400', description: 'Notebook' },
      ],
      hiddenReviews: [],
      verified: true,
      viewCount: 0,
      activatedAt: FieldValue.serverTimestamp(),
    })
  console.log(`  ✓ publicProfile/config`)

  // 4. Create sample services
  const services = [
    { name: 'Troca de Tela', value: 250, active: true },
    { name: 'Troca de Bateria', value: 150, active: true },
    { name: 'Reparo de Placa', value: 350, active: true },
    { name: 'Limpeza Interna', value: 80, active: true },
    { name: 'Troca de Conector de Carga', value: 120, active: true },
    { name: 'Formatação e Backup', value: 100, active: true },
    { name: 'Diagnóstico Completo', value: 50, active: true },
  ]

  const servicesRef = db.collection('companies').doc(COMPANY_ID).collection('services')
  for (const service of services) {
    await servicesRef.add({
      ...service,
      createdAt: FieldValue.serverTimestamp(),
    })
  }
  console.log(`  ✓ ${services.length} services`)

  // 5. Create sample orders with ratings
  const reviews = [
    { score: 5, comment: 'Excelente serviço! Trocaram a tela do meu iPhone em menos de 1 hora. Muito profissional.', customerName: 'Maria Silva' },
    { score: 5, comment: 'Super recomendo! Resolveram um problema que outras lojas não conseguiram.', customerName: 'João Santos' },
    { score: 4, comment: 'Bom atendimento e preço justo. Voltarei sempre que precisar.', customerName: 'Ana Oliveira' },
    { score: 5, comment: 'Notebook voltou como novo! Ótima experiência.', customerName: 'Pedro Costa' },
    { score: 4, comment: 'Serviço rápido e confiável. Recomendo!', customerName: 'Fernanda Lima' },
    { score: 5, comment: 'Profissionais muito competentes. Fizeram o diagnóstico certeiro.', customerName: 'Carlos Mendes' },
    { score: 5, comment: '', customerName: 'Lucas Pereira' },
    { score: 4, comment: 'Boa assistência técnica. Preço justo pelo serviço.', customerName: 'Beatriz Souza' },
  ]

  const ordersRef = db.collection('companies').doc(COMPANY_ID).collection('orders')
  const now = new Date()
  for (let i = 0; i < reviews.length; i++) {
    const daysAgo = i * 5 + Math.floor(Math.random() * 10)
    const date = new Date(now.getTime() - daysAgo * 86400000)
    await ordersRef.add({
      status: 'done',
      customer: { name: reviews[i].customerName },
      rating: {
        score: reviews[i].score,
        comment: reviews[i].comment,
        customerName: reviews[i].customerName,
        createdAt: date,
      },
      total: Math.floor(Math.random() * 400) + 50,
      createdAt: date,
      updatedAt: date,
    })
  }
  console.log(`  ✓ ${reviews.length} orders with ratings`)

  console.log(`\nDone! Visit /pro/${SLUG} to see the profile.`)
}

seed().catch(console.error)
