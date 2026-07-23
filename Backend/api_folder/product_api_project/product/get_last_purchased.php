<?php
include '../../connection.php';
header('Content-Type: application/json');

$user_id = isset($_REQUEST['user_id']) ? (int)$_REQUEST['user_id'] : 0;
$lang = isset($_REQUEST['lang']) ? trim($_REQUEST['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

if (!$user_id) {
    echo json_encode([
        "success" => false,
        "message" => "User ID missing or invalid"
    ]);
    exit;
}

$name_col = "p.name";
$desc_col = "p.description";
$var_col = "pv.name";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
    $var_col = "COALESCE(NULLIF(pv.name_$lang, ''), pv.name)";
}

// Fetch last 5 unique purchased items
$sql = "
    SELECT 
        p.id AS id,
        $name_col AS name,
        $desc_col AS description,
        p.main_category_id,
        pv.id AS variant_id,
        $var_col AS variant_name,
        pv.price AS price,
        pv.selling_price AS selling_price,
        pv.stock AS stock,
        oi.image_url AS image_url
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    JOIN products p ON oi.product_id = p.id
    LEFT JOIN product_variants pv ON oi.variant_id = pv.id
    WHERE o.user_id = ?
    GROUP BY p.id, pv.id
    ORDER BY o.id DESC
    LIMIT 5
";

$stmt = $conn->prepare($sql);
if (!$stmt) {
    echo json_encode([
        "success" => false,
        "message" => "Prepare statement failed: " . $conn->error
    ]);
    exit;
}

$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

$products = [];
while ($row = $result->fetch_assoc()) {
    // Process absolute image URL if needed
    $image_url = $row['image_url'];
    if (empty($image_url)) {
        // Fallback to check product_images table
        $p_id = $row['id'];
        $img_res = $conn->query("SELECT image_url FROM product_images WHERE product_id = $p_id LIMIT 1");
        if ($img_res && $img_row = $img_res->fetch_assoc()) {
            $image_url = $img_row['image_url'];
        }
    }
    
    // If image_url starts with uploads/, prefix with Base URL
    if (!empty($image_url) && !str_starts_with($image_url, 'http')) {
        $image_url = "http://192.168.31.213/dxmart_api/product_api_project/" . $image_url;
    }

    $products[] = [
        'id' => $row['id'],
        'name' => $row['name'],
        'description' => $row['description'],
        'main_category_id' => $row['main_category_id'],
        'variant_id' => $row['variant_id'],
        'variant_name' => $row['variant_name'],
        'price' => $row['price'],
        'selling_price' => $row['selling_price'],
        'stock' => $row['stock'],
        'image' => $image_url
    ];
}

$stmt->close();

echo json_encode([
    "success" => true,
    "products" => $products
]);
?>
