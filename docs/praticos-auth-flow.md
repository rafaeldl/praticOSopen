# Documentação: Vínculo de Token e SessionID (PraticOS)

Este documento detalha o contrato de autenticação entre o Clawdbot e o Firebase.

## 1. Fluxo de Autenticação

1. **Identificação (WhatsApp):** O bot recebe uma mensagem e captura o `authorId` (ex: `+5548984090709`).
2. **Handshake de Sessão:** A Skill faz uma chamada ao backend passando o `authorId` e o `sessionId` atual.
3. **Vínculo no Firebase:**
   - O backend verifica se o `authorId` está cadastrado.
   - Se sim, o backend armazena o `sessionId` no documento do usuário (ou em uma coleção de sessões ativas).
   - O `sessionId` passa a valer como um "Bearer Token" temporário para as chamadas daquela conversa.

## 2. Contrato da API (Exemplo)

### `POST /auth/bindSession`
- **Payload:**
  ```json
  {
    "authorId": "+5548984090709",
    "sessionId": "e125d3b3-7229-4ad7-9ee4-09ace3e3016a"
  }
  ```
- **Resposta:**
  ```json
  {
    "status": "success",
    "linked": true,
    "userContext": {
      "name": "Rafael",
      "tenantId": "oficina-xyz",
      "labels": { "objeto": "Placa" }
    }
  }
  ```

## 3. Estrutura no Firestore (Coleção `users`)

Para manter o vínculo persistente, o documento do usuário no Firestore deve ser atualizado para incluir um objeto `clawdbot`. Isso permite que o backend saiba instantaneamente quem é o dono daquela sessão.

**Path:** `/users/{uid}`

```json
{
  "name": "Rafael Laurindo",
  "whatsapp": "+5548984090709",
  "clawdbot": {
    "authorId": "+5548984090709",
    "lastSessionId": "e125d3b3-7229-4ad7-9ee4-09ace3e3016a",
    "linkedAt": "2026-01-28T15:20:00Z",
    "status": "active"
  }
}
```

## 4. Segurança
O `sessionId` é gerado pelo Clawdbot e é único por conversa/usuário. O backend só deve aceitar requisições onde o `sessionId` enviado no header coincida com o `lastSessionId` guardado no Firestore para aquele `authorId`. Isso evita que alguém tente "chutar" IDs de sessão para acessar dados de terceiros.
