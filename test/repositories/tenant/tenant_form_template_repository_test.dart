import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/form_template_store.dart';
import 'package:praticos/repositories/tenant/tenant_form_template_repository.dart';

void main() {
  test('a template without isActive counts as active', () {
    // 5 templates, 1 marked inactive, 1 without the field: 4 active.
    expect(activeFormTemplateCount(all: 5, inactive: 1), 4);
    expect(activeFormTemplateCount(all: 0, inactive: 0), 0);
    expect(activeFormTemplateCount(all: 1, inactive: 2), 0);
  });

  test('checklist templates live in the company "forms" subcollection', () {
    expect(TenantFormTemplateRepository.collectionName, 'forms');
  });

  test('the active checklists counter reads the same subcollection', () {
    // The counter used to count `formTemplates`, which holds nothing, so the
    // plan always showed 0 active checklists.
    final source = File('lib/mobx/form_template_store.dart').readAsStringSync();
    expect(source, isNot(contains("collection('formTemplates')")));
    // Active is isActive != false (server trigger), never == true.
    expect(source, isNot(contains("where('isActive', isEqualTo: true)")));
    expect(
      source,
      contains('.collection(TenantFormTemplateRepository.collectionName)'),
    );
  });
}
