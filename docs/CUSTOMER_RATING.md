# Customer Rating System

## Overview

The customer rating system allows customers to rate their service experience when viewing completed orders (status: `done`) through the public magic link. The rating is embedded in the Order document and displayed in the app.

## Data Model

### OrderRating (Flutter)

```dart
@JsonSerializable()
class OrderRating {
  int? score;           // 1-5 stars
  String? comment;      // Optional (max 500 chars)
  DateTime? createdAt;
  String? customerName;

  bool get hasRating => score != null && score! >= 1 && score! <= 5;
}
```

Location: `lib/models/order.dart`

### Firestore Structure

The rating is stored as a nested object in the Order document:

```json
{
  "id": "order123",
  "status": "done",
  "rating": {
    "score": 5,
    "comment": "Excellent service!",
    "createdAt": "2025-01-15T14:30:00Z",
    "customerName": "John Doe"
  }
}
```

Path: `/companies/{companyId}/orders/{orderId}`

## API Endpoint

### POST /public/orders/:token/rating

Submit a rating for a completed order.

**Request:**
```json
{
  "score": 5,
  "comment": "Great service!"
}
```

**Validations:**
- Token must be valid (checked by middleware)
- Score must be integer between 1-5
- Comment is optional, max 500 characters
- Order must have status `done`
- Order must not already have a rating

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "message": "Rating submitted successfully",
    "rating": {
      "score": 5,
      "comment": "Great service!",
      "createdAt": "2025-01-15T14:30:00Z",
      "customerName": "John Doe"
    }
  }
}
```

**Error Codes:**
- `VALIDATION_ERROR`: Invalid score or comment
- `INVALID_STATUS`: Order is not completed
- `ALREADY_RATED`: Order has already been rated

## Flow

### Customer (Web)

1. Customer opens magic link for completed order
2. Rating section appears with 5 interactive stars
3. Customer selects rating (1-5 stars)
4. Optionally adds a comment
5. Submits rating
6. Confirmation message shown

### Team (App)

1. Push notification sent when rating is submitted
2. Rating displayed in order detail page
3. All ratings viewable in dedicated Ratings screen
4. Average rating calculated and displayed

## Notifications

When a customer submits a rating, a push notification is sent to the team:

```
Title: Nova Avaliação! ⭐⭐⭐⭐⭐
Body: {customerName} avaliou a OS #{number} com {score} estrelas
```

## UI Components

### Web (Public Link)

- **Star Rating Input**: 5 interactive stars with hover effects
- **Comment Textarea**: Optional, max 500 characters
- **Submit Button**: Golden gradient, disabled until rating selected
- **Rating Display**: Read-only view when already rated

Location: `firebase/hosting/src/js/order-view.js`

### Flutter App

#### Order Form Rating Section

Displays the rating (if exists) in the order detail page:
- Stars (filled/empty)
- Score (e.g., "5/5")
- Comment in italic
- Customer name and date

Location: `lib/screens/order_form.dart` - `_buildRatingSection()`

#### Ratings Screen

Lists all rated orders with:
- Summary card: average rating and total count
- List of ratings with score badge, stars, comment preview
- Navigation to order detail

Location: `lib/screens/ratings/ratings_screen.dart`

## Internationalization

### Supported Languages

- Portuguese (pt-BR)
- English (en-US)
- Spanish (es-ES)

### Key Translations

| Key | PT | EN | ES |
|-----|----|----|-----|
| rating | Avaliação | Rating | Calificación |
| ratings | Avaliações | Ratings | Calificaciones |
| averageRating | Média das avaliações | Average rating | Promedio de calificaciones |
| rateService | Avalie nosso serviço | Rate our service | Califica nuestro servicio |
| rateSuccess | Obrigado pela sua avaliação! | Thank you for your rating! | ¡Gracias por tu calificación! |

## Files Modified/Created

### Backend

- `firebase/functions/src/models/types.ts` - Added OrderRating interface
- `firebase/functions/src/services/notification.service.ts` - Added notifyOrderRated()
- `firebase/functions/src/routes/public/orders.routes.ts` - Added POST /rating endpoint

### Web Frontend

- `firebase/hosting/src/js/order-view.js` - Added rating UI and i18n
- `firebase/hosting/src/css/order-view.css` - Added rating styles

### Flutter

- `lib/models/order.dart` - Added OrderRating class and rating field
- `lib/screens/order_form.dart` - Added _buildRatingSection()
- `lib/screens/ratings/ratings_screen.dart` - New screen
- `lib/repositories/v2/order_repository_v2.dart` - Added getRatedOrders()
- `lib/routes.dart` - Added /ratings route
- `lib/screens/menu_navigation/settings.dart` - Added ratings menu entry
- `lib/l10n/app_pt.arb`, `app_en.arb`, `app_es.arb` - Added rating strings

## Query for Firestore Index

The ratings screen queries orders with ratings. Ensure this composite index exists:

```
Collection: companies/{companyId}/orders
Fields:
  - rating.score (Ascending)
  - rating.createdAt (Descending)
```

## Security Rules

The rating endpoint validates:
1. Valid share token
2. Order belongs to the token's company
3. Order status is `done`
4. Order has not been rated yet

No direct Firestore writes from client - all rating submissions go through the API.
