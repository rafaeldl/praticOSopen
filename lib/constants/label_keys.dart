/// Constantes de keys para labels type-safe
///
/// Use essas constantes em vez de strings mágicas para evitar erros de digitação.
///
/// Exemplo:
/// ```dart
/// final config = context.read<SegmentConfigProvider>();
/// Text(config.label(LabelKeys.deviceBrand)) // "Montadora" ou "Marca"
/// ```
class LabelKeys {
  LabelKeys._(); // Private constructor para não instanciar

  // ════════════════════════════════════════════════════════════
  // ENTIDADES
  // ════════════════════════════════════════════════════════════

  /// Label da entidade "device" (singular)
  /// Exemplos: "Veículo", "Equipamento", "Aparelho"
  static const deviceEntity = 'device._entity';

  /// Label da entidade "device" (plural)
  /// Exemplos: "Veículos", "Equipamentos", "Aparelhos"
  static const deviceEntityPlural = 'device._entity_plural';

  /// Label da entidade "customer" (singular)
  /// Exemplos: "Cliente", "Proprietário"
  static const customerEntity = 'customer._entity';

  /// Label da entidade "customer" (plural)
  /// Exemplos: "Clientes", "Proprietários"
  static const customerEntityPlural = 'customer._entity_plural';

  /// Label da entidade "service_order" (singular)
  /// Exemplos: "Ordem de Serviço", "OS"
  static const serviceOrderEntity = 'service_order._entity';

  /// Label da entidade "service_order" (plural)
  /// Exemplos: "Ordens de Serviço", "OSs"
  static const serviceOrderEntityPlural = 'service_order._entity_plural';

  // ════════════════════════════════════════════════════════════
  // CAMPOS DE DEVICE
  // ════════════════════════════════════════════════════════════

  /// Label do campo "brand"
  /// Exemplos: "Marca", "Montadora", "Fabricante"
  static const deviceBrand = 'device.brand';

  /// Label do campo "model"
  /// Exemplo: "Modelo"
  static const deviceModel = 'device.model';

  /// Label do campo "serialNumber"
  /// Exemplos: "Número de Série", "Placa", "IMEI"
  static const deviceSerialNumber = 'device.serialNumber';

  /// Label do campo "description"
  /// Exemplo: "Descrição"
  static const deviceDescription = 'device.description';

  /// Label do campo "notes"
  /// Exemplos: "Observações", "Notas"
  static const deviceNotes = 'device.notes';

  // ════════════════════════════════════════════════════════════
  // CAMPOS DE CUSTOMER
  // ════════════════════════════════════════════════════════════

  /// Label do campo "name"
  /// Exemplo: "Nome"
  static const customerName = 'customer.name';

  /// Label do campo "phone"
  /// Exemplo: "Telefone"
  static const customerPhone = 'customer.phone';

  /// Label do campo "email"
  /// Exemplo: "E-mail"
  static const customerEmail = 'customer.email';

  /// Label do campo "address"
  /// Exemplo: "Endereço"
  static const customerAddress = 'customer.address';

  // ════════════════════════════════════════════════════════════
  // AÇÕES
  // ════════════════════════════════════════════════════════════

  /// Label de ação "criar device"
  /// Exemplos: "Adicionar Veículo", "Adicionar Equipamento"
  static const createDevice = 'actions.create_device';

  /// Label de ação "editar device"
  /// Exemplos: "Editar Veículo", "Editar Equipamento"
  static const editDevice = 'actions.edit_device';

  /// Label de ação "excluir device"
  /// Exemplos: "Excluir Veículo", "Excluir Equipamento"
  static const deleteDevice = 'actions.delete_device';

  /// Label de ação "criar customer"
  /// Exemplo: "Adicionar Cliente"
  static const createCustomer = 'actions.create_customer';

  /// Label de ação "editar customer"
  /// Exemplo: "Editar Cliente"
  static const editCustomer = 'actions.edit_customer';

  /// Label de ação "criar service order"
  /// Exemplo: "Nova OS"
  static const createServiceOrder = 'actions.create_service_order';

  /// Label de ação "editar service order"
  /// Exemplo: "Editar OS"
  static const editServiceOrder = 'actions.edit_service_order';

  /// Label de ação "criar service"
  /// Exemplo: "Novo Serviço"
  static const createService = 'actions.create_service';

  /// Label de ação "editar service"
  /// Exemplo: "Editar Serviço"
  static const editService = 'actions.edit_service';

  /// Label de ação "criar product"
  /// Exemplo: "Novo Produto"
  static const createProduct = 'actions.create_product';

  /// Label de ação "editar product"
  /// Exemplo: "Editar Produto"
  static const editProduct = 'actions.edit_product';

  /// Label de ação "remover"
  /// Exemplo: "Remover"
  static const remove = 'actions.remove';

  /// Label de ação "confirmar exclusão"
  /// Exemplo: "Confirmar exclusão"
  static const confirmDeletion = 'actions.confirm_deletion';

  /// Label de ação "tentar novamente"
  /// Exemplo: "Tentar novamente"
  static const retryAgain = 'actions.retry_again';

  // ════════════════════════════════════════════════════════════
  // STATUS
  // ════════════════════════════════════════════════════════════

  /// Status "pendente"
  /// Exemplos: "Pendente", "Aguardando Peças"
  static const statusPending = 'status.pending';

  /// Status "em andamento"
  /// Exemplos: "Em Andamento", "Em Conserto", "Em Manutenção"
  static const statusInProgress = 'status.in_progress';

  /// Status "concluído"
  /// Exemplos: "Concluído", "Pronto para Retirada"
  static const statusCompleted = 'status.completed';

  /// Status "cancelado"
  /// Exemplo: "Cancelado"
  static const statusCancelled = 'status.cancelled';

  // ════════════════════════════════════════════════════════════
  // MESSAGES (Mensagens do sistema)
  // ════════════════════════════════════════════════════════════

  /// Mensagem "Nenhum resultado encontrado"
  static const noResultsFound = 'messages.no_results_found';

  /// Mensagem "Obrigatório" (validação de campo)
  static const required = 'messages.required';

  // ════════════════════════════════════════════════════════════
  // PHOTOS (Fotos e imagens)
  // ════════════════════════════════════════════════════════════

  /// Label "Alterar Foto"
  static const changePhoto = 'photos.change';

  /// Label "Adicionar Foto"
  static const addPhoto = 'photos.add';

  /// Label "Excluir Foto"
  static const deletePhoto = 'photos.delete';

  /// Label "Definir como Capa"
  static const setAsCover = 'photos.set_as_cover';

  // ════════════════════════════════════════════════════════════
  // PRODUCTS (Produtos e Serviços)
  // ════════════════════════════════════════════════════════════

  /// Label "Quantidade"
  static const quantity = 'product.quantity';

  /// Label "Valor unitário"
  static const unitValue = 'product.unit_value';

  /// Label "Total"
  static const total = 'product.total';

  // ════════════════════════════════════════════════════════════
  // COMUM
  // ════════════════════════════════════════════════════════════

  /// Label de ação "salvar"
  /// Exemplo: "Salvar"
  static const save = 'common.save';

  /// Label de ação "cancelar"
  /// Exemplo: "Cancelar"
  static const cancel = 'common.cancel';

  /// Label de ação "confirmar"
  /// Exemplo: "Confirmar"
  static const confirm = 'common.confirm';

  /// Label de ação "excluir"
  /// Exemplo: "Excluir"
  static const delete = 'common.delete';

  /// Label de ação "editar"
  /// Exemplo: "Editar"
  static const edit = 'common.edit';

  /// Label de ação "buscar"
  /// Exemplo: "Buscar"
  static const search = 'common.search';

  /// Label de ação "filtrar"
  /// Exemplo: "Filtrar"
  static const filter = 'common.filter';

  /// Label de ação "ordenar"
  /// Exemplo: "Ordenar"
  static const sort = 'common.sort';

  /// Label de ação "exportar"
  /// Exemplo: "Exportar"
  static const export = 'common.export';

  /// Label de ação "importar"
  /// Exemplo: "Importar"
  static const import = 'common.import';

  /// Label de ação "imprimir"
  /// Exemplo: "Imprimir"
  static const print = 'common.print';

  /// Label "Observações" ou "Notas"
  static const notes = 'common.notes';
}
