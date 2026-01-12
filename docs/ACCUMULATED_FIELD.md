# Accumulated Field System

## Overview

The Accumulated Field System stores and suggests previously entered values per company. It automatically learns from user input, making data entry faster by suggesting commonly used values.

**Architecture Philosophy**: Provide a selection screen, let developers choose their own input UI (ListTile, TextField, Button, etc).

## Architecture

### Files

| File | Purpose |
|------|---------|
| `lib/models/accumulated_value.dart` | Data model for stored values |
| `lib/repositories/accumulated_value_repository.dart` | Firestore CRUD operations |
| `lib/screens/accumulated_value_list_screen.dart` | Selection/creation screen |

### Firestore Structure

```
companies/{companyId}/accumulatedFields/{fieldType}/values/{valueId}
{
  value: "Galaxy S21",           // Display value
  searchKey: "galaxy s21",       // Lowercase for search
  usageCount: 12,                // Frequency (for sorting)
  group: "smartphone-samsung",   // Optional: normalized parent value(s) for filtering
  createdAt: "2025-01-09T10:00:00.000Z",  // ISO8601 string
  updatedAt: "2025-01-09T10:00:00.000Z"   // ISO8601 string
}
```

### Class Diagram

```
AccumulatedValue (Model)
├── id: String?
├── value: String
├── searchKey: String (lowercase for search)
├── usageCount: int
├── group: String? (normalized lowercase for hierarchical filtering)
├── createdAt: DateTime?
└── updatedAt: DateTime?

AccumulatedValueRepository
├── getAll(companyId, fieldType, {group?})
├── streamAll(companyId, fieldType, {group?})
├── use(companyId, fieldType, value, {group?})  // Create or increment
├── remove(companyId, fieldType, valueId)
└── Client-side sorting by usageCount (no Firestore indexes needed)

AccumulatedValueListScreen (Screen)
├── Uses: companyId from Global.companyAggr?.id (automatic)
├── Receives (arguments):
│   ├── fieldType: String (required - e.g., 'deviceBrand')
│   ├── title: String (optional - defaults to context.l10n.select)
│   ├── multiSelect: bool (optional - default: false)
│   ├── currentValue: String? (optional - for single-select highlighting)
│   ├── currentValues: List<String>? (optional - for multi-select initial values)
│   └── group: String? or List? (optional - parent value(s) for filtering)
│       - String: used as-is (normalized to lowercase)
│       - List: non-null values joined with '-' (e.g., ['smartphone', 'samsung'] → 'smartphone-samsung')
├── Shows: Searchable list + "Add new" option + Swipe-to-delete
├── Returns:
│   - Single-select: String value via Navigator.pop()
│   - Multi-select: List<String> values via Navigator.pop()
└── Multi-select: Shows "Done" button in navigation bar
```

## Data Flow

```
User taps field (ListTile/Button/TextField/etc)
        ↓
Navigate to AccumulatedValueListScreen
        ↓
User searches or browses list (sorted by usageCount)
        ↓
User selects existing OR adds new value
        ↓
Repository: use(value)
├── If exists: increment usageCount
└── If new: create with usageCount = 1
        ↓
Navigator.pop(context, value)
        ↓
Parent receives String value and updates state
```

## Business Rules

1. **Multi-tenancy**: Values are isolated by `companyId`
2. **Field Types**: Each `fieldType` has its own collection of values
3. **Usage Tracking**: Values are sorted by `usageCount` (most used first)
4. **Deduplication**: Uses `searchKey` to prevent duplicate values
5. **Hierarchical Grouping**: Optional `groupId` for parent-child relationships
6. **Client-side Search**: No Firestore indexes needed for text search

## Usage Examples

### Example 1: CupertinoListTile (Recommended - iOS native)

```dart
CupertinoListTile(
  title: Text('Marca'),
  additionalInfo: Text(
    device.manufacturer ?? 'Selecionar',
    style: TextStyle(
      color: device.manufacturer != null
          ? CupertinoColors.label.resolveFrom(context)
          : CupertinoColors.placeholderText.resolveFrom(context),
    ),
  ),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceBrand',
        'title': 'Marca',
        'currentValue': device.manufacturer,
      },
    );

    if (value != null && value is String) {
      setState(() {
        device.manufacturer = value;
      });
    }
  },
)
```

### Example 2: Hierarchical Fields (Multi-Level)

```dart
// Level 1: Category
CupertinoListTile(
  title: Text('Categoria'),
  additionalInfo: Text(device.category ?? 'Selecionar'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceCategory',
        'title': 'Categoria',
        'currentValue': device.category,
      },
    );

    if (value != null && value is String) {
      setState(() {
        device.category = value;
        device.manufacturer = null;  // Clear children when parent changes
        device.model = null;
      });
    }
  },
)

// Level 2: Brand
CupertinoListTile(
  title: Text('Marca'),
  additionalInfo: Text(device.manufacturer ?? 'Selecionar'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceBrand',
        'title': 'Marca',
        'currentValue': device.manufacturer,
      },
    );

    if (value != null && value is String) {
      setState(() {
        device.manufacturer = value;
        device.model = null;  // Clear child when parent changes
      });
    }
  },
)

// Level 3: Model - filtered by category AND brand
// Just pass an array - the screen handles the rest!
CupertinoListTile(
  title: Text('Modelo'),
  additionalInfo: Text(device.model ?? 'Selecionar'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'deviceModel',
        'title': 'Modelo',
        'currentValue': device.model,
        'group': [device.category, device.manufacturer],  // Pass array, nulls filtered automatically
      },
    );

    if (value != null && value is String) {
      setState(() {
        device.model = value;
      });
    }
  },
)
```

**Why combined group?**
Separates models by device type + brand. For example:
- `['smartphone', 'samsung']` → filtered by `smartphone-samsung`
- `['tablet', 'samsung']` → filtered by `tablet-samsung`
- `['smartphone', 'apple']` → filtered by `smartphone-apple`
- `['tablet', 'apple']` → filtered by `tablet-apple`

Results:
- "Galaxy S21" under `smartphone-samsung`
- "Galaxy Tab S7" under `tablet-samsung`
- "iPhone 13" under `smartphone-apple`
- "iPad Pro" under `tablet-apple`

### Example 3: Multi-Select

```dart
// Model with multiple tags/categories
class Product extends BaseAuditCompany {
  String? name;
  List<String>? tags;  // Multiple tags
  // ...
}

// Field with multi-select
CupertinoListTile(
  title: Text('Tags'),
  additionalInfo: Text(
    product.tags != null && product.tags!.isNotEmpty
        ? product.tags!.join(', ')
        : context.l10n.select,
  ),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () async {
    final values = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        'fieldType': 'productTag',
        'title': 'Tags',
        'multiSelect': true,              // Enable multi-select
        'currentValues': product.tags,    // Pass current list
      },
    );

    if (values != null && values is List) {
      setState(() {
        product.tags = values.cast<String>();
      });
    }
  },
)
```

**Multi-select behavior:**
- Tap items to toggle selection (checkmarks appear)
- "Done" button in navigation bar to confirm
- Returns `List<String>` with all selected values
- Can add new values while selecting

### Example 4: Custom Button

```dart
CupertinoButton(
  child: Text(device.category ?? '+ Adicionar Categoria'),
  onPressed: () async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        
        'fieldType': 'deviceCategory',
        'title': 'Categoria',
        'currentValue': device.category,
      },
    );

    if (value != null && value is String) {
      setState(() => device.category = value);
    }
  },
)
```

### Example 4: Read-only TextField

```dart
GestureDetector(
  onTap: () async {
    final value = await Navigator.pushNamed(
      context,
      '/accumulated_value_list',
      arguments: {
        
        'fieldType': 'deviceBrand',
        'title': 'Marca',
        'currentValue': device.manufacturer,
      },
    );

    if (value != null) {
      setState(() => device.manufacturer = value);
    }
  },
  child: CupertinoTextField(
    controller: TextEditingController(text: device.manufacturer),
    enabled: false,
    suffix: Icon(CupertinoIcons.chevron_right),
  ),
)
```

## Field Types Reference

| fieldType | Description | Group Format | Multi-Select |
|-----------|-------------|--------------|--------------|
| `deviceCategory` | Device categories (smartphone, tablet, laptop) | - | No |
| `deviceBrand` | Device brands (Samsung, Apple, Dell) | - | No |
| `deviceModel` | Device models (Galaxy S21, iPad Pro) | `category-brand` | No |
| `serviceCategory` | Service categories | - | No |
| `productCategory` | Product categories | - | No |
| `productBrand` | Product brands | `category` | No |
| `productTag` | Product tags (new, promotion, featured) | - | **Yes** |
| `paymentMethod` | Payment methods (cash, pix, card) | - | Possible |
| `paymentCondition` | Payment conditions | - | No |

## Repository API

### getAll(companyId, fieldType, {group})

Gets all values for a field type with optional group filtering.

```dart
// Get all brands
final brands = await repo.getAll(companyId, 'deviceBrand');

// Get models for specific category-brand combination
final models = await repo.getAll(
  companyId,
  'deviceModel',
  group: 'smartphone-samsung',
);
```

Results are automatically sorted by `usageCount` (most used first) on the client side.

### streamAll(companyId, fieldType, {group})

Same as `getAll()` but returns a `Stream<List<AccumulatedValue>>` for real-time updates.

```dart
final stream = repo.streamAll(
  companyId,
  'deviceModel',
  group: 'smartphone-samsung',
);
```

### use(companyId, fieldType, value, {group})

Records usage of a value (creates new or increments count if exists).

```dart
// Simple field without group
final categoryId = await repo.use(
  companyId,
  'deviceCategory',
  'Smartphone',
);

// Hierarchical field with group
final modelId = await repo.use(
  companyId,
  'deviceModel',
  'Galaxy S21',
  group: 'smartphone-samsung',  // Automatically normalized to lowercase
);
```

**Note**: `companyId` is automatically retrieved from `Global.companyAggr` in the screen.

### remove(companyId, fieldType, valueId)

Removes a specific value.

```dart
await repo.remove(companyId, 'deviceBrand', valueId);
```

## Migration from Device Catalog

The Accumulated Field system replaced the existing Device Catalog implementation:

| Old Device Catalog | New Accumulated Field |
|-------------------|----------------------|
| `brands` collection | `fieldType: 'deviceBrand'` |
| `deviceCatalog` collection | `fieldType: 'deviceModel'` |
| `brandId` reference | `group: 'category-brand'` |
| `brand` denormalized | Removed (simplified) |
| `DeviceAutocompleteField` widget | `AccumulatedValueListScreen` navigation |
| `DeviceCatalogRepository` | `AccumulatedValueRepository` |

## When to Use Multi-Select vs Single-Select

### Single-Select (default)
Use when the entity should have **only one value** for the field:
- Device category (one category per device)
- Device brand (one brand per device)
- Device model (one model per device)
- Customer type (residential, commercial, or industrial - not multiple)
- Payment condition (one payment term)

**Returns**: `String`

### Multi-Select
Use when the entity can have **multiple values** for the field:
- Product tags (promotional, featured, new arrival, etc.)
- Service categories (a service can fit multiple categories)
- Payment methods accepted (cash, pix, credit card, debit card)
- Customer segments (a customer can be in multiple segments)
- Order problems (multiple issues can occur simultaneously)

**Returns**: `List<String>`

**Example use cases:**
```dart
// Product with multiple tags
product.tags = ['promotion', 'featured', 'new']

// Service applicable to multiple categories
service.categories = ['maintenance', 'preventive', 'residential']

// Payment methods accepted
company.acceptedPayments = ['cash', 'pix', 'credit', 'debit']
```

## Performance Considerations

1. **Client-side Sorting**: No Firestore composite indexes needed - sorting by `usageCount` happens in memory after fetching
2. **Client-side Search**: Filtering by `searchKey` happens in memory using `.contains()`
3. **Normalized Groups**: All group values are automatically normalized to lowercase for efficient querying
4. **Swipe-to-Delete**: Native iOS gesture for item removal
5. **Automatic Reload**: List refreshes when returning from navigation to always show latest values
6. **Multi-Select State**: Managed in memory - no performance impact for large selections

## Security Rules

Firestore rules should ensure:
- Users can only read/write values for companies they belong to
- `companyId` path segment matches user's company

```javascript
match /companies/{companyId}/accumulatedFields/{fieldType}/values/{valueId} {
  allow read, write: if request.auth != null
    && request.auth.token.companyId == companyId;
}
```
