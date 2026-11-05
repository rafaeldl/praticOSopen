import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:praticos/models/fiscal_address.dart';

/// What the Receita has for a CNPJ: the legal name, the address and the
/// e-mail (when public).
class CnpjInfo {
  const CnpjInfo({required this.legalName, required this.address, this.email});

  final String legalName;
  final FiscalAddress address;
  final String? email;
}

/// Looks up a CNPJ (Receita, through BrasilAPI) and a CEP (ViaCEP) to fill
/// the customer's "Dados para nota". Both are public data; nothing about
/// the customer is sent besides the number. Returns null when not found or
/// when the service fails: the user fills by hand.
class FiscalLookupService {
  FiscalLookupService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  /// [cnpj] with digits only (14). The alphanumeric CNPJ is not in the
  /// public services yet: null.
  Future<CnpjInfo?> lookupCnpj(String cnpj) async {
    if (!RegExp(r'^\d{14}$').hasMatch(cnpj)) return null;
    final json = await _get('https://brasilapi.com.br/api/cnpj/v1/$cnpj');
    if (json == null) return null;
    final legalName = _str(json['razao_social']);
    if (legalName == null) return null;
    final street = [
      _str(json['descricao_tipo_de_logradouro']),
      _str(json['logradouro']),
    ].whereType<String>().join(' ');
    return CnpjInfo(
      legalName: legalName,
      email: _str(json['email'])?.toLowerCase(),
      address: FiscalAddress(
        postalCode: _digits(json['cep']),
        street: _title(street.isEmpty ? null : street),
        number: _str(json['numero']),
        complement: _title(_str(json['complemento'])),
        district: _title(_str(json['bairro'])),
        cityCode: _digits(json['codigo_municipio_ibge']),
        cityName: _title(_str(json['municipio'])),
        state: _str(json['uf'])?.toUpperCase(),
      ),
    );
  }

  /// [postalCode] with digits only (8): street, district, city and UF.
  Future<FiscalAddress?> lookupPostalCode(String postalCode) async {
    if (!RegExp(r'^\d{8}$').hasMatch(postalCode)) return null;
    final json = await _get('https://viacep.com.br/ws/$postalCode/json/');
    if (json == null || json['erro'] != null) return null;
    final city = _str(json['localidade']);
    if (city == null) return null;
    return FiscalAddress(
      postalCode: postalCode,
      street: _str(json['logradouro']),
      district: _str(json['bairro']),
      cityCode: _digits(json['ibge']),
      cityName: city,
      state: _str(json['uf'])?.toUpperCase(),
    );
  }

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final response = await _client.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  static String? _str(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _digits(Object? value) {
    final digits = value?.toString().replaceAll(RegExp(r'\D'), '');
    return digits == null || digits.isEmpty ? null : digits;
  }

  /// The Receita writes the address in capitals ("RUA DAS FLORES"); the
  /// form shows it as people write it ("Rua Das Flores").
  static String? _title(String? value) {
    if (value == null) return null;
    return value
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
