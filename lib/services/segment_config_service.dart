import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/custom_field.dart';

/// Serviço que carrega e gerencia a configuração de um segmento
/// (labels customizados e campos extras)
class SegmentConfigService {
  static final SegmentConfigService _instance =
      SegmentConfigService._internal();
  factory SegmentConfigService() => _instance;
  SegmentConfigService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Estado
  String _locale = 'pt-BR';
  String? _segmentId;

  // Cache
  final Map<String, String> _labelCache = {};
  final List<CustomField> _customFields = [];

  // Labels padrão do sistema (fallback quando não há override)
  static const Map<String, String> _systemDefaults = {
    // Entidades
    'device._entity': 'Dispositivo',
    'device._entity_plural': 'Dispositivos',
    'customer._entity': 'Cliente',
    'customer._entity_plural': 'Clientes',
    'service_order._entity': 'Ordem de Serviço',
    'service_order._entity_plural': 'Ordens de Serviço',

    // Campos padrão de device
    'device.brand': 'Marca',
    'device.model': 'Modelo',
    'device.serialNumber': 'Número de Série',
    'device.description': 'Descrição',
    'device.notes': 'Observações',

    // Campos padrão de customer
    'customer.name': 'Nome',
    'customer.phone': 'Telefone',
    'customer.email': 'E-mail',
    'customer.address': 'Endereço',

    // Ações
    'actions.create_device': 'Adicionar Dispositivo',
    'actions.edit_device': 'Editar Dispositivo',
    'actions.delete_device': 'Excluir Dispositivo',
    'actions.create_customer': 'Adicionar Cliente',
    'actions.edit_customer': 'Editar Cliente',
    'actions.create_service_order': 'Nova OS',
    'actions.edit_service_order': 'Editar OS',
    'actions.create_service': 'Novo Serviço',
    'actions.edit_service': 'Editar Serviço',
    'actions.create_product': 'Novo Produto',
    'actions.edit_product': 'Editar Produto',
    'actions.remove': 'Remover',
    'actions.confirm_deletion': 'Confirmar exclusão',
    'actions.retry_again': 'Tentar novamente',

    // Status
    'status.pending': 'Pendente',
    'status.in_progress': 'Em Andamento',
    'status.completed': 'Concluído',
    'status.cancelled': 'Cancelado',

    // Messages
    'messages.no_results_found': 'Nenhum resultado encontrado',
    'messages.required': 'Obrigatório',

    // Photos
    'photos.change': 'Alterar Foto',
    'photos.add': 'Adicionar Foto',
    'photos.delete': 'Excluir Foto',
    'photos.set_as_cover': 'Definir como Capa',

    // Products
    'product.quantity': 'Quantidade',
    'product.unit_value': 'Valor unitário',
    'product.total': 'Total',

    // Comum
    'common.save': 'Salvar',
    'common.cancel': 'Cancelar',
    'common.confirm': 'Confirmar',
    'common.delete': 'Excluir',
    'common.edit': 'Editar',
    'common.search': 'Buscar',
    'common.filter': 'Filtrar',
    'common.sort': 'Ordenar',
    'common.export': 'Exportar',
    'common.import': 'Importar',
    'common.print': 'Imprimir',
    'common.notes': 'Observações',
  };

  // Mapeamento de chaves técnicas de status para label keys
  static const Map<String, String> _statusKeyMapping = {
    'quote': 'status.quote',
    'approved': 'status.approved',
    'progress': 'status.in_progress',
    'done': 'status.completed',
    'canceled': 'status.cancelled',
  };

  // Labels padrão para status (compatibilidade com Order.statusMap)
  static const Map<String, String> _statusDefaults = {
    'status.quote': 'Orçamento',
    'status.approved': 'Aprovado',
  };

  /// Define o idioma atual
  void setLocale(String locale) {
    _locale = locale;
  }

  /// Carrega a configuração de um segmento do Firestore
  Future<void> load(String segmentId) async {
    if (_segmentId == segmentId) {
      return; // Já carregado
    }

    try {
      final doc = await _db.collection('segments').doc(segmentId).get();

      if (!doc.exists) {
        throw Exception('Segmento não encontrado: $segmentId');
      }

      // Limpa cache anterior
      _labelCache.clear();
      _customFields.clear();

      final data = doc.data()!;
      final customFieldsJson = data['customFields'] as List? ?? [];

      // Parse dos customFields
      for (final json in customFieldsJson) {
        final field = CustomField.fromJson(json as Map<String, dynamic>);

        if (field.isLabel) {
          // É um label override - armazena no cache
          _labelCache[field.key] = field.getLabel(_locale);
        } else {
          // É um campo customizado real
          _customFields.add(field);
        }
      }

      // Ordena campos customizados por order
      _customFields.sort((a, b) {
        final orderA = a.order ?? 999;
        final orderB = b.order ?? 999;
        return orderA.compareTo(orderB);
      });

      _segmentId = segmentId;
    } catch (e) {
      throw Exception('Erro ao carregar configuração do segmento: $e');
    }
  }

  /// Obtém um label (com fallback: segment → system → key)
  String label(String key) {
    return _labelCache[key] ?? _systemDefaults[key] ?? key;
  }

  /// Atalhos para labels comuns de entidades
  String get device => label('device._entity');
  String get devicePlural => label('device._entity_plural');
  String get customer => label('customer._entity');
  String get customerPlural => label('customer._entity_plural');
  String get serviceOrder => label('service_order._entity');
  String get serviceOrderPlural => label('service_order._entity_plural');

  /// Obtém label de status customizado
  ///
  /// Mapeia chaves técnicas para labels (com fallback)
  /// Ex: 'quote' → 'Orçamento' (ou customizado por segmento)
  String getStatus(String? statusKey) {
    if (statusKey == null) return 'Pendente';
    // Primeiro tenta mapear a chave técnica para label key
    final labelKey = _statusKeyMapping[statusKey];
    if (labelKey == null) {
      return statusKey; // Chave desconhecida, retorna ela mesma
    }

    // Busca nos overrides do segmento
    if (_labelCache.containsKey(labelKey)) {
      return _labelCache[labelKey]!;
    }

    // Busca nos status defaults
    if (_statusDefaults.containsKey(labelKey)) {
      return _statusDefaults[labelKey]!;
    }

    // Busca nos system defaults (pending, in_progress, completed, cancelled)
    if (_systemDefaults.containsKey(labelKey)) {
      return _systemDefaults[labelKey]!;
    }

    // Fallback final
    return statusKey;
  }

  /// Obtém todos os campos customizados de um namespace
  List<CustomField> fieldsFor(String namespace) {
    return _customFields.where((f) => f.namespace == namespace).toList();
  }

  /// Obtém campos customizados agrupados por section
  Map<String, List<CustomField>> fieldsGroupedBySection(String namespace) {
    final fields = fieldsFor(namespace);
    final grouped = <String, List<CustomField>>{};

    for (final field in fields) {
      final section = field.section ?? 'Geral';
      grouped.putIfAbsent(section, () => []).add(field);
    }

    return grouped;
  }

  /// Limpa todo o cache
  void clear() {
    _segmentId = null;
    _labelCache.clear();
    _customFields.clear();
  }

  /// Getters de estado
  bool get isLoaded => _segmentId != null;
  String? get currentSegmentId => _segmentId;
  String get currentLocale => _locale;
}
