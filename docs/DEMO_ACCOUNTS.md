# Demo Accounts - Multi-Locale Setup

Este documento contém as informações necessárias para criar as contas demo em cada idioma para captura de screenshots e testes.

## Contas Criadas no Firebase Auth

| Email | Password | Locale | Status |
|-------|----------|--------|--------|
| demo-pt@praticos.com.br | Demo@2024! | pt-BR | ✅ Criado |
| demo-en@praticos.com.br | Demo@2024! | en-US | ✅ Criado |
| demo-es@praticos.com.br | Demo@2024! | es-ES | ✅ Criado |

---

## 🇧🇷 Português (pt-BR)

### Conta
- **Email**: demo-pt@praticos.com.br
- **Senha**: Demo@2024!
- **Nome do Usuário**: Rafael Oliveira

### Dados da Empresa
- **Nome da Empresa**: Auto Mecânica São Paulo
- **Endereço**: Avenida Paulista, 1578 - Bela Vista, São Paulo - SP, 01310-200
- **Telefone**: (11) 3251-4000
- **Email**: contato@automecsp.com.br
- **Website**: www.automecsp.com.br

### Segmento e Especialização
- **Segmento**: 🚗 Automotivo (Automotive)
- **Especialização**: Oficina Mecânica (Mechanical)
  - ID do segmento: `automotive`
  - ID da especialização: `mechanical`

### Dados de Exemplo (Bootstrap)
Ao finalizar o onboarding, escolher **"Sim, criar dados de exemplo"** para gerar:
- ✅ 10 clientes fictícios
- ✅ 10 dispositivos (veículos)
- ✅ 10 serviços
- ✅ 10 produtos
- ✅ 4 ordens de serviço com status variados

---

## 🇺🇸 English (en-US)

### Account
- **Email**: demo-en@praticos.com.br
- **Password**: Demo@2024!
- **User Name**: Michael Johnson

### Company Data
- **Company Name**: Pro Auto Repair Shop
- **Address**: 350 5th Avenue, New York, NY 10118, USA
- **Phone**: +1 (212) 736-3100
- **Email**: contact@proautorepair.com
- **Website**: www.proautorepair.com

### Segment and Specialization
- **Segment**: 🚗 Automotive
- **Specialization**: Auto Repair Shop (Mechanical)
  - Segment ID: `automotive`
  - Specialization ID: `mechanical`

### Sample Data (Bootstrap)
When finishing onboarding, choose **"Yes, create sample data"** to generate:
- ✅ 10 fictional customers
- ✅ 10 devices (vehicles)
- ✅ 10 services
- ✅ 10 products
- ✅ 4 service orders with varied statuses

---

## 🇪🇸 Español (es-ES)

### Cuenta
- **Email**: demo-es@praticos.com.br
- **Contraseña**: Demo@2024!
- **Nombre del Usuario**: Carlos Rodríguez

### Datos de la Empresa
- **Nombre de la Empresa**: Taller Mecánico Madrid
- **Dirección**: Calle Gran Vía, 28, 28013 Madrid, España
- **Teléfono**: +34 915 21 29 00
- **Email**: contacto@tallermadrid.es
- **Website**: www.tallermadrid.es

### Segmento y Especialización
- **Segmento**: 🚗 Automotriz (Automotive)
- **Especialización**: Taller Mecánico (Mechanical)
  - ID del segmento: `automotive`
  - ID de la especialización: `mechanical`

### Datos de Ejemplo (Bootstrap)
Al finalizar la incorporación, elegir **"Sí, crear datos de ejemplo"** para generar:
- ✅ 10 clientes ficticios
- ✅ 10 dispositivos (vehículos)
- ✅ 10 servicios
- ✅ 10 productos
- ✅ 4 órdenes de servicio con estados variados

---

## Processo de Criação Manual (Onboarding)

Para cada conta, seguir os seguintes passos:

### 1. Login
1. Abrir o app
2. Clicar em "Já tenho conta com e-mail" / "I already have an account with email" / "Ya tengo cuenta con correo"
3. Inserir email e senha correspondentes
4. Fazer login

### 2. Onboarding - Dados da Empresa
1. **Nome da Empresa**: Usar o nome correspondente ao idioma
2. **Foto/Logo**: (Opcional) Pode pular ou adicionar uma logo genérica
3. Avançar

### 3. Onboarding - Contato
1. **Endereço**: Usar o endereço correspondente
2. **Telefone**: Usar o telefone correspondente
3. **Email**: Usar o email corporativo correspondente
4. **Website**: Usar o website correspondente
5. Avançar

### 4. Onboarding - Segmento
1. Selecionar: **🚗 Automotivo** / **Automotive** / **Automotriz**
2. Avançar

### 5. Onboarding - Especialização
1. Selecionar: **Oficina Mecânica** / **Auto Repair Shop** / **Taller Mecánico**
2. Avançar

### 6. Onboarding - Dados de Exemplo
1. Escolher: **"Sim, criar dados de exemplo"** / **"Yes, create sample data"** / **"Sí, crear datos de ejemplo"**
2. Finalizar

### 7. Verificação
Após completar o onboarding, verificar:
- ✅ Empresa criada com dados corretos
- ✅ 10 clientes criados
- ✅ 10 dispositivos criados
- ✅ 10 serviços criados
- ✅ 4 OSs criadas com status:
  - OS #1: `quote` (Orçamento)
  - OS #2: `approved` (Aprovado)
  - OS #3: `progress` (Em Andamento)
  - OS #4: `done` (Concluído)

---

## Status das Ordens de Serviço (Demo)

As 4 OSs criadas automaticamente têm os seguintes status:

| # | Status | Descrição PT | Description EN | Descripción ES |
|---|--------|--------------|----------------|----------------|
| 1 | `quote` | Orçamento | Quote | Presupuesto |
| 2 | `approved` | Aprovado | Approved | Aprobado |
| 3 | `progress` | Em Andamento | In Progress | En Progreso |
| 4 | `done` | Concluído | Completed | Completado |

---

## Uso nos Testes de Screenshot

O arquivo `integration_test/screenshot_test.dart` usa automaticamente a conta correta baseada no locale:

```dart
String _getEmailByLocale(String locale) {
  switch (locale) {
    case 'pt-BR':
      return 'demo-pt@praticos.com.br';
    case 'en-US':
      return 'demo-en@praticos.com.br';
    case 'es-ES':
      return 'demo-es@praticos.com.br';
    default:
      return 'demo@praticos.com.br';
  }
}
```

### Executar Testes

```bash
# Capturar screenshots para todos os idiomas
cd ios
bundle exec fastlane capture_ios_screenshots

# Capturar apenas um idioma específico
LOCALE=pt-BR bundle exec fastlane capture_ios_screenshots
LOCALE=en-US bundle exec fastlane capture_ios_screenshots
LOCALE=es-ES bundle exec fastlane capture_ios_screenshots
```

---

## Notas Importantes

1. **Factory Reset**: Os testes fazem factory reset do simulador antes de cada execução
2. **Bootstrap Automático**: Ao escolher "criar dados de exemplo", o `BootstrapService` cria automaticamente todos os dados
3. **Locale do Simulador**: É alterado automaticamente pelo Fastlane antes de cada teste
4. **Screenshots**: Salvos em `ios/fastlane/screenshots/{locale}/`

---

## Troubleshooting

### Problema: OSs não foram criadas
**Solução**: Verificar se escolheu "Sim, criar dados de exemplo" no último passo do onboarding

### Problema: Status das OSs incorretos
**Solução**: Os status corretos são: `quote`, `approved`, `progress`, `done` (conforme `Order.statusMap`)

### Problema: Dados não localizados
**Solução**: Verificar se o idioma do simulador foi alterado corretamente antes do teste

### Problema: Login falha
**Solução**: Verificar se a conta demo existe no Firebase Auth com a senha `Demo@2024!`
