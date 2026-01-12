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
      if (section != null) 'section': section,
      if (order != null) 'order': order,
    };
  }

  /// Obtém label no idioma especificado com fallback inteligente
  ///
  /// Tenta encontrar na seguinte ordem:
  /// 1. Locale exata (pt-BR, en-US, es-ES, etc)
  /// 2. Fallback por código de idioma (pt_* → pt-BR, en_* → en-US, es_* → es-ES)
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
