<?php

declare(strict_types=1);

$root = dirname(__DIR__);
require_once $root . '/vegetable_api/bootstrap.php';

use Gruno\Repositories\ProductRepository;

function normalize_level(string $value): string
{
    return strtolower(trim($value));
}

function recalculate_predicted_price(array $product): float
{
    $itemName = strtolower(trim((string) ($product['name'] ?? '')));
    $currentPrice = (float) ($product['current_price'] ?? $product['price'] ?? 0);
    $demandLevel = normalize_level((string) ($product['demand_level'] ?? ''));
    $supplyLevel = normalize_level((string) ($product['supply_level'] ?? ''));
    $temperature = (float) ($product['temperature'] ?? 0);
    $rainfall = (float) ($product['rainfall'] ?? 0);
    $festivalFlag = (int) ($product['festival_flag'] ?? 0);

    $discount = max($currentPrice * 0.1, 1.0);

    if ($temperature > 30) {
        $discount += 2;
    }
    if ($rainfall > 2) {
        $discount += 2;
    }
    if ($demandLevel === 'low') {
        $discount += 4;
    } elseif ($demandLevel === 'medium') {
        $discount += 2;
    }
    if ($supplyLevel === 'high') {
        $discount += 4;
    } elseif ($supplyLevel === 'medium') {
        $discount += 2;
    }
    if ($festivalFlag === 1) {
        $discount -= 1;
    }

    if ($itemName === 'tomato' && $rainfall > 0) {
        $discount += 1;
    }
    if ($itemName === 'onion' && $temperature > 28) {
        $discount += 1;
    }
    if ($itemName === 'potato' && $temperature > 30) {
        $discount += 1;
    }

    $predictedPrice = max(1.0, $currentPrice - $discount);
    if ($predictedPrice >= $currentPrice) {
        $predictedPrice = max(1.0, $currentPrice - 1.0);
    }

    return round($predictedPrice, 2);
}

$repository = new ProductRepository(gruno_db());
$products = $repository->all();
$updated = [];

foreach ($products as $product) {
    $productId = (int) ($product['id'] ?? 0);
    if ($productId <= 0) {
        continue;
    }

    $predictedPrice = recalculate_predicted_price($product);
    $updatedProduct = $repository->update(
        $productId,
        (string) ($product['name'] ?? ''),
        (string) ($product['category'] ?? ''),
        (float) ($product['price'] ?? 0),
        (float) ($product['current_price'] ?? $product['price'] ?? 0),
        $predictedPrice,
        (string) ($product['season'] ?? ''),
        (string) ($product['demand_level'] ?? ''),
        (float) ($product['rainfall'] ?? 0),
        (float) ($product['temperature'] ?? 0),
        (string) ($product['supply_level'] ?? ''),
        (int) ($product['festival_flag'] ?? 0),
        (int) ($product['stock'] ?? 0),
        (string) ($product['image_url'] ?? ''),
        (int) ($product['is_favorite'] ?? 0)
    );

    $updated[] = [
        'id' => $productId,
        'name' => (string) ($updatedProduct['name'] ?? $product['name'] ?? ''),
        'current_price' => (float) ($updatedProduct['current_price'] ?? $product['current_price'] ?? 0),
        'predicted_price' => (float) ($updatedProduct['predicted_price'] ?? $predictedPrice),
    ];
}

echo json_encode(
    [
        'updated_count' => count($updated),
        'products' => $updated,
    ],
    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
);
