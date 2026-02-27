/// Representa um campo customizado ou label override de um segmento
class CustomField {
  final String key;
  final String type;
  final Map<String, String> labels;

  // Validações (apenas para campos reais, não type: "label")
  final bool required;
  final num? min;
  final num? max;
  final int? maxLength;
  final int? minLength;
  final String? pattern;
  final String? suffix;
  final String? prefix;
  final String? placeholder;

  // Para select/radio
  final List<String>? options;
  final List<Map<String, dynamic>>? optionsI18n; // Tradução das opções

  // Organização - i18n
  final Map<String, String>? sectionI18n; // Tradução do nome da seção

  // Configurações de input mask
  final List<String>? masks; // Máscaras universais (não variam por país)
  final Map<String, List<String>>? masksByCountry; // Máscaras por país (BR, US, PT, etc)
  final String? keyboardType; // 'phone', 'text', 'number', 'email', 'decimal'
  final String? textCapitalization; // 'characters', 'words', 'sentences', 'none'

  // Organização
  final String? section;
  final int? order;

  const CustomField({
    required this.key,
    required this.type,
    required this.labels,
    this.required = false,
    this.min,
    this.max,
    this.maxLength,
    this.minLength,
    this.pattern,
    this.suffix,
    this.prefix,
    this.placeholder,
    this.options,
    this.optionsI18n,
    this.sectionI18n,
    this.masks,
    this.masksByCountry,
    this.keyboardType,
    this.textCapitalization,
    this.section,
    this.order,
  });

  /// Cria a partir de JSON do Firestore
  factory CustomField.fromJson(Map<String, dynamic> json) {
    return CustomField(
      key: json['key'] ?? '',
      type: json['type'] ?? 'text',
      labels: Map<String, String>.from(json['labels'] ?? {}),
      required: json['required'] ?? false,
      min: json['min'],
      max: json['max'],
      maxLength: json['maxLength'],
      minLength: json['minLength'],
      pattern: json['pattern'],
      suffix: json['suffix'],
      prefix: json['prefix'],
      placeholder: json['placeholder'],
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
      optionsI18n: json['optionsI18n'] != null
          ? List<Map<String, dynamic>>.from(
              (json['optionsI18n'] as List).map((e) => Map<String, dynamic>.from(e)))
          : null,
      sectionI18n: json['sectionI18n'] != null
          ? Map<String, String>.from(json['sectionI18n'])
          : null,
      masks: json['masks'] != null
          ? List<String>.from(json['masks'])
          : null,
      masksByCountry: json['masksByCountry'] != null
          ? (json['masksByCountry'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, List<String>.from(value)))
          : null,
      keyboardType: json['keyboardType'],
      textCapitalization: json['textCapitalization'],
      section: json['section'],
      order: json['order'],
    );
  }

  /// Converte para JSON do Firestore
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'labels': labels,
      if (required) 'required': required,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (maxLength != null) 'maxLength': maxLength,
      if (minLength != null) 'minLength': minLength,
      if (pattern != null) 'pattern': pattern,
      if (suffix != null) 'suffix': suffix,
      if (prefix != null) 'prefix': prefix,
      if (placeholder != null) 'placeholder': placeholder,
      if (options != null) 'options': options,
      if (optionsI18n != null) 'optionsI18n': optionsI18n,
      if (sectionI18n != null) 'sectionI18n': sectionI18n,
      if (masks != null) 'masks': masks,
      if (masksByCountry != null) 'masksByCountry': masksByCountry,
      if (keyboardType != null) 'keyboardType': keyboardType,
      if (textCapitalization != null) 'textCapitalization': textCapitalization,
      if (section != null) 'section': section,
      if (order != null) 'order': order,
    };
  }

  /// Obtém label no idioma especificado com fallback inteligente
  ///
  /// Tenta encontrar na seguinte ordem:
  /// 1. Locale exata (pt-BR, en-US, es-ES, etc)
  /// 2. Fallback por código de idioma (pt/pt_PT → pt-BR, en/en_GB → en-US, es/es_MX → es-ES)
  /// 3. Fallback final para português brasileiro (pt-BR)
  String getLabel(String locale) {
    // 1. Tenta locale exata
    if (labels.containsKey(locale)) {
      return labels[locale]!;
    }

    // 2. Fallback inteligente por código de idioma
    final languageCode = locale.split('-')[0].split('_')[0];

    String fallbackLocale;
    switch (languageCode) {
      case 'pt':
        fallbackLocale = 'pt-BR';
        break;
      case 'en':
        fallbackLocale = 'en-US';
        break;
      case 'es':
        fallbackLocale = 'es-ES';
        break;
      default:
        fallbackLocale = 'pt-BR'; // Fallback final
    }

    if (fallbackLocale != locale && labels.containsKey(fallbackLocale)) {
      return labels[fallbackLocale]!;
    }

    // 3. Fallback final: português brasileiro
    return labels['pt-BR'] ?? key;
  }

  /// Obtém label traduzida para uma opção de select
  String getOptionLabel(String value, String locale) {
    if (optionsI18n == null) return value;
    try {
      final entry = optionsI18n!.firstWhere((o) => o['value'] == value);
      final labels = Map<String, String>.from(entry['labels'] ?? {});
      return _resolveLocale(labels, locale) ?? value;
    } catch (e) {
      return value;
    }
  }

  /// Obtém nome da seção traduzido
  String getSectionLabel(String locale) {
    if (sectionI18n == null) return section ?? 'Geral';
    return _resolveLocale(sectionI18n!, locale) ?? section ?? 'Geral';
  }

  /// Resolve locale com fallback inteligente
  static String? _resolveLocale(Map<String, String> map, String locale) {
    if (map.containsKey(locale)) return map[locale];
    final languageCode = locale.split('-')[0].split('_')[0];
    final fallback = switch (languageCode) {
      'pt' => 'pt-BR',
      'en' => 'en-US',
      'es' => 'es-ES',
      _ => 'pt-BR',
    };
    if (fallback != locale && map.containsKey(fallback)) return map[fallback];
    return map['pt-BR'];
  }

  /// Verifica se é apenas um label override
  bool get isLabel => type == 'label';

  /// Verifica se é um campo customizado real
  bool get isField => type != 'label';

  /// Extrai o namespace (ex: "device" de "device.brand")
  String get namespace => key.split('.').first;

  /// Extrai o nome do campo (ex: "brand" de "device.brand")
  String get fieldName => key.split('.').last;

  @override
  String toString() {
    return 'CustomField(key: $key, type: $type, labels: $labels)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomField && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}
