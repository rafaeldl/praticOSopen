const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

/**
 * Tenta ler o projeto do .firebaserc
 */
function getFirebaseProject() {
  // Tentar vários caminhos possíveis
  const possiblePaths = [
    path.resolve(__dirname, '../../.firebaserc'),  // Raiz do projeto
    path.resolve(__dirname, '../../../.firebaserc'), // Se scripts estiver em firebase/scripts
    path.resolve(process.cwd(), '.firebaserc'),     // Diretório atual
  ];
  
  for (const firebasercPath of possiblePaths) {
    try {
      if (fs.existsSync(firebasercPath)) {
        const firebaserc = JSON.parse(fs.readFileSync(firebasercPath, 'utf8'));
        return firebaserc.projects?.default;
      }
    } catch (error) {
      // Continuar tentando outros caminhos
    }
  }
  return null;
}

/**
 * Inicializa o Firebase Admin SDK com suporte a múltiplas formas de autenticação
 * @param {string} serviceAccountPath - Caminho opcional para arquivo de service account
 * @param {string} projectId - ID do projeto Firebase (opcional)
 */
function initializeFirebase(serviceAccountPath = null, projectId = null) {
  // Verificar se já foi inicializado
  if (admin.apps.length > 0) {
    return admin.app();
  }

  // Prioridade: argumento > variável de ambiente > padrão
  const credentialsPath = serviceAccountPath || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const project = projectId || process.env.GCLOUD_PROJECT || getFirebaseProject() || 'praticos';

  try {
    if (credentialsPath && fs.existsSync(credentialsPath)) {
      const serviceAccount = require(path.resolve(credentialsPath));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: project
      });
      console.log('✓ Credenciais carregadas do arquivo:', credentialsPath);
      console.log(`✓ Projeto: ${project}`);
      return admin.app();
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      // Tentar usar credenciais padrão do ambiente
      admin.initializeApp({
        projectId: project
      });
      console.log('✓ Usando credenciais do ambiente (GOOGLE_APPLICATION_CREDENTIALS)');
      console.log(`✓ Projeto: ${project}`);
      return admin.app();
    } else {
      // Tentar inicializar sem credenciais (pode funcionar se estiver no ambiente do Firebase)
      admin.initializeApp({
        projectId: project
      });
      console.log('✓ Tentando usar credenciais padrão do ambiente...');
      console.log(`✓ Projeto: ${project}`);
      return admin.app();
    }
  } catch (error) {
    console.error('\n❌ ERRO: Não foi possível inicializar o Firebase Admin SDK');
    console.error('Erro:', error.message);
    console.error('\n⚠️  IMPORTANTE:');
    console.error('   O arquivo google-services.json (android/app/) é para o CLIENT SDK,');
    console.error('   não para o Admin SDK! Você precisa de um Service Account JSON diferente.\n');
    console.error('📋 SOLUÇÕES POSSÍVEIS:\n');
    console.error('1. Obter e usar arquivo de Service Account (RECOMENDADO):');
    console.error('   - Acesse: https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk');
    console.error('   - Clique em "Gerar nova chave privada"');
    console.error('   - Configure: export GOOGLE_APPLICATION_CREDENTIALS="/caminho/para/service-account.json"');
    console.error('   - Execute: npm run <script>\n');
    console.error('2. Ou passar o arquivo como argumento:');
    console.error('   npm run <script> /caminho/para/service-account.json\n');
    console.error('3. Ou usar gcloud CLI:');
    console.error('   gcloud auth application-default login');
    console.error('   npm run <script>\n');
    console.error('📖 Veja o guia completo: firebase/scripts/COMO_OBTER_CREDENCIAIS.md');
    console.error('🔍 Verifique suas credenciais: npm run verificar-credenciais\n');
    throw error;
  }
}

module.exports = { initializeFirebase, admin };

