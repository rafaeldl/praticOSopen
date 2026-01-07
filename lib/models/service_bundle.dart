import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/product.dart';

part 'service_bundle.g.dart';

/// Bundle de formulário associado a um serviço.
/// Quando o serviço é adicionado à OS, este formulário é incluído automaticamente.
@JsonSerializable(explicitToJson: true)
class ServiceFormBundle {
  /// ID do formulário (FormDefinition)
  String formId;

  /// Título do formulário (para exibição, snapshot do título)
  String formTitle;

  /// Se o preenchimento do formulário é obrigatório
  bool isRequired;

  ServiceFormBundle({
    required this.formId,
    required this.formTitle,
    this.isRequired = false,
  });

  factory ServiceFormBundle.fromJson(Map<String, dynamic> json) =>
      _$ServiceFormBundleFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceFormBundleToJson(this);

  /// Cria um bundle a partir de uma definição de formulário
  factory ServiceFormBundle.fromFormDefinition(
    FormDefinition form, {
    bool isRequired = false,
  }) {
    return ServiceFormBundle(
      formId: form.id!,
      formTitle: form.title,
      isRequired: isRequired,
    );
  }
}

/// Bundle de produto associado a um serviço.
/// Quando o serviço é adicionado à OS, este produto é incluído automaticamente.
@JsonSerializable(explicitToJson: true)
class ServiceProductBundle {
  /// ID do produto
  String productId;

  /// Nome do produto (para exibição, snapshot do nome)
  String productName;

  /// Quantidade padrão a ser adicionada
  int quantity;

  /// Valor unitário (opcional, usa o valor do produto se não informado)
  double? value;

  ServiceProductBundle({
    required this.productId,
    required this.productName,
    this.quantity = 1,
    this.value,
  });

  factory ServiceProductBundle.fromJson(Map<String, dynamic> json) =>
      _$ServiceProductBundleFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceProductBundleToJson(this);

  /// Cria um bundle a partir de um produto
  factory ServiceProductBundle.fromProduct(
    Product product, {
    int quantity = 1,
    double? value,
  }) {
    return ServiceProductBundle(
      productId: product.id!,
      productName: product.name ?? '',
      quantity: quantity,
      value: value ?? product.value,
    );
  }
}
