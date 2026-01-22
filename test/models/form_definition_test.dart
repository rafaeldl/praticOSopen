import 'package:praticos/models/form_definition.dart';
import 'package:test/test.dart';

void main() {
  group('FormDefinition', () {
    test('Create with required fields', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Test Form',
      );

      expect(form.id, equals('form123'));
      expect(form.title, equals('Test Form'));
      expect(form.isActive, isTrue);
      expect(form.items, isEmpty);
    });

    test('Create with all fields', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Complete Form',
        description: 'A complete form for testing',
        isActive: false,
        items: [
          FormItemDefinition(
            id: 'item1',
            label: 'Text Field',
            type: FormItemType.text,
          ),
        ],
        titleI18n: {'en': 'Complete Form', 'pt': 'Formulário Completo'},
        descriptionI18n: {'en': 'A complete form', 'pt': 'Um formulário completo'},
      );

      expect(form.id, equals('form123'));
      expect(form.title, equals('Complete Form'));
      expect(form.description, equals('A complete form for testing'));
      expect(form.isActive, isFalse);
      expect(form.items.length, equals(1));
      expect(form.titleI18n, isNotNull);
      expect(form.descriptionI18n, isNotNull);
    });

    test('Create from json', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Test Form',
        description: 'Test Description',
        isActive: true,
        items: [
          FormItemDefinition(
            id: 'item1',
            label: 'Question 1',
            type: FormItemType.text,
            required: true,
          ),
        ],
      );

      FormDefinition newForm = FormDefinition.fromJson(form.toJson());

      expect(newForm.id, equals(form.id));
      expect(newForm.title, equals(form.title));
      expect(newForm.description, equals(form.description));
      expect(newForm.isActive, equals(form.isActive));
      expect(newForm.items.length, equals(form.items.length));
    });

    test('JSON round-trip preserves data', () {
      FormDefinition form = FormDefinition(
        id: 'form456',
        title: 'Round Trip Form',
        description: 'Testing round trip',
        isActive: true,
        items: [
          FormItemDefinition(
            id: 'item1',
            label: 'Text Question',
            type: FormItemType.text,
            required: true,
            allowPhotos: false,
          ),
          FormItemDefinition(
            id: 'item2',
            label: 'Select Question',
            type: FormItemType.select,
            options: ['Option A', 'Option B', 'Option C'],
            required: false,
            allowPhotos: true,
          ),
        ],
      );

      Map<String, dynamic> json = form.toJson();
      FormDefinition restored = FormDefinition.fromJson(json);

      expect(restored.toJson(), equals(form.toJson()));
    });

    test('getLocalizedTitle returns correct translation', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Default Title',
        titleI18n: {
          'en': 'English Title',
          'pt': 'Título em Português',
          'es': 'Título en Español',
        },
      );

      expect(form.getLocalizedTitle('en'), equals('English Title'));
      expect(form.getLocalizedTitle('pt'), equals('Título em Português'));
      expect(form.getLocalizedTitle('es'), equals('Título en Español'));
    });

    test('getLocalizedTitle falls back to default', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Default Title',
        titleI18n: {'pt': 'Título em Português'},
      );

      // Falls back to 'pt' when locale not found
      expect(form.getLocalizedTitle('fr'), equals('Título em Português'));

      // Falls back to default title when null locale
      expect(form.getLocalizedTitle(null), equals('Default Title'));
    });

    test('getLocalizedDescription returns correct translation', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Test',
        description: 'Default Description',
        descriptionI18n: {
          'en': 'English Description',
          'pt': 'Descrição em Português',
        },
      );

      expect(form.getLocalizedDescription('en'), equals('English Description'));
      expect(form.getLocalizedDescription('pt'), equals('Descrição em Português'));
    });

    test('getLocalizedDescription falls back correctly', () {
      FormDefinition form = FormDefinition(
        id: 'form123',
        title: 'Test',
        description: 'Default Description',
      );

      expect(form.getLocalizedDescription(null), equals('Default Description'));
      expect(form.getLocalizedDescription('en'), equals('Default Description'));
    });
  });

  group('FormItemDefinition', () {
    test('Create with required fields', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Test Item',
        type: FormItemType.text,
      );

      expect(item.id, equals('item123'));
      expect(item.label, equals('Test Item'));
      expect(item.type, equals(FormItemType.text));
      expect(item.required, isFalse);
      expect(item.allowPhotos, isTrue);
    });

    test('Create with all fields', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Select Item',
        type: FormItemType.select,
        options: ['A', 'B', 'C'],
        required: true,
        allowPhotos: false,
        labelI18n: {'en': 'Select', 'pt': 'Selecionar'},
        optionsI18n: {
          'en': ['A', 'B', 'C'],
          'pt': ['A', 'B', 'C'],
        },
      );

      expect(item.id, equals('item123'));
      expect(item.label, equals('Select Item'));
      expect(item.type, equals(FormItemType.select));
      expect(item.options, equals(['A', 'B', 'C']));
      expect(item.required, isTrue);
      expect(item.allowPhotos, isFalse);
      expect(item.labelI18n, isNotNull);
      expect(item.optionsI18n, isNotNull);
    });

    test('Create from json', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Number Item',
        type: FormItemType.number,
        required: true,
      );

      FormItemDefinition newItem = FormItemDefinition.fromJson(item.toJson());

      expect(newItem.id, equals(item.id));
      expect(newItem.label, equals(item.label));
      expect(newItem.type, equals(item.type));
      expect(newItem.required, equals(item.required));
    });

    test('JSON round-trip preserves data', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item456',
        label: 'Checklist Item',
        type: FormItemType.checklist,
        options: ['Check 1', 'Check 2', 'Check 3'],
        required: true,
        allowPhotos: true,
      );

      Map<String, dynamic> json = item.toJson();
      FormItemDefinition restored = FormItemDefinition.fromJson(json);

      expect(restored.toJson(), equals(item.toJson()));
    });

    test('getLocalizedLabel returns correct translation', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Default Label',
        type: FormItemType.text,
        labelI18n: {
          'en': 'English Label',
          'pt': 'Rótulo em Português',
        },
      );

      expect(item.getLocalizedLabel('en'), equals('English Label'));
      expect(item.getLocalizedLabel('pt'), equals('Rótulo em Português'));
    });

    test('getLocalizedLabel falls back correctly', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Default Label',
        type: FormItemType.text,
        labelI18n: {'pt': 'Rótulo em Português'},
      );

      // Falls back to 'pt' when locale not found
      expect(item.getLocalizedLabel('fr'), equals('Rótulo em Português'));

      // Falls back to default label when null locale
      expect(item.getLocalizedLabel(null), equals('Default Label'));
    });

    test('getLocalizedOptions returns correct translation', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Select',
        type: FormItemType.select,
        options: ['A', 'B', 'C'],
        optionsI18n: {
          'en': ['Option A', 'Option B', 'Option C'],
          'pt': ['Opção A', 'Opção B', 'Opção C'],
        },
      );

      expect(item.getLocalizedOptions('en'), equals(['Option A', 'Option B', 'Option C']));
      expect(item.getLocalizedOptions('pt'), equals(['Opção A', 'Opção B', 'Opção C']));
    });

    test('getLocalizedOptions falls back correctly', () {
      FormItemDefinition item = FormItemDefinition(
        id: 'item123',
        label: 'Select',
        type: FormItemType.select,
        options: ['A', 'B', 'C'],
      );

      expect(item.getLocalizedOptions(null), equals(['A', 'B', 'C']));
      expect(item.getLocalizedOptions('en'), equals(['A', 'B', 'C']));
    });

    test('All FormItemType values can be serialized', () {
      for (final type in FormItemType.values) {
        final item = FormItemDefinition(
          id: 'test_${type.name}',
          label: 'Test ${type.name}',
          type: type,
        );

        final json = item.toJson();
        final restored = FormItemDefinition.fromJson(json);

        expect(restored.type, equals(type));
      }
    });
  });

  group('FormItemType', () {
    test('All types exist', () {
      expect(FormItemType.values, contains(FormItemType.text));
      expect(FormItemType.values, contains(FormItemType.number));
      expect(FormItemType.values, contains(FormItemType.select));
      expect(FormItemType.values, contains(FormItemType.checklist));
      expect(FormItemType.values, contains(FormItemType.photoOnly));
      expect(FormItemType.values, contains(FormItemType.boolean));
    });
  });
}
