/**
 * Setup Test Data Script
 * Creates test data for local API testing with the bot
 *
 * Usage:
 *   npx ts-node scripts/setup-test-data.ts
 *
 * Note: Run this while the emulator is running
 */

import * as admin from 'firebase-admin';

// Connect to emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

admin.initializeApp({
  projectId: 'praticos-app',
});

const db = admin.firestore();

async function setupTestData() {
  console.log('🚀 Setting up test data...\n');

  // 1. Create Bot API Key
  console.log('📌 Creating Bot API Key...');
  await db.collection('apiKeys').doc('bot_praticos').set({
    key: 'bot_praticos_dev_key',
    type: 'bot',
    active: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('   ✅ API Key: bot_praticos_dev_key\n');

  // 2. Create Test User
  const userId = 'test_user_001';
  console.log('📌 Creating Test User...');
  await db.collection('users').doc(userId).set({
    name: 'Rafael Teste',
    email: 'rafael@teste.com',
    phone: '+5548984090709',
    companies: [
      {
        company: {
          id: 'test_company_001',
          name: 'Assistência Técnica Teste',
        },
        role: 'owner',
      },
    ],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`   ✅ User: ${userId} (Rafael Teste)\n`);

  // 3. Create Test Company
  const companyId = 'test_company_001';
  console.log('📌 Creating Test Company...');
  await db.collection('companies').doc(companyId).set({
    name: 'Assistência Técnica Teste',
    segment: 'electronics',
    country: 'BR',
    phone: '+5548999999999',
    email: 'contato@assistenciateste.com',
    address: 'Rua Teste, 123 - Florianópolis/SC',
    nextOrderNumber: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`   ✅ Company: ${companyId}\n`);

  // 4. Create WhatsApp Link
  const whatsappNumber = '+5548984090709';
  console.log('📌 Creating WhatsApp Link...');
  await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .doc(whatsappNumber)
    .set({
      channel: 'whatsapp',
      identifier: whatsappNumber,
      userId: userId,
      companyId: companyId,
      role: 'owner',
      userName: 'Rafael Teste',
      companyName: 'Assistência Técnica Teste',
      linkedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  console.log(`   ✅ WhatsApp: ${whatsappNumber} → ${userId}\n`);

  // 5. Create Some Test Customers
  console.log('📌 Creating Test Customers...');
  const customers = [
    { name: 'João Silva', phone: '+5548999111111' },
    { name: 'Maria Souza', phone: '+5548999222222' },
    { name: 'Pedro Santos', phone: '+5548999333333' },
  ];

  for (const customer of customers) {
    const customerId = `customer_${customer.name.replace(/\s/g, '_').toLowerCase()}`;
    await db
      .collection('companies')
      .doc(companyId)
      .collection('customers')
      .doc(customerId)
      .set({
        name: customer.name,
        phone: customer.phone,
        company: { id: companyId, name: 'Assistência Técnica Teste' },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: { id: userId, name: 'Rafael Teste' },
      });
    console.log(`   ✅ Customer: ${customer.name}`);
  }
  console.log('');

  // 6. Create Some Test Devices
  console.log('📌 Creating Test Devices...');
  const devices = [
    { name: 'iPhone 14 Pro', serial: 'DNPXXX123' },
    { name: 'Samsung Galaxy S23', serial: 'RF8XXX456' },
    { name: 'MacBook Pro M2', serial: 'C02XXX789' },
  ];

  for (const device of devices) {
    const deviceId = `device_${device.serial}`;
    await db
      .collection('companies')
      .doc(companyId)
      .collection('devices')
      .doc(deviceId)
      .set({
        name: device.name,
        serial: device.serial,
        company: { id: companyId, name: 'Assistência Técnica Teste' },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: { id: userId, name: 'Rafael Teste' },
      });
    console.log(`   ✅ Device: ${device.name} (${device.serial})`);
  }
  console.log('');

  // 7. Create Some Test Services (catalog)
  console.log('📌 Creating Test Services (catalog)...');
  const services = [
    { name: 'Troca de Tela', value: 350 },
    { name: 'Troca de Bateria', value: 180 },
    { name: 'Formatação', value: 100 },
    { name: 'Diagnóstico', value: 50 },
  ];

  for (const service of services) {
    const serviceId = `service_${service.name.replace(/\s/g, '_').toLowerCase()}`;
    await db
      .collection('companies')
      .doc(companyId)
      .collection('services')
      .doc(serviceId)
      .set({
        name: service.name,
        value: service.value,
        company: { id: companyId, name: 'Assistência Técnica Teste' },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    console.log(`   ✅ Service: ${service.name} - R$ ${service.value}`);
  }
  console.log('');

  // 8. Create Test Orders
  console.log('📌 Creating Test Orders...');
  const orders = [
    {
      number: 1,
      customer: { id: 'customer_joão_silva', name: 'João Silva', phone: '+5548999111111' },
      device: { id: 'device_DNPXXX123', name: 'iPhone 14 Pro', serial: 'DNPXXX123' },
      status: 'quote',
      total: 350,
      paidAmount: 0,
      problem: 'Tela trincada',
    },
    {
      number: 2,
      customer: { id: 'customer_maria_souza', name: 'Maria Souza', phone: '+5548999222222' },
      device: { id: 'device_RF8XXX456', name: 'Samsung Galaxy S23', serial: 'RF8XXX456' },
      status: 'approved',
      total: 180,
      paidAmount: 90,
      problem: 'Bateria não segura carga',
    },
    {
      number: 3,
      customer: { id: 'customer_pedro_santos', name: 'Pedro Santos', phone: '+5548999333333' },
      device: { id: 'device_C02XXX789', name: 'MacBook Pro M2', serial: 'C02XXX789' },
      status: 'progress',
      total: 400,
      paidAmount: 200,
      dueDate: new Date(Date.now() + 24 * 60 * 60 * 1000), // Tomorrow
      problem: 'Não liga, sem imagem',
    },
  ];

  for (const order of orders) {
    const orderId = `order_${order.number.toString().padStart(6, '0')}`;
    await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderId)
      .set({
        ...order,
        remainingBalance: order.total - order.paidAmount,
        company: { id: companyId, name: 'Assistência Técnica Teste' },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: { id: userId, name: 'Rafael Teste' },
      });
    console.log(`   ✅ Order #${order.number}: ${order.customer.name} - ${order.device.name} (${order.status})`);
  }
  console.log('');

  // Update nextOrderNumber
  await db.collection('companies').doc(companyId).update({
    nextOrderNumber: orders.length + 1,
  });

  console.log('✅ Test data setup complete!\n');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📋 Summary:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`   API Key:     bot_praticos_dev_key`);
  console.log(`   WhatsApp:    ${whatsappNumber}`);
  console.log(`   User:        ${userId} (Rafael Teste)`);
  console.log(`   Company:     ${companyId}`);
  console.log(`   Customers:   ${customers.length}`);
  console.log(`   Devices:     ${devices.length}`);
  console.log(`   Services:    ${services.length}`);
  console.log(`   Orders:      ${orders.length}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  console.log('🧪 Test the API:');
  console.log('');
  console.log('# Health check');
  console.log('curl http://localhost:5001/praticos-app/southamerica-east1/api/health');
  console.log('');
  console.log('# Get user context');
  console.log(`curl -H "X-API-Key: bot_praticos_dev_key" -H "X-WhatsApp-Number: ${whatsappNumber}" \\`);
  console.log('  http://localhost:5001/praticos-app/southamerica-east1/api/api/bot/link/context');
  console.log('');
  console.log('# Get summary');
  console.log(`curl -H "X-API-Key: bot_praticos_dev_key" -H "X-WhatsApp-Number: ${whatsappNumber}" \\`);
  console.log('  http://localhost:5001/praticos-app/southamerica-east1/api/api/bot/summary/today');
  console.log('');

  process.exit(0);
}

setupTestData().catch((error) => {
  console.error('❌ Error setting up test data:', error);
  process.exit(1);
});
