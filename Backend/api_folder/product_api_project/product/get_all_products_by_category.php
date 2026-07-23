<?php
include '../../connection.php';
header('Content-Type: application/json');

// ================= INPUT =================
$category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : 0;
$lang = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

if ($category_id == 0) {
    echo json_encode([
        'success' => false,
        'message' => 'category_id required'
    ]);
    exit;
}

// ================= MAIN PRODUCT QUERY =================
$name_col = "p.name";
$desc_col = "p.description";
$cat_col = "c.name";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
    $cat_col = "COALESCE(NULLIF(c.name_$lang, ''), c.name)";
}

$sql = "SELECT 
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
        WHERE p.main_category_id = $category_id
        ORDER BY p.id DESC";

$res = mysqli_query($conn, $sql);

if (!$res) {
    echo json_encode([
        'success' => false,
        'message' => 'Query failed: ' . mysqli_error($conn)
    ]);
    exit;
}

$products = [];

// ================= LOOP PRODUCTS =================
while ($product = mysqli_fetch_assoc($res)) {

    $product_id = $product['product_id'];

    // ---------- VARIANTS ----------
    $variants = [];
    $var_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $var_select = "id, product_id, name_hi, name_hn, price, selling_price, wholesale_price, stock, COALESCE(NULLIF(name_$lang, ''), name) AS name";
    }
    $vRes = mysqli_query($conn, "SELECT $var_select FROM product_variants WHERE product_id = $product_id");
    while ($v = mysqli_fetch_assoc($vRes)) {
        $variants[] = $v;
    }

    // ---------- INFO ----------
    $info = [];
    $info_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $info_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $iRes = mysqli_query($conn, "SELECT $info_select FROM product_info WHERE product_id = $product_id");
    while ($i = mysqli_fetch_assoc($iRes)) {
        $info[] = $i;
    }

    // ---------- HIGHLIGHTS ----------
    $highlights = [];
    $high_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $high_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $hRes = mysqli_query($conn, "SELECT $high_select FROM product_highlights WHERE product_id = $product_id");
    while ($h = mysqli_fetch_assoc($hRes)) {
        $highlights[] = $h;
    }

    // ---------- IMAGES ----------
    $images = [];
    $imgRes = mysqli_query($conn, "SELECT image_url FROM product_images WHERE product_id = $product_id");
    while ($img = mysqli_fetch_assoc($imgRes)) {
        $images[] = $img['image_url'];
    }

    // ---------- FINAL PRODUCT ----------
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

// ================= RESPONSE =================
echo json_encode([
    'success' => true,
    'count' => count($products),
    'products' => $products
]);
?>
