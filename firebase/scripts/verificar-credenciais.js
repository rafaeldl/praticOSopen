#!/usr/bin/env node

/**
 * Script para verificar se as credenciais do Firebase Admin SDK estão configuradas corretamente
 */

const fs = require('fs');
const path = require('path');

console.log('════════════════════════════════════════════════════════════');
console.log('  VERIFICAÇÃO DE CREDENCIAIS - Firebase Admin SDK');
console.log('════════════════════════════════════════════════════════════\n');

// Verificar variável de ambiente
const envCreds = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (envCreds) {
  console.log('✓ Variável GOOGLE_APPLICATION_CREDENTIALS encontrada:');
  console.log(`  ${envCreds}\n`);
  
  if (fs.existsSync(envCreds)) {
    try {
      const creds = JSON.parse(fs.readFileSync(envCreds, 'utf8'));
      
      if (creds.type === 'service_account') {
        console.log('✓ Arquivo é um Service Account válido!');
        console.log(`  Project ID: ${creds.project_id}`);
        console.log(`  Client Email: ${creds.client_email}`);
        console.log(`  Private Key: ${creds.private_key ? '✓ Presente' : '❌ Ausente'}\n`);
        console.log('✅ Credenciais configuradas corretamente!\n');
        process.exit(0);
      } else {
        console.log('❌ Arquivo não é um Service Account válido!');
        console.log('   O arquivo parece ser do tipo:', creds.type || 'desconhecido');
        console.log('   Você precisa de um Service Account JSON, não um google-services.json\n');
      }
    } catch (error) {
      console.log('❌ Erro ao ler o arquivo:', error.message);
      console.log('   Verifique se o arquivo JSON é válido\n');
    }
  } else {
    console.log('❌ Arquivo não encontrado no caminho especificado!\n');
  }
} else {
  console.log('⚠️  Variável GOOGLE_APPLICATION_CREDENTIALS não está configurada\n');
}

// Verificar se há google-services.json (não serve, mas vamos avisar)
const googleServicesPath = path.resolve(__dirname, '../../android/app/google-services.json');
if (fs.existsSync(googleServicesPath)) {
  console.log('ℹ️  Encontrado google-services.json (android/app/google-services.json)');
  console.log('   ⚠️  Este arquivo é para o CLIENT SDK (app Flutter), não para Admin SDK!\n');
  
  try {
    const gs = JSON.parse(fs.readFileSync(googleServicesPath, 'utf8'));
    console.log(`   Project ID do app: ${gs.project_info?.project_id || 'não encontrado'}`);
    console.log('   Este arquivo NÃO pode ser usado nos scripts Node.js\n');
  } catch (error) {
    // Ignorar
  }
}

// Instruções
console.log('📋 PRÓXIMOS PASSOS:\n');
console.log('1. Obtenha um Service Account JSON:');
console.log('   https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk\n');
console.log('2. Configure a variável de ambiente:');
console.log('   export GOOGLE_APPLICATION_CREDENTIALS="/caminho/para/service-account.json"\n');
console.log('3. Ou passe como argumento ao executar os scripts:');
console.log('   npm run refresh-claims /caminho/para/service-account.json\n');
console.log('📖 Veja o guia completo: firebase/scripts/COMO_OBTER_CREDENCIAIS.md\n');

process.exit(1);

