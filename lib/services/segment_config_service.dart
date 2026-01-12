import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/custom_field.dart';
import '../l10n/app_localizations.dart';

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
  AppLocalizations? _l10n;

  // Cache
  final Map<String, String> _labelCache = {};
  final List<CustomField> _customFields = [];

  // Mapeamento de chaves técnicas de status para label keys
  static const Map<String, String> _statusKeyMapping = {
    'quote': 'status.quote',
    'approved': 'status.approved',
    'progress': 'status.in_progress',
    'done': 'status.completed',
    'canceled': 'status.cancelled',
  };

  /// Injeta o AppLocalizations para usar traduções dos ARB files
  void setL10n(AppLocalizations l10n) {
    _l10n = l10n;
  }

  /// Define o idioma atual e recarrega cache com novas traduções
  void setLocale(String locale) {
    if (_locale == locale) return; // Sem mudança, não precisa fazer nada

    _locale = locale;

    // Recarrega customFields com nova locale
    if (_segmentId != null) {
      _labelCache.clear();
      load(_segmentId!).ignore();
    }
  }

  /// Atualiza AppLocalizations quando o idioma muda
  /// Chamado sempre que a locale muda no app
  void updateL10n(AppLocalizations l10n) {
    _l10n = l10n;

    // Reconstruir cache se segmento está carregado
    if (_segmentId != null) {
      _labelCache.clear();
      load(_segmentId!).ignore();
    }
  }

  /// Carrega a configuração de um segmento do Firestore
  /// Também carrega labels globais e permite override por segmento
  Future<void> load(String segmentId) async {
    if (_segmentId == segmentId) {
      return; // Já carregado
    }

    try {
      // Limpa cache anterior
      _labelCache.clear();
      _customFields.clear();

      // 1. Carrega labels globais (se segmentId != 'global')
      if (segmentId != 'global') {
        try {
          final globalDoc = await _db.collection('segments').doc('global').get();
          if (globalDoc.exists) {
            final globalCustomFields = globalDoc.data()!['customFields'] as List? ?? [];
            for (final json in globalCustomFields) {
              final field = CustomField.fromJson(json as Map<String, dynamic>);
              if (field.isLabel) {
                _labelCache[field.key] = field.getLabel(_normalizeLocale(_locale));
              }
            }
          }
        } catch (e) {
          // Global segment não existe ou erro ao carregar
          // Continua sem errar, labels específicas do segmento serão usadas
          debugPrint('⚠️  Aviso ao carregar global segment: $e');
        }
      }

      // 2. Carrega segmento específico (pode sobrescrever labels globais)
      final doc = await _db.collection('segments').doc(segmentId).get();

      if (!doc.exists) {
        throw Exception('Segmento não encontrado: $segmentId');
      }

      final data = doc.data()!;
      final customFieldsJson = data['customFields'] as List? ?? [];

      // Parse dos customFields
      for (final json in customFieldsJson) {
        final field = CustomField.fromJson(json as Map<String, dynamic>);

        if (field.isLabel) {
          // É um label override - armazena no cache (sobrescreve global se houver)
          _labelCache[field.key] = field.getLabel(_normalizeLocale(_locale));
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

  /// Normaliza locale para buscar no cache (pt-BR → pt_BR)
  String _normalizeLocale(String locale) {
    return locale.replaceAll('-', '_');
  }

  /// Tenta obter label dos ARB files (AppLocalizations)
  String? _getFromArb(String key) {
    if (_l10n == null) return null;

    // Mapeamento de label keys → ARB keys
    switch (key) {
      // Entidades
      case 'customer._entity':
        return _l10n!.customer;
      case 'customer._entity_plural':
        return _l10n!.customers;
      case 'device._entity':
        return _l10n!.device;
      case 'device._entity_plural':
        return _l10n!.devices;
      case 'service_order._entity':
        return _l10n!.order;
      case 'service_order._entity_plural':
        return _l10n!.orders;

      // Campos de customer
      case 'customer.name':
        return _l10n!.name;
      case 'customer.phone':
        return _l10n!.phone;
      case 'customer.email':
        return _l10n!.email;
      case 'customer.address':
        return _l10n!.address;

      // Campos de device
      case 'device.brand':
        return _l10n!.brand;
      case 'device.model':
        return _l10n!.model;
      case 'device.serialNumber':
        return _l10n!.serialNumber;
      case 'device.description':
        return _l10n!.description;
      case 'device.notes':
        return _l10n!.notes;

      // Actions
      case 'actions.create_device':
        return _l10n!.addDevice;
      case 'actions.edit_device':
        return '${_l10n!.edit} ${_l10n!.device}';
      case 'actions.delete_device':
        return '${_l10n!.delete} ${_l10n!.device}';
      case 'actions.create_customer':
        return _l10n!.addCustomer;
      case 'actions.edit_customer':
        return '${_l10n!.edit} ${_l10n!.customer}';
      case 'actions.create_service_order':
        return _l10n!.addOrder;
      case 'actions.edit_service_order':
        return '${_l10n!.edit} ${_l10n!.order}';
      case 'actions.create_service':
        return _l10n!.addService;
      case 'actions.edit_service':
        return '${_l10n!.edit} ${_l10n!.service}';
      case 'actions.create_product':
        return _l10n!.addProduct;
      case 'actions.edit_product':
        return '${_l10n!.edit} ${_l10n!.product}';
      case 'actions.remove':
        return _l10n!.remove;
      case 'actions.confirm_deletion':
        return _l10n!.confirmDelete;
      case 'actions.retry_again':
        return _l10n!.retryAgain;

      // Status
      case 'status.pending':
        return _l10n!.statusPending;
      case 'status.in_progress':
        return _l10n!.statusInProgress;
      case 'status.completed':
        return _l10n!.statusCompleted;
      case 'status.cancelled':
        return _l10n!.statusCancelled;
      case 'status.quote':
        return _l10n!.statusQuote;
      case 'status.approved':
        return _l10n!.statusApproved;

      // Messages
      case 'messages.no_results_found':
        return _l10n!.noResultsFound;
      case 'messages.required':
        return _l10n!.required;

      // Photos
      case 'photos.change':
        return _l10n!.changePhoto;
      case 'photos.add':
        return _l10n!.addPhoto;
      case 'photos.delete':
        return '${_l10n!.delete} ${_l10n!.photo}';
      case 'photos.set_as_cover':
        return _l10n!.setAsCover;

      // Products
      case 'product.quantity':
        return _l10n!.quantity;
      case 'product.unit_value':
        return _l10n!.unitValue;
      case 'product.total':
        return _l10n!.total;

      // Common
      case 'common.save':
        return _l10n!.save;
      case 'common.cancel':
        return _l10n!.cancel;
      case 'common.confirm':
        return _l10n!.confirm;
      case 'common.delete':
        return _l10n!.delete;
      case 'common.edit':
        return _l10n!.edit;
      case 'common.search':
        return _l10n!.search;
      case 'common.filter':
        return _l10n!.filter;
      case 'common.sort':
        return _l10n!.sort;
      case 'common.export':
        return _l10n!.export;
      case 'common.import':
        return _l10n!.import;
      case 'common.print':
        return _l10n!.print;
      case 'common.notes':
        return _l10n!.notes;

      default:
        return null;
    }
  }

  /// Obtém um label (com fallback: segment → ARB → key)
  String label(String key) {
    // 1. Firestore custom (por segmento)
    if (_labelCache.containsKey(key)) {
      return _labelCache[key]!;
    }

    // 2. AppLocalizations (ARB files)
    final arbValue = _getFromArb(key);
    if (arbValue != null) return arbValue;

    // 3. Key herself (fallback final)
    return key;
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
    if (statusKey == null) {
      return _l10n?.statusPending ?? 'Pendente';
    }

    // Primeiro tenta mapear a chave técnica para label key
    final labelKey = _statusKeyMapping[statusKey];
    if (labelKey == null) {
      return statusKey; // Chave desconhecida, retorna ela mesma
    }

    // Usa o método label() que já tem o fluxo: segment → ARB → key
    return label(labelKey);
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
  AppLocalizations? get currentL10n => _l10n;
}
