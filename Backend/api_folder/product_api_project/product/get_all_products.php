<?php
include '../../connection.php';
header('Content-Type: application/json');

// ================= PAGINATION & SEARCH =================
$page  = isset($_GET['page']) ? intval($_GET['page']) : 1;
$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 10;
$search = isset($_GET['search']) ? trim($_GET['search']) : '';
$category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : null;
$lang = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

$offset = ($page - 1) * $limit;
$search = mysqli_real_escape_string($conn, $search);

// ================= WHERE CONDITION =================
$where = [];

if ($search !== '') {
    $where[] = "(p.name LIKE '%$search%' OR p.name_hi LIKE '%$search%' OR p.name_hn LIKE '%$search%' OR p.description LIKE '%$search%')";
}

if ($category_id !== null && $category_id > 0) {
    $where[] = "p.main_category_id = $category_id";
}

$whereSql = count($where) ? "WHERE " . implode(" AND ", $where) : "";

// ================= TOTAL COUNT =================
$countSql = "SELECT COUNT(*) AS total FROM products p $whereSql";
$countRes = $conn->query($countSql);
$total = $countRes->fetch_assoc()['total'] ?? 0;

// ================= PRODUCT LIST WITH CATEGORY =================
$name_col = "p.name";
$desc_col = "p.description";
$cat_col = "c.name";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
    $cat_col = "COALESCE(NULLIF(c.name_$lang, ''), c.name)";
}

$productSql = "SELECT 
                    p.id AS product_id,
                    $name_col AS name,
                    p.name_hi,
                    p.name_hn,
                    $desc_col AS description,
                    p.description_hi,
                    p.description_hn,
                    p.main_category_id,
                    $cat_col AS main_category_name,
                    p.types
               FROM products p
               LEFT JOIN main_category c ON p.main_category_id = c.id
               $whereSql
               ORDER BY p.id DESC
               LIMIT $limit OFFSET $offset";

$productRes = $conn->query($productSql);

if (!$productRes) {
    echo json_encode([
        'success' => false,
        'message' => $conn->error
    ]);
    exit;
}

$products = [];

while ($product = $productRes->fetch_assoc()) {

    $product_id = $product['product_id'];

    // ================= VARIANTS =================
    $variants = [];
    $var_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $var_select = "id, product_id, name_hi, name_hn, price, selling_price, wholesale_price, stock, COALESCE(NULLIF(name_$lang, ''), name) AS name";
    }
    $resVar = $conn->query("SELECT $var_select FROM product_variants WHERE product_id = $product_id");
    while ($row = $resVar->fetch_assoc()) {
        $variants[] = $row;
    }

    // ================= INFO =================
    $info = [];
    $info_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $info_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $resInfo = $conn->query("SELECT $info_select FROM product_info WHERE product_id = $product_id");
    while ($row = $resInfo->fetch_assoc()) {
        $info[] = $row;
    }

    // ================= HIGHLIGHTS =================
    $highlights = [];
    $high_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $high_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $resHigh = $conn->query("SELECT $high_select FROM product_highlights WHERE product_id = $product_id");
    while ($row = $resHigh->fetch_assoc()) {
        $highlights[] = $row;
    }

    // ================= IMAGES =================
    $images = [];
    $resImg = $conn->query("SELECT image_url FROM product_images WHERE product_id = $product_id");
    while ($row = $resImg->fetch_assoc()) {
        $images[] = $row['image_url'];
    }

    // ================= FINAL PRODUCT =================
    $products[] = [
        'id' => $product_id,
        'name' => $product['name'],
        'name_hi' => $product['name_hi'] ?? '',
        'name_hn' => $product['name_hn'] ?? '',
        'description' => $product['description'],
        'description_hi' => $product['description_hi'] ?? '',
        'description_hn' => $product['description_hn'] ?? '',
        'main_category_id' => $product['main_category_id'],
        'main_category_name' => $product['main_category_name'],
        'types' => $product['types'],
        'variants' => $variants,
        'info' => $info,
        'highlights' => $highlights,
        'images' => $images
    ];
}

// ================= TOTAL PAGES =================
$totalPages = $limit > 0 ? ceil($total / $limit) : 1;

// ================= RESPONSE =================
echo json_encode([
    'success' => true,
    'products' => $products,
    'total' => $total,
    'count' => count($products),
    'page' => $page,
    'limit' => $limit,
    'totalPages' => $totalPages
]);
?>