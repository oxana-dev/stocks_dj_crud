# API-requests examples (PowerShell / Invoke-RestMethod)
# Requires: python manage.py runserver activo en otra terminal

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8000/api/v1"
$jsonHeaders = @{ "Content-Type" = "application/json" }

# Helper: obtiene la lista de resultados de una respuesta paginada de DRF
function Get-DrfList($response) {
    if ($null -eq $response) { return @() }
    if ($response.PSObject.Properties.Name -contains 'results') { return @($response.results) }
    if ($response.PSObject.Properties.Name -contains 'value')   { return @($response.value)   }
    return @($response)
}


# ============================================================
# 0. CLEANUP DATABASE
# ============================================================

Write-Host "`n=== 0. Cleaning existing data ===" -ForegroundColor Yellow

$stocks = Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/stocks/" -Method Get -Headers $jsonHeaders)
foreach ($s in $stocks) {
    Invoke-RestMethod -Uri "$baseUrl/stocks/$($s.id)/" -Method Delete -Headers $jsonHeaders | Out-Null
    Write-Host "  Deleted stock id=$($s.id)"
}

$products = Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/products/" -Method Get -Headers $jsonHeaders)
foreach ($p in $products) {
    Invoke-RestMethod -Uri "$baseUrl/products/$($p.id)/" -Method Delete -Headers $jsonHeaders | Out-Null
    Write-Host "  Deleted product id=$($p.id)"
}

Write-Host "  Cleanup complete." -ForegroundColor Green


# ============================================================
# 1. CREATE 4 PRODUCTS
# ============================================================

Write-Host "`n=== 1. Create 4 products (POST /products/) ===" -ForegroundColor Cyan

$productData = @(
    @{ title = "Tomatoe";    description = "The best tomatoe" },
    @{ title = "Apple";      description = "Fresh red apples from the orchard" },
    @{ title = "Watermelon"; description = "Juicy summer watermelon" },
    @{ title = "Carrot";     description = "Crunchy orange carrots" }
)

$created = @()
foreach ($p in $productData) {
    $body = $p | ConvertTo-Json -Compress
    try {
        $resp = Invoke-RestMethod -Uri "$baseUrl/products/" -Method Post -Headers $jsonHeaders -Body $body
        Write-Host "  Created product id=$($resp.id) title=$($resp.title)"
        $created += $resp
    } catch {
        # Si ya existe (unique title), lo buscamos y reutilizamos su id
        $found = Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/products/?search=$($p.title)" -Method Get -Headers $jsonHeaders)
        $match = $found | Where-Object { $_.title -eq $p.title } | Select-Object -First 1
        if ($match) {
            Write-Host "  Product '$($p.title)' already existed, reusing id=$($match.id)" -ForegroundColor Yellow
            $created += $match
        } else {
            throw
        }
    }
}

$idTomatoe    = $created[0].id
$idApple      = $created[1].id
$idWatermelon = $created[2].id
$idCarrot     = $created[3].id


# ============================================================
# 2. RETRIEVE PRODUCTS
# ============================================================

Write-Host "`n=== 2. Retrieve products (GET /products/) ===" -ForegroundColor Cyan
Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/products/" -Method Get -Headers $jsonHeaders) |
    Format-Table id, title, description


# ============================================================
# 3. UPDATE A PRODUCT
# ============================================================

Write-Host "`n=== 3. Update a product (PATCH /products/$idTomatoe/) ===" -ForegroundColor Cyan
$body = '{"description": "The juiciest and most flavorful tomatoes."}'
Invoke-RestMethod -Uri "$baseUrl/products/$idTomatoe/" -Method Patch -Headers $jsonHeaders -Body $body |
    Format-Table id, title, description


# ============================================================
# 4. SEARCH PRODUCTS
# ============================================================

Write-Host "`n=== 4. Search products (GET /products/?search=Tomato) ===" -ForegroundColor Cyan
Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/products/?search=Tomato" -Method Get -Headers $jsonHeaders) |
    Format-Table id, title, description


# ============================================================
# 5. CREATE A WAREHOUSE
# ============================================================

Write-Host "`n=== 5. Create a warehouse (POST /stocks/) ===" -ForegroundColor Cyan

# Construimos el body como objeto PowerShell y lo convertimos a JSON
# (evita problemas de interpolación de strings y comas colgando)
$stockBodyObj = @{
    address   = "my address"
    positions = @(
        @{ product = $idTomatoe;    quantity = 250; price = 120.50 },
        @{ product = $idApple;      quantity = 100; price = 180.00 },
        @{ product = $idWatermelon; quantity = 50;  price = 95.00  },
        @{ product = $idCarrot;     quantity = 300; price = 40.00  }
    )
}
$body = $stockBodyObj | ConvertTo-Json -Depth 5

$stock = Invoke-RestMethod -Uri "$baseUrl/stocks/" -Method Post -Headers $jsonHeaders -Body $body
$stockId = $stock.id
Write-Host "  Created stock id=$stockId at $($stock.address)"


# ============================================================
# 6. RETRIEVE WAREHOUSES
# ============================================================

Write-Host "`n=== 6. Retrieve warehouses (GET /stocks/) ===" -ForegroundColor Cyan
Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/stocks/" -Method Get -Headers $jsonHeaders) |
    ConvertTo-Json -Depth 5


# ============================================================
# 7. UPDATE STOCK RECORDS
# ============================================================

Write-Host "`n=== 7. Update stock records (PATCH /stocks/$stockId/) ===" -ForegroundColor Cyan

$patchBodyObj = @{
    positions = @(
        @{ product = $idTomatoe;    quantity = 100; price = 130.80 },
        @{ product = $idApple;      quantity = 243; price = 145.00 },
        @{ product = $idWatermelon; quantity = 20;  price = 90.00  },
        @{ product = $idCarrot;     quantity = 150; price = 45.00  }
    )
}
$body = $patchBodyObj | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "$baseUrl/stocks/$stockId/" -Method Patch -Headers $jsonHeaders -Body $body |
    ConvertTo-Json -Depth 5


# ============================================================
# 8. SEARCH WAREHOUSES BY PRODUCT ID
# ============================================================

Write-Host "`n=== 8. Search warehouses by product id (GET /stocks/?products=$idTomatoe) ===" -ForegroundColor Cyan
Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/stocks/?products=$idTomatoe" -Method Get -Headers $jsonHeaders) |
    ConvertTo-Json -Depth 5


# ============================================================
# 9. SEARCH WAREHOUSES BY PRODUCT NAME
# ============================================================

Write-Host "`n=== 9. Search warehouses by product name (GET /stocks/?search=Watermelon) ===" -ForegroundColor Cyan
Get-DrfList (Invoke-RestMethod -Uri "$baseUrl/stocks/?search=Watermelon" -Method Get -Headers $jsonHeaders) |
    ConvertTo-Json -Depth 5


# ============================================================
# 10. DELETE A PRODUCT (al final, para no romper los stocks)
# ============================================================

Write-Host "`n=== 10. Delete a product (DELETE /products/$idCarrot/) ===" -ForegroundColor Cyan
Invoke-RestMethod -Uri "$baseUrl/products/$idCarrot/" -Method Delete -Headers $jsonHeaders | Out-Null
Write-Host "  Product id=$idCarrot (Carrot) deleted (204 No Content)"