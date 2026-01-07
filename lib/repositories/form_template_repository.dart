import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/repository.dart';

class FormTemplateRepository extends Repository<FormDefinition> {
  static String collectionName = 'form_templates';

  FormTemplateRepository() : super(collectionName);

  @override
  FormDefinition fromJson(data) => FormDefinition.fromJson(data);

  @override
  Map<String, dynamic> toJson(FormDefinition template) => template.toJson();
}
