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
  value: "Samsung",              // Display value
  searchKey: "samsung",          // Lowercase for search
  usageCount: 12,                // Frequency (for sorting)
  groupId: "abc123",             // Optional: parent value ID
  groupValue: "Electronics",     // Optional: parent display value
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Class Diagram

```
AccumulatedValue (Model)
├── id: String?
├── value: String
├── searchKey: String
├── usageCount: int
├── groupId: String?
├── groupValue: String?
├── createdAt: DateTime?
└── updatedAt: DateTime?

AccumulatedValueRepository
├── search()
├── getAll()
├── streamAll()
├── use()              // Simplified: addOrIncrement
├── getById()
├── remove()
├── removeByGroup()
└── updateValue()

AccumulatedValueListScreen (Screen)
├── Uses: companyId from Global.companyAggr?.id (automatic)
├── Receives (arguments):
│   ├── fieldType: String (required - e.g., 'deviceBrand')
│   ├── title: String (optional - defaults to context.l10n.select)
│   ├── currentValue: String? (optional - for highlighting)
│   ├── groupId: String? (optional - for hierarchical filtering)
│   └── groupValue: String? (optional - for storing parent reference)
├── Shows: Searchable list + "Add new" option
└── Returns: String value via Navigator.pop()
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

### Example 2: Hierarchical Fields (Parent-Child)

```dart
// Parent field (Brand)
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

// Child field (Model) - filtered by brand
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
        'groupId': device.manufacturer,      // Filter by parent
        'groupValue': device.manufacturer,   // Store parent reference
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

### Example 3: Custom Button

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

| fieldType | Description | Group By |
|-----------|-------------|----------|
| `deviceCategory` | Device categories | - |
| `deviceBrand` | Device brands | - |
| `deviceModel` | Device models | `deviceBrand` |
| `serviceCategory` | Service categories | - |
| `productCategory` | Product categories | - |
| `productBrand` | Product brands | `productCategory` |
| `paymentCondition` | Payment conditions | - |

## Repository API

### search(companyId, fieldType, query, {groupId, limit})

Searches values by query string with optional group filtering.

```dart
final values = await repo.search(
  companyId,
  'deviceBrand',
  'sam',  // Finds "Samsung", "Samson", etc.
  limit: 10,
);
```

### use(companyId, fieldType, value, {groupId, groupValue})

Records usage of a value (creates new or increments count if exists).

```dart
final valueId = await repo.use(
  companyId,
  'deviceModel',
  'Galaxy S24',
  groupId: 'Samsung',
  groupValue: 'Samsung',
);
```

**Note**: `companyId` is automatically retrieved from `Global.companyAggr` in the screen.

### remove(companyId, fieldType, valueId)

Removes a specific value.

```dart
await repo.remove(companyId, 'deviceBrand', valueId);
```

### removeByGroup(companyId, fieldType, groupId)

Removes all values belonging to a group (cascade delete).

```dart
// Remove brand and all its models
await repo.remove(companyId, 'deviceBrand', brandId);
await repo.removeByGroup(companyId, 'deviceModel', brandId);
```

## Migration from Device Catalog

The Accumulated Field can replace the existing Device Catalog implementation:

| Device Catalog | Accumulated Field |
|----------------|-------------------|
| `brands` collection | `fieldType: 'deviceBrand'` |
| `deviceCatalog` collection | `fieldType: 'deviceModel'` |
| `brandId` reference | `groupId` |
| `brand` denormalized | `groupValue` |

To migrate:
1. Update screens to use `AccumulatedField` widget
2. Migrate existing data from `brands/` to `accumulatedFields/deviceBrand/values/`
3. Migrate existing data from `deviceCatalog/` to `accumulatedFields/deviceModel/values/`
4. Remove old `DeviceCatalogRepository` and `DeviceAutocompleteField`

## Performance Considerations

1. **Caching**: Widget caches all values on init for fast client-side search
2. **No Indexes**: Uses `orderBy('usageCount')` only - no composite indexes needed
3. **Lazy Loading**: Suggestions load on focus, not on widget creation
4. **Debouncing**: Consider adding debounce for very large value sets (future enhancement)

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
