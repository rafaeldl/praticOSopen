# Accumulated Field Component

## Overview

The Accumulated Field is a reusable form component that stores and suggests previously entered values per company. It automatically learns from user input, making data entry faster by suggesting commonly used values.

## Architecture

### Files

| File | Purpose |
|------|---------|
| `lib/models/accumulated_value.dart` | Data model for stored values |
| `lib/repositories/accumulated_value_repository.dart` | Firestore CRUD operations |
| `lib/widgets/accumulated_field.dart` | Reusable UI widget |

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
├── addOrIncrement()
├── getById()
├── remove()
├── removeByGroup()
└── updateValue()

AccumulatedField (Widget)
├── companyId: String
├── fieldType: String
├── label: String
├── groupId: String?
├── groupValue: String?
├── onSelected: Function(value, valueId)
└── allowRemove: bool
```

## Data Flow

```
User types in field
        ↓
Widget searches cached values (client-side)
        ↓
Dropdown shows matching suggestions
        ↓
User selects or submits new value
        ↓
Repository: addOrIncrement()
├── If exists: increment usageCount
└── If new: create with usageCount = 1
        ↓
Callback: onSelected(value, valueId)
        ↓
Parent widget receives value + ID
```

## Business Rules

1. **Multi-tenancy**: Values are isolated by `companyId`
2. **Field Types**: Each `fieldType` has its own collection of values
3. **Usage Tracking**: Values are sorted by `usageCount` (most used first)
4. **Deduplication**: Uses `searchKey` to prevent duplicate values
5. **Hierarchical Grouping**: Optional `groupId` for parent-child relationships
6. **Client-side Search**: No Firestore indexes needed for text search

## Usage Examples

### Independent Field (No Grouping)

```dart
AccumulatedField(
  companyId: Global.companyAggr!.id!,
  fieldType: 'deviceCategory',
  label: 'Categoria',
  initialValue: device.category,
  onSelected: (value, valueId) {
    device.category = value;
  },
)
```

### Hierarchical Fields (Parent-Child)

```dart
// Parent field (Brand)
AccumulatedField(
  companyId: companyId,
  fieldType: 'deviceBrand',
  label: 'Marca',
  initialValue: device.brand,
  onSelected: (value, valueId) {
    setState(() {
      device.brand = value;
      device.brandId = valueId;
      device.model = null;  // Clear child when parent changes
    });
  },
)

// Child field (Model) - filtered by brand
AccumulatedField(
  companyId: companyId,
  fieldType: 'deviceModel',
  label: 'Modelo',
  initialValue: device.model,
  groupId: device.brandId,      // Filter by parent
  groupValue: device.brand,     // Store parent reference
  onSelected: (value, valueId) {
    device.model = value;
  },
)
```

### Disabling Remove Button

```dart
AccumulatedField(
  companyId: companyId,
  fieldType: 'paymentCondition',
  label: 'Condição de Pagamento',
  allowRemove: false,  // Hide remove button
  onSelected: (value, valueId) => ...,
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

### addOrIncrement(companyId, fieldType, value, {groupId, groupValue})

Adds a new value or increments usage count if exists.

```dart
final valueId = await repo.addOrIncrement(
  companyId,
  'deviceModel',
  'Galaxy S24',
  groupId: brandId,
  groupValue: 'Samsung',
);
```

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
