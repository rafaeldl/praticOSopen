import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/services/fiscal_lookup_service.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('FiscalLookupService', () {
    test('CNPJ: legal name, address with the IBGE code and e-mail', () async {
      Uri? asked;
      final service = FiscalLookupService(
        client: MockClient((request) async {
          asked = request.url;
          return _json({
            'razao_social': 'REVENDA EXEMPLO LTDA',
            'descricao_tipo_de_logradouro': 'RUA',
            'logradouro': 'DAS FLORES',
            'numero': '100',
            'complemento': 'SALA 2',
            'bairro': 'CENTRO',
            'cep': '80010-000',
            'municipio': 'CURITIBA',
            'codigo_municipio_ibge': 4106902,
            'uf': 'pr',
            'email': 'FISCAL@REVENDA.COM.BR',
          });
        }),
      );
      final info = await service.lookupCnpj('11222333000181');
      expect(asked.toString(), contains('/cnpj/v1/11222333000181'));
      expect(info!.legalName, 'REVENDA EXEMPLO LTDA');
      expect(info.email, 'fiscal@revenda.com.br');
      final a = info.address;
      expect(a.street, 'Rua Das Flores');
      expect(a.number, '100');
      expect(a.complement, 'Sala 2');
      expect(a.district, 'Centro');
      expect(a.postalCode, '80010000');
      expect(a.cityName, 'Curitiba');
      expect(a.cityCode, '4106902');
      expect(a.state, 'PR');
    });

    test('CNPJ not found, service down or alphanumeric: null', () async {
      var calls = 0;
      final notFound = FiscalLookupService(
        client: MockClient((_) async {
          calls++;
          return _json({'message': 'not found'}, 404);
        }),
      );
      expect(await notFound.lookupCnpj('11222333000181'), isNull);
      expect(await notFound.lookupCnpj('12ABC34501DE35'), isNull);
      expect(calls, 1);

      final down = FiscalLookupService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(await down.lookupCnpj('11222333000181'), isNull);
    });

    test('CEP: street, district, city with IBGE code and UF', () async {
      final service = FiscalLookupService(
        client: MockClient(
          (request) async => _json({
            'cep': '01310-100',
            'logradouro': 'Avenida Paulista',
            'bairro': 'Bela Vista',
            'localidade': 'São Paulo',
            'uf': 'SP',
            'ibge': '3550308',
          }),
        ),
      );
      final a = await service.lookupPostalCode('01310100');
      expect(a!.postalCode, '01310100');
      expect(a.street, 'Avenida Paulista');
      expect(a.district, 'Bela Vista');
      expect(a.cityName, 'São Paulo');
      expect(a.cityCode, '3550308');
      expect(a.state, 'SP');
    });

    test('CEP that does not exist: null', () async {
      final service = FiscalLookupService(
        client: MockClient((_) async => _json({'erro': 'true'})),
      );
      expect(await service.lookupPostalCode('99999999'), isNull);
      expect(await service.lookupPostalCode('123'), isNull);
    });
  });
}
