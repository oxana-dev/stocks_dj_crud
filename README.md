# Stocks & Products API

## A REST API for managing products and warehouses, built with Django and Django REST Framework

## Overview

This project provides a complete CRUD API for a simple inventory system. A company sells **products** (described by a title and an optional description) and stores them across multiple **warehouses**. Each product stored in a warehouse has its own quantity and storage price, so the same product can have different prices at different warehouses.

The API is exposed under the `/api/v1/` prefix and supports:

- Full CRUD operations for products and warehouses
- Nested creation and update of warehouse positions (products stored in a warehouse)
- Search of products by title and description
- Search of warehouses containing a specific product — by product id **or** by product title/description
- Pagination for list endpoints

## Tech Stack

- Python 3

- Django 3.2

- Django REST Framework

- PostgreSQL (`psycopg2-binary`)

## Data Model

The application is built around three related entities: **Product**, **Stock**, and **StockProduct**.

### Product

Represents a product sold by the company.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `BigAutoField` | Primary key | Auto-generated identifier |
| `title` | `CharField(max_length=60)` | Unique, required | Product name |
| `description` | `TextField` | Nullable, blank | Optional product description |

### Stock

Represents a warehouse where products are stored.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `BigAutoField` | Primary key | Auto-generated identifier |
| `address` | `CharField(max_length=200)` | Unique, required | Warehouse address |
| `products` | `ManyToManyField(Product)` | Through `StockProduct`, `related_name='stocks'` | Products stored in this warehouse |

### StockProduct

Join table between `Stock` and `Product`. Implemented as an explicit `through` model because each position carries extra data (quantity and price), allowing the same product to have different prices and quantities at different warehouses.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | `BigAutoField` | Primary key | Auto-generated identifier |
| `stock` | `ForeignKey(Stock)` | `on_delete=CASCADE`, `related_name='positions'` | Warehouse reference |
| `product` | `ForeignKey(Product)` | `on_delete=CASCADE`, `related_name='positions'` | Product reference |
| `quantity` | `PositiveIntegerField` | Default `1` | Number of units stored |
| `price` | `DecimalField(max_digits=18, decimal_places=2)` | `MinValueValidator(0)` | Storage price per unit |

### Relationships

```text
Product ─────┐
             │
             ├──< StockProduct >──── Stock
             │
             └── (M:N via StockProduct, related_name 'stocks' / 'positions')
```

- **Product ↔ Stock** — many-to-many, resolved through `StockProduct`.
- **Stock → StockProduct** — one-to-many (`related_name='positions'`).
- **Product → StockProduct** — one-to-many (`related_name='positions'`).
- Deleting a `Stock` or a `Product` cascades to its related `StockProduct` rows.

## API Endpoints

All endpoints are available under `http://localhost:8000/api/v1`.

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/products/` | Create a product |
| `GET` | `/products/` | List products (paginated) |
| `GET` | `/products/{id}/` | Retrieve a product |
| `PATCH` | `/products/{id}/` | Update a product |
| `DELETE` | `/products/{id}/` | Delete a product |
| `GET` | `/products/?search=помидор` | Search products by title/description |
| `POST` | `/stocks/` | Create a warehouse with positions |
| `GET` | `/stocks/` | List warehouses (paginated) |
| `GET` | `/stocks/{id}/` | Retrieve a warehouse |
| `PATCH` | `/stocks/{id}/` | Update a warehouse and its positions |
| `DELETE` | `/stocks/{id}/` | Delete a warehouse |
| `GET` | `/stocks/?products=2` | Find warehouses containing product with id 2 |
| `GET` | `/stocks/?search=помид` | Find warehouses containing a product by title/description |


### Example: Create a product


```http
POST /api/v1/products/
Content-Type: application/json

{
  "title": "Tomato",
  "description": "The best tomatoes on the market"
}
```

### Example: Create a warehouse with positions

```http
POST /api/v1/stocks/
Content-Type: application/json

{
  "address": "123 Main Street, Springfield",
  "positions": [
    {
      "product": 2,
      "quantity": 250,
      "price": 120.50
    },
    {
      "product": 3,
      "quantity": 100,
      "price": 180
    }
  ]
}
```

### Example: Update warehouse positions

```http
PATCH /api/v1/stocks/4/
Content-Type: application/json

{
  "positions": [
    {
      "product": 2,
      "quantity": 100,
      "price": 130.80
    },
    {
      "product": 3,
      "quantity": 243,
      "price": 145
    }
  ]
}
```

## Implementation Notes

- **Nested writes** — `StockSerializer` overrides `create()` and `update()` to handle the `positions` list. On update, `update_or_create()` is used with `(stock, product)` as the lookup key, so existing positions are updated and new ones are added in a single request.
- **Search** — `SearchFilter` from DRF is used with `search_fields`:
  - Products: `title`, `description`
  - Stocks: `positions__product__title`, `positions__product__description` (this enables searching warehouses by a product's name or description fragment)
- **Filtering by product id** — `?products=<id>` is supported on the stocks endpoint via `django-filter`.
- **Pagination** — `PageNumberPagination` is enabled on both viewsets.

See `requests-examples.http` for a complete set of ready-to-run request examples.

## Project Structure

```text
stocks_products/        # Django project settings
├── settings.py
├── urls.py             # /api/v1/ → logistic.urls
├── asgi.py
└── wsgi.py

logistic/               # Main application
├── models.py           # Product, Stock, StockProduct
├── serializers.py      # ProductSerializer, ProductPositionSerializer, StockSerializer
├── views.py            # ProductViewSet, StockViewSet
├── urls.py             # DefaultRouter registration
├── admin.py
├── apps.py
└── migrations/
    └── 0001_initial.py

manage.py
requirements.txt
requests-examples.http
```

## Getting Started

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure the database

Make sure PostgreSQL is running locally, and create a database matching the configuration in `stocks_products/settings.py` (by default: `netology_stocks_products` on `127.0.0.1:5432`).

### 3. Apply migrations

```bash
python manage.py migrate
```

### 4. Run the development server

```bash
python manage.py runserver
```

The API will be available at `http://localhost:8000/api/v1/`.

### 5. Try the endpoints

Use the provided `requests-examples.http` file with any HTTP client that supports the `.http` format (e.g. PyCharm's built-in HTTP client, VS Code's REST Client, or IntelliJ HTTP Client).

## Requirements

```text
django
djangorestframework
django-filter
psycopg2-binary
```