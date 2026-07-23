<?php
include '../connection.php';
header("Content-Type: application/json");

// ================== INPUT ==================
$user_id = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
$page  = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
$lang  = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

if ($user_id <= 0) {
    echo json_encode([
        "success" => false,
        "message" => "User ID required"
    ]);
    exit;
}

$page  = $page > 0 ? $page : 1;
$limit = $limit > 0 ? $limit : 10;
$offset = ($page - 1) * $limit;

// ================== TOTAL COUNT ==================
$countSql = "
    SELECT COUNT(*) AS total
    FROM wishlist w
    INNER JOIN products p ON w.product_id = p.id
    WHERE w.user_id = $user_id
";

$countRes = $conn->query($countSql);
$total = $countRes ? (int)$countRes->fetch_assoc()['total'] : 0;

// ================== FETCH WISHLIST PRODUCTS ==================
$name_col = "p.name";
$desc_col = "p.description";
$cat_col = "mc.name";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
    $cat_col = "COALESCE(NULLIF(mc.name_$lang, ''), mc.name)";
}

$sql = "
    SELECT
        w.id AS wishlist_id,
        p.id AS product_id,
        $name_col AS name,
        p.name_hi,
        p.name_hn,
        $desc_col AS description,
        p.description_hi,
        p.description_hn,
        p.types,
        p.main_category_id,
        $cat_col AS main_category_name
    FROM wishlist w
    INNER JOIN products p ON w.product_id = p.id
    LEFT JOIN main_category mc ON p.main_category_id = mc.id
    WHERE w.user_id = $user_id
    ORDER BY w.id DESC
    LIMIT $limit OFFSET $offset
";

$result = $conn->query($sql);

if (!$result) {
    echo json_encode([
        "success" => false,
        "message" => $conn->error
    ]);
    exit;
}

$products = [];

while ($product = $result->fetch_assoc()) {

    $product_id = (int)$product['product_id'];

    // ================== VARIANTS ==================
    $variants = [];
    $var_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $var_select = "id, product_id, name_hi, name_hn, price, selling_price, wholesale_price, stock, COALESCE(NULLIF(name_$lang, ''), name) AS name";
    }
    $resVar = $conn->query("SELECT $var_select FROM product_variants WHERE product_id = $product_id");
    while ($row = $resVar->fetch_assoc()) {
        $variants[] = $row;
    }

    // ================== INFO ==================
    $info = [];
    $info_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $info_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $resInfo = $conn->query("
        SELECT $info_select 
        FROM product_info 
        WHERE product_id = $product_id
    ");
    while ($row = $resInfo->fetch_assoc()) {
        $info[] = $row;
    }

    // ================== HIGHLIGHTS ==================
    $highlights = [];
    $high_select = "*";
    if ($lang === 'hi' || $lang === 'hn') {
        $high_select = "id, product_id, attribute_hi, attribute_hn, value_hi, value_hn, COALESCE(NULLIF(attribute_$lang, ''), attribute) AS attribute, COALESCE(NULLIF(value_$lang, ''), value) AS value";
    }
    $resHigh = $conn->query("
        SELECT $high_select 
        FROM product_highlights 
        WHERE product_id = $product_id
    ");
    while ($row = $resHigh->fetch_assoc()) {
        $highlights[] = $row;
    }

    // ================== IMAGES ==================
    $images = [];
    $resImg = $conn->query("
        SELECT image_url 
        FROM product_images 
        WHERE product_id = $product_id
    ");
    while ($row = $resImg->fetch_assoc()) {
        $images[] = $row['image_url'];
    }

    // ================== FINAL FORMAT (SAME AS PRODUCTS API) ==================
    $products[] = [
        'wishlist_id'        => (int)$product['wishlist_id'],
        'id'                 => $product_id,
        'name'               => $product['name'],
        'name_hi'            => $product['name_hi'] ?? '',
        'name_hn'            => $product['name_hn'] ?? '',
        'description'        => $product['description'],
        'description_hi'     => $product['description_hi'] ?? '',
        'description_hn'     => $product['description_hn'] ?? '',
        'type'               => $product['types'],
        'main_category_id'   => $product['main_category_id'],
        'main_category_name' => $product['main_category_name'],
        'variants'           => $variants,
        'info'               => $info,
        'highlights'         => $highlights,
        'images'             => $images
    ];
}

// ================== RESPONSE ==================
echo json_encode([
    "success"  => true,
    "total"    => $total,
    "page"     => $page,
    "limit"    => $limit,
    "products" => $products
]);

$conn->close();
?>
