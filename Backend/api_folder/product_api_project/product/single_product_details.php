<?php
include '../../connection.php';

header('Content-Type: application/json');

$product_id = $_GET['product_id'] ?? '';

if (!$product_id) {
    echo json_encode(['success' => false, 'message' => 'Missing product_id']);
    exit;
}

// Step 1: Fetch product basic details with category
$lang = $_GET['lang'] ?? '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

$name_col = "p.name";
$desc_col = "p.description";
$cat_col = "c.name";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
    $cat_col = "COALESCE(NULLIF(c.name_$lang, ''), c.name)";
}

$sql = "SELECT 
            p.id, $name_col AS name, p.name_hi, p.name_hn, 
            $desc_col AS description, p.description_hi, p.description_hn, 
            p.main_category_id,
            $cat_col AS category_name
        FROM products p
        LEFT JOIN main_category c ON p.main_category_id = c.id
        WHERE p.id = ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $product_id);
$stmt->execute();
$productResult = $stmt->get_result();

if ($productResult->num_rows === 0) {
    echo json_encode(['success' => false, 'message' => 'Product not found']);
    exit;
}

$product = $productResult->fetch_assoc();

// Step 2: Fetch variants
$variants = [];
$var_select = "*";
if ($lang === 'hi' || $lang === 'hn') {
    $var_select = "id, product_id, name_hi, name_hn, price, selling_price, wholesale_price, stock, COALESCE(NULLIF(name_$lang, ''), name) AS name";
}
$stmt2 = $conn->prepare("SELECT $var_select FROM product_variants WHERE product_id = ?");
$stmt2->bind_param("i", $product_id);
$stmt2->execute();
$result2 = $stmt2->get_result();
while ($row = $result2->fetch_assoc()) {
    $variants[] = $row;
}

// Step 3: Fetch product info
$info = [];
$info_select = "*";
if ($lang === 'hi' || $lang === 'hn') {
    $info_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
}
$stmt3 = $conn->prepare("SELECT $info_select FROM product_info WHERE product_id = ?");
$stmt3->bind_param("i", $product_id);
$stmt3->execute();
$result3 = $stmt3->get_result();
while ($row = $result3->fetch_assoc()) {
    $info[] = $row;
}

// Step 4: Fetch highlights
$highlights = [];
$high_select = "*";
if ($lang === 'hi' || $lang === 'hn') {
    $high_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
}
$stmt4 = $conn->prepare("SELECT $high_select FROM product_highlights WHERE product_id = ?");
$stmt4->bind_param("i", $product_id);
$stmt4->execute();
$result4 = $stmt4->get_result();
while ($row = $result4->fetch_assoc()) {
    $highlights[] = $row;
}

// Step 5: Fetch images
$images = [];
$stmt5 = $conn->prepare("SELECT image_url FROM product_images WHERE product_id = ?");
$stmt5->bind_param("i", $product_id);
$stmt5->execute();
$result5 = $stmt5->get_result();
while ($row = $result5->fetch_assoc()) {
    $images[] = $row['image_url'];
}

// Combine all data
$response = [
    'success' => true,
    'product' => [
        'id' => (string)$product['id'],
        'name' => $product['name'],
        'name_hi' => $product['name_hi'] ?? '',
        'name_hn' => $product['name_hn'] ?? '',
        'description' => $product['description'],
        'description_hi' => $product['description_hi'] ?? '',
        'description_hn' => $product['description_hn'] ?? '',
        'category' => $product['category_name'] ?? '',
        'subcategory' => '',
        'category_id' => (string)$product['main_category_id'],
        'subcategory_id' => '',
        'main_category_id' => (string)$product['main_category_id'],
        'variants' => $variants,
        'info' => $info,
        'highlights' => $highlights,
        'images' => $images
    ]
];

echo json_encode($response);
