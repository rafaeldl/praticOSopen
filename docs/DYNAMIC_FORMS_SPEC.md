# Especificação Técnica: Formulários Dinâmicos e Checklists (MVP)

## 1. Visão Geral
Esta funcionalidade permite que empresas (ou o sistema via segmentos) criem templates de formulários que podem ser anexados manualmente a Ordens de Serviço (OS). Ideal para checklists de entrada, laudos e vistorias, com forte suporte a evidências fotográficas.

## 2. Design e UX (Apple HIG)
Seguindo as diretrizes em `docs/UX_GUIDELINES.md`:
- **Interface:** Uso estrito de widgets `Cupertino`.
- **Formulários:** Organizados em `CupertinoListSection.insetGrouped`.
- **Cores:** Uso de `CupertinoColors` dinâmicos (`label`, `systemGroupedBackground`) para suporte total ao Dark Mode.
- **Navegação:** Títulos grandes (`largeTitle`) e feedbacks táteis nativos.
- **Fotos:** Galeria horizontal ou grid simples dentro do item do formulário para exibir múltiplas capturas.

## 3. Modelagem de Dados

### 3.1 FormDefinition (Template)
Existem dois níveis de templates:
1. **Templates Globais:** Coleção `segments/{segmentId}/forms` (definidos pelo sistema para o segmento).
2. **Templates da Empresa:** Coleção `companies/{companyId}/forms` (criados pela própria empresa).

```typescript
{
  id: string;
  title: string;                 // Ex: "Vistoria de Entrada"
  description: string;
  isActive: boolean;
  items: FormItemDefinition[];
  createdAt: timestamp;
  updatedAt: timestamp;
}
```

### 3.2 FormItemDefinition
```typescript
{
  id: string;
  label: string;                 // Pergunta/Item
  type: 'text' | 'number' | 'select' | 'checklist' | 'photo_only' | 'boolean';
  options: string[];             // Para 'select' ou 'checklist'
  required: boolean;
  allowPhotos: boolean;          // Habilita captura de imagens por item
}
```

### 3.3 OrderForm (Instância na OS)
Coleção: `orders/{orderId}/forms/{formInstanceId}`

```typescript
{
  id: string;
  formDefinitionId: string;
  title: string;
  status: 'pending' | 'in_progress' | 'completed';
  responses: {
    itemId: string;
    value: any;
    photoUrls: string[];         // Suporte a múltiplas fotos por item
  }[];
  updatedAt: timestamp;
}
```

## 4. Funcionamento (MVP)

### 4.1 Vinculação Manual
- Dentro da OS, o usuário clica em "Adicionar Formulário".
- O sistema lista os templates disponíveis para a empresa e segmento.
- Ao selecionar, uma nova instância é criada na subcollection da OS.

### 4.2 Preenchimento e Múltiplas Fotos
- Cada item exibe seu campo de resposta e um botão de câmera.
- Ao tirar fotos, elas são enviadas ao Storage e as URLs são adicionadas ao array `photoUrls` do item correspondente.
- As fotos também podem ser replicadas na galeria principal da OS para visibilidade geral, se desejado.

## 5. Arquitetura e Performance
- **Subcollections:** O uso de `orders/{id}/forms` mantém o documento principal da OS leve (abaixo de 1MB), mesmo com centenas de URLs de fotos.
- **Offline:** O preenchimento deve funcionar offline via cache do Firestore, sincronizando as fotos conforme a conexão permitir.