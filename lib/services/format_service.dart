import 'package:intl/intl.dart';

/// Serviço centralizado para formatação de datas, números e moedas
/// de acordo com o locale atual do aplicativo
class FormatService {
  static final FormatService _instance = FormatService._internal();
  factory FormatService() => _instance;
  FormatService._internal();

  String _locale = 'pt-BR';

  /// Define o locale atual
  void setLocale(String locale) {
    _locale = _normalizeLocale(locale);
  }

  /// Normaliza locale para formato completo (en → en-US, pt → pt-BR, es → es-ES)
  String _normalizeLocale(String locale) {
    // Se já está no formato completo, retorna
    if (locale.contains('-') || locale.contains('_')) {
      return locale.replaceAll('_', '-');
    }

    // Fallback inteligente por código de idioma
    switch (locale) {
      case 'pt':
        return 'pt-BR';
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      default:
        return locale;
    }
  }

  /// Obtém locale no formato usado pelo intl (pt_BR, en_US, es_ES)
  String get _intlLocale => _locale.replaceAll('-', '_');

  // ══════════════════════════════════════════════════════════
  // DATAS
  // ══════════════════════════════════════════════════════════

  /// Formata data no formato curto (ex: 09/01/2025, 01/09/2025, 09/01/2025)
  String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat.yMd(_intlLocale).format(date);
  }

  /// Formata data com hora (ex: 09/01/2025 14:30, 01/09/2025 2:30 PM)
  String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat.yMd(_intlLocale).add_Hm().format(date);
  }

  /// Formata data no formato longo (ex: 9 de janeiro de 2025)
  String formatDateLong(DateTime? date) {
    if (date == null) return '';
    return DateFormat.yMMMMd(_intlLocale).format(date);
  }

  /// Formata apenas dia e mês (ex: 09/01, 01/09)
  String formatDayMonth(DateTime? date) {
    if (date == null) return '';
    return DateFormat.Md(_intlLocale).format(date);
  }

  /// Formata apenas hora (ex: 14:30, 2:30 PM)
  String formatTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat.Hm(_intlLocale).format(date);
  }

  // ══════════════════════════════════════════════════════════
  // NÚMEROS E MOEDA
  // ══════════════════════════════════════════════════════════

  /// Formata valor monetário com moeda do país (ex: R$ 1.234,56, $1,234.56, € 1.234,56)
  ///
  /// A biblioteca intl detecta automaticamente:
  /// - Símbolo da moeda (R$, $, €, etc)
  /// - Separadores decimais e de milhares
  /// - Posição do símbolo
  /// - Tudo baseado na locale atual
  String formatCurrency(num? value, {int decimalDigits = 2}) {
    if (value == null) return formatCurrency(0, decimalDigits: decimalDigits);

    return NumberFormat.simpleCurrency(
      locale: _intlLocale,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  /// Formata número decimal simples (ex: 1.234,56, 1,234.56)
  ///
  /// A biblioteca intl detecta automaticamente os separadores corretos
  String formatDecimal(num? value, {int decimalDigits = 2}) {
    if (value == null) return '0';
    return NumberFormat.decimalPattern(_intlLocale).format(value);
  }

  /// Formata porcentagem (ex: 15%, 15.5%)
  String formatPercent(num? value, {int decimalDigits = 0}) {
    if (value == null) return '0%';
    final formatter = NumberFormat.decimalPattern(_intlLocale);
    return '${formatter.format(value)}%';
  }

  /// Retorna NumberFormat para moeda (útil para TextInputFormatters)
  NumberFormat get currencyFormat {
    return NumberFormat.simpleCurrency(locale: _intlLocale);
  }

  /// Retorna NumberFormat simplificado (para inputs)
  NumberFormat get simpleCurrencyFormat {
    return NumberFormat.simpleCurrency(locale: _intlLocale);
  }
}
