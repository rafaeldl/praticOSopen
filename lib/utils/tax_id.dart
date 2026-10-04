// CPF/CNPJ helpers. `Customer.taxId` is stored normalized: digits and, for
// the alphanumeric CNPJ (Receita Federal, since July 2026), uppercase letters.

/// Uppercases and keeps only `[0-9A-Z]` (drops `.`, `-`, `/`, spaces, etc.).
String normalizeTaxId(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

final RegExp _digitsOnly = RegExp(r'^[0-9]+$');
final RegExp _cnpjBody = RegExp(r'^[0-9A-Z]{12}[0-9]{2}$');

bool _allSameChar(String value) => value.split('').toSet().length == 1;

/// Brazilian CPF (11 digits, two mod-11 check digits). Numeric only.
bool isValidCpf(String value) {
  final digits = normalizeTaxId(value);
  if (digits.length != 11 ||
      !_digitsOnly.hasMatch(digits) ||
      _allSameChar(digits)) {
    return false;
  }
  final numbers = digits.codeUnits.map((c) => c - 48).toList();
  for (var position = 9; position <= 10; position++) {
    var sum = 0;
    for (var i = 0; i < position; i++) {
      sum += numbers[i] * (position + 1 - i);
    }
    final check = (sum * 10) % 11 % 10;
    if (check != numbers[position]) return false;
  }
  return true;
}

/// Brazilian CNPJ, numeric or alphanumeric: 12 `[0-9A-Z]` characters plus two
/// numeric check digits. Character value is `codeUnit - 48` (A=17 ... Z=42).
bool isValidCnpj(String value) {
  final id = normalizeTaxId(value);
  if (!_cnpjBody.hasMatch(id) || _allSameChar(id)) return false;
  final values = id.codeUnits.map((c) => c - 48).toList();
  const firstWeights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const secondWeights = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  int checkDigit(List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += values[i] * weights[i];
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  return checkDigit(firstWeights) == values[12] &&
      checkDigit(secondWeights) == values[13];
}

/// CPF when 11 characters, CNPJ when 14; anything else is invalid.
bool isValidTaxId(String value) {
  final id = normalizeTaxId(value);
  if (id.length == 11) return isValidCpf(id);
  if (id.length == 14) return isValidCnpj(id);
  return false;
}

/// 000.000.000-00 (CPF) or XX.XXX.XXX/XXXX-XX (CNPJ); other sizes return the
/// normalized value.
String formatTaxId(String value) {
  final d = normalizeTaxId(value);
  if (d.length == 11) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }
  if (d.length == 14) {
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
  }
  return d;
}
