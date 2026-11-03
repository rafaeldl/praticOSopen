import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/repositories/tenant/tenant_form_template_repository.dart';

void main() {
  test('checklist templates live in the company "forms" subcollection', () {
    expect(TenantFormTemplateRepository.collectionName, 'forms');
  });

  test('the active checklists counter reads the same subcollection', () {
    // The counter used to count `formTemplates`, which holds nothing, so the
    // plan always showed 0 active checklists.
    final source = File('lib/mobx/form_template_store.dart').readAsStringSync();
    expect(source, isNot(contains("collection('formTemplates')")));
    expect(
      source,
      contains('.collection(TenantFormTemplateRepository.collectionName)'),
    );
  });
}
