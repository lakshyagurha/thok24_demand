<?php
include '../../connection.php';
header('Content-Type: application/json');

$subcategory_id = isset($_GET['subcategory_id']) ? intval($_GET['subcategory_id']) : 0;
$lang = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

if ($subcategory_id == 0) {
    echo json_encode(['success' => false, 'message' => 'subcategory_id required']);
    exit;
}

$name_col = "p.name";
$desc_col = "p.description";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
}

$sql = "SELECT 
            p.id AS product_id,
            $name_col AS name,
            p.name_hi,
            p.name_hn,
            $desc_col AS description,
            p.description_hi,
            p.description_hn,
            p.category_id,
            p.subcategory_id,
            p.brand_id,
            c.category_name,
            sc.sub_category_name,
            b.brand_name,
            b.brand_image
        FROM products p
        LEFT JOIN category c ON p.category_id = c.category_id
        LEFT JOIN sub_category sc ON p.subcategory_id = sc.id
        LEFT JOIN brand b ON p.brand_id = b.id
        WHERE p.subcategory_id = $subcategory_id
        ORDER BY p.id DESC";

$res = mysqli_query($conn, $sql);

$products = [];

while ($product = mysqli_fetch_assoc($res)) {
    $product_id = $product['product_id'];

    // Variants
    $variants = [];
    $var_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $var_select = "id, product_id, name_hi, name_hn, price, selling_price, wholesale_price, stock, COALESCE(NULLIF(name_$lang, ''), name) AS name";
    }
    $vRes = mysqli_query($conn, "SELECT $var_select FROM product_variants WHERE product_id = $product_id");
    while ($v = mysqli_fetch_assoc($vRes)) {
        $variants[] = $v;
    }

    // Info
    $info = [];
    $info_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $info_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $iRes = mysqli_query($conn, "SELECT $info_select FROM product_info WHERE product_id = $product_id");
    while ($i = mysqli_fetch_assoc($iRes)) {
        $info[] = $i;
    }

    // Highlights
    $highlights = [];
    $high_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $high_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $hRes = mysqli_query($conn, "SELECT $high_select FROM product_highlights WHERE product_id = $product_id");
    while ($h = mysqli_fetch_assoc($hRes)) {
        $highlights[] = $h;
    }

    // Images
    $images = [];
    $imgRes = mysqli_query($conn, "SELECT image_url FROM product_images WHERE product_id = $product_id");
    while ($img = mysqli_fetch_assoc($imgRes)) {
        $images[] = $img['image_url'];
    }

    $products[] = [
        'id' => $product_id,
        'name' => $product['name'],
        'name_hi' => $product['name_hi'] ?? '',
        'name_hn' => $product['name_hn'] ?? '',
        'description' => $product['description'],
        'description_hi' => $product['description_hi'] ?? '',
        'description_hn' => $product['description_hn'] ?? '',
        'category' => $product['category_name'],
        'subcategory' => $product['sub_category_name'],
        'category_id' => $product['category_id'],
        'subcategory_id' => $product['subcategory_id'],
        'brand_id' => $product['brand_id'],
        'brand_name' => $product['brand_name'],
        'brand_image' => $product['brand_image'],
        'variants' => $variants,
        'info' => $info,
        'highlights' => $highlights,
        'images' => $images
    ];
}

echo json_encode(['success' => true, 'products' => $products]);
?>
