<?php
include '../../connection.php';
header('Content-Type: application/json');

$keyword = isset($_GET['keyword']) ? trim($_GET['keyword']) : '';
$keyword = mysqli_real_escape_string($conn, $keyword);
$lang = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

if ($keyword === '') {
    echo json_encode([
        "success" => false,
        "message" => "Keyword missing"
    ]);
    exit;
}

// Lowecase conversion for mapping
$lower = strtolower($keyword);

// Synonym mapping to DB terms
$searchTerms = [];

if (str_contains($lower, 'aata') || str_contains($lower, 'atta') || str_contains($lower, 'flour')) {
    $searchTerms[] = 'atta';
    $searchTerms[] = 'flour';
}
if (str_contains($lower, 'tel') || str_contains($lower, 'oil') || str_contains($lower, 'tel')) {
    $searchTerms[] = 'oil';
    $searchTerms[] = 'ghee';
}
if (str_contains($lower, 'dal') || str_contains($lower, 'moong') || str_contains($lower, 'chana')) {
    $searchTerms[] = 'moong';
    $searchTerms[] = 'chana';
    $searchTerms[] = 'dal';
}
if (str_contains($lower, 'chawal') || str_contains($lower, 'rice')) {
    $searchTerms[] = 'rice';
}
if (str_contains($lower, 'suji') || str_contains($lower, 'sooji')) {
    $searchTerms[] = 'suji';
}
if (str_contains($lower, 'doodh') || str_contains($lower, 'milk')) {
    $searchTerms[] = 'milk';
    $searchTerms[] = 'taaza';
}
if (str_contains($lower, 'paneer')) {
    $searchTerms[] = 'paneer';
}
if (str_contains($lower, 'dahi') || str_contains($lower, 'curd')) {
    $searchTerms[] = 'dahi';
    $searchTerms[] = 'masti';
}
if (str_contains($lower, 'butter') || str_contains($lower, 'makkhan')) {
    $searchTerms[] = 'butter';
}
if (str_contains($lower, 'chai') || str_contains($lower, 'tea')) {
    $searchTerms[] = 'tea';
    $searchTerms[] = 'coffee';
}
if (str_contains($lower, 'bulb') || str_contains($lower, 'light') || str_contains($lower, 'led')) {
    $searchTerms[] = 'bulb';
    $searchTerms[] = 'led';
}
if (str_contains($lower, 'biscuit') || str_contains($lower, 'cookie')) {
    $searchTerms[] = 'biscuit';
    $searchTerms[] = 'cookies';
}
if (str_contains($lower, 'sugar') || str_contains($lower, 'cheeni') || str_contains($lower, 'shakar')) {
    $searchTerms[] = 'sugar';
}

// Fallback search term if no synonym matched
if (empty($searchTerms)) {
    $searchTerms[] = $lower;
}

// Build SQL search conditions
$conditions = [];
foreach ($searchTerms as $term) {
    $term = mysqli_real_escape_string($conn, $term);
    $conditions[] = "p.name LIKE '%$term%'";
    $conditions[] = "p.name_hi LIKE '%$term%'";
    $conditions[] = "p.name_hn LIKE '%$term%'";
    $conditions[] = "p.description LIKE '%$term%'";
}

$whereSql = "WHERE " . implode(" OR ", $conditions);

$name_col = "p.name";
$desc_col = "p.description";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
}

$sql = "
    SELECT 
        p.id AS product_id,
        $name_col AS name,
        p.name_hi,
        p.name_hn,
        $desc_col AS description,
        p.description_hi,
        p.description_hn,
        p.main_category_id,
        p.types
    FROM products p
    $whereSql
    LIMIT 10
";

$res = $conn->query($sql);

if (!$res) {
    echo json_encode([
        'success' => false,
        'message' => $conn->error
    ]);
    exit;
}

$products = [];

while ($product = $res->fetch_assoc()) {
    $product_id = $product['product_id'];

    // Fetch variants
    $variants = [];
    $var_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $var_select = "id, product_id, name_hi, name_hn, price, selling_price, wholesale_price, stock, COALESCE(NULLIF(name_$lang, ''), name) AS name";
    }
    $resVar = $conn->query("SELECT $var_select FROM product_variants WHERE product_id = $product_id");
    while ($row = $resVar->fetch_assoc()) {
        $variants[] = $row;
    }

    // Fetch images
    $images = [];
    $resImg = $conn->query("SELECT image_url FROM product_images WHERE product_id = $product_id");
    while ($row = $resImg->fetch_assoc()) {
        $img = $row['image_url'];
        // If image_url starts with uploads/, prefix with Base URL
        if (!empty($img) && !str_starts_with($img, 'http')) {
            $img = "http://192.168.31.213/dxmart_api/product_api_project/" . $img;
        }
        $images[] = $img;
    }

    $products[] = [
        'id' => $product_id,
        'name' => $product['name'],
        'name_hi' => $product['name_hi'] ?? '',
        'name_hn' => $product['name_hn'] ?? '',
        'description' => $product['description'],
        'description_hi' => $product['description_hi'] ?? '',
        'description_hn' => $product['description_hn'] ?? '',
        'main_category_id' => $product['main_category_id'],
        'types' => $product['types'],
        'variants' => $variants,
        'images' => $images
    ];
}

echo json_encode([
    'success' => true,
    'products' => $products,
    'count' => count($products)
]);
?>
