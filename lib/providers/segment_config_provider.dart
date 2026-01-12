import 'package:flutter/cupertino.dart';
import '../models/custom_field.dart';
import '../services/segment_config_service.dart';

/// Provider que gerencia labels dinâmicos e campos customizados
/// baseado no segmento da empresa
class SegmentConfigProvider extends ChangeNotifier {
  /// Singleton instance for global access (used by LocaleStore)
  static SegmentConfigProvider? _instance;
  static SegmentConfigProvider get instance {
    _instance ??= SegmentConfigProvider();
    return _instance!;
  }

  final _service = SegmentConfigService();

  SegmentConfigProvider() {
    _instance = this;
  }

  bool _isLoading = false;
  String? _error;

  /// Indica se está carregando
  bool get isLoading => _isLoading;

  /// Indica se já foi carregado
  bool get isLoaded => _service.isLoaded;

  /// Erro ocorrido durante o carregamento
  String? get error => _error;

  /// ID do segmento atual
  String? get segmentId => _service.currentSegmentId;

  /// Idioma atual
  String get locale => _service.currentLocale;

  /// Define se o device deve ser exibido na listagem de OS
  /// Por enquanto, true para todos os segmentos
  bool get showDeviceInOrderList {
    // Configurar por segmento quando necessário
    // Segmentos onde device é importante: automotive, hvac, smartphones, computers, appliances, printers
    // Segmentos onde device é menos relevante: electrical, plumbing, security, solar, other
    return true;
  }

  /// Obtém o ícone do dispositivo baseado no segmento
  IconData get deviceIcon {
    switch (segmentId) {
      case 'automotive':
        return CupertinoIcons.car_detailed;
      case 'computers':
        return CupertinoIcons.device_laptop;
      case 'smartphones':
        return CupertinoIcons.device_phone_portrait;
      case 'hvac':
        return CupertinoIcons.snow;
      case 'appliances':
        return CupertinoIcons.bolt_horizontal_circle; // Eletrodomésticos
      case 'electrical':
        return CupertinoIcons.bolt;
      case 'plumbing':
        return CupertinoIcons.drop;
      case 'security':
        return CupertinoIcons.video_camera_solid;
      case 'solar':
        return CupertinoIcons.sun_max;
      case 'printers':
        return CupertinoIcons.printer;
      default:
        return CupertinoIcons.tag; // Genérico
    }
  }

  /// Inicializa com um segmento específico
  ///
  /// NOTE: Não controla locale aqui - isso é feito automaticamente pelo
  /// MaterialApp builder via injectL10n() quando AppLocalizations muda
  Future<void> initialize(String segmentId) async {
    if (_service.currentSegmentId == segmentId && _service.isLoaded) {
      return; // Já carregado
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Apenas carrega o segmento, não força locale
      // O locale será configurado automaticamente por injectL10n()
      await _service.load(segmentId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Injeta ou atualiza o AppLocalizations para usar traduções dos ARB files
  /// Chamado no MaterialApp builder, então é executado a cada rebuild
  /// Detecta mudanças de locale e recarrega cache automaticamente
  void injectL10n(dynamic l10n) {
    if (l10n != null) {
      final currentL10nInstance = _service.currentL10n;
      final isDifferent = currentL10nInstance != l10n;

      if (isDifferent) {
        // Locale mudou, recarrega cache com nova AppLocalizations
        _service.updateL10n(l10n);
      } else {
        // Primeira injeção ou mesma locale, apenas armazena
        _service.setL10n(l10n);
      }
    }
  }

  // NOTE: setLocale() removido - locale é controlado automaticamente
  // via injectL10n() quando MaterialApp rebuilds com novo AppLocalizations

  // ════════════════════════════════════════════════════════════
  // LABELS
  // ════════════════════════════════════════════════════════════

  /// Obtém um label genérico
  String label(String key) => _service.label(key);

  /// Atalhos para entidades comuns
  String get device => _service.device;
  String get devicePlural => _service.devicePlural;
  String get customer => _service.customer;
  String get customerPlural => _service.customerPlural;
  String get serviceOrder => _service.serviceOrder;
  String get serviceOrderPlural => _service.serviceOrderPlural;

  /// Obtém label de status customizado
  ///
  /// Mapeia chaves técnicas para labels customizados:
  /// - 'quote' → 'Orçamento'
  /// - 'approved' → 'Aprovado'
  /// - 'progress' → 'Em Andamento' / 'Em Conserto' / 'Em Manutenção'
  /// - 'done' → 'Concluído' / 'Pronto para Retirada'
  /// - 'canceled' → 'Cancelado'
  String getStatus(String? statusKey) => _service.getStatus(statusKey);

  // ════════════════════════════════════════════════════════════
  // CUSTOM FIELDS
  // ════════════════════════════════════════════════════════════

  /// Obtém campos customizados para um namespace (ex: "device")
  List<CustomField> fieldsFor(String namespace) =>
      _service.fieldsFor(namespace);

  /// Obtém campos customizados agrupados por section
  Map<String, List<CustomField>> fieldsGroupedBySection(String namespace) =>
      _service.fieldsGroupedBySection(namespace);

  // ════════════════════════════════════════════════════════════
  // UTILS
  // ════════════════════════════════════════════════════════════

  /// Limpa todo o estado
  void clear() {
    _service.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.clear();
    super.dispose();
  }
}
