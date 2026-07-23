<?php
include '../../connection.php';
header('Content-Type: application/json');

$user_id = isset($_POST['user_id']) ? (int)$_POST['user_id'] : 0;
$lang = isset($_REQUEST['lang']) ? trim($_REQUEST['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

if (!$user_id) {
    echo json_encode(["success" => false, "message" => "User ID missing"]);
    exit;
}

$name_col = "p.name";
$var_col = "pv.name";
if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $var_col = "COALESCE(NULLIF(pv.name_$lang, ''), pv.name)";
}

// 1. Order info + location details
$order_stmt = $conn->prepare("
    SELECT 
        o.*, 
        da.name AS address_name,
        da.phone AS address_phone,
        da.full_address,
        da.pin_code,
        da.landmark
    FROM orders o
    LEFT JOIN delivery_address da ON o.location_id = da.id
    WHERE o.user_id = ?
    ORDER BY o.id DESC
");
$order_stmt->bind_param("i", $user_id);
$order_stmt->execute();
$order_result = $order_stmt->get_result();

if ($order_result->num_rows == 0) {
    echo json_encode(["success" => false, "message" => "No orders found"]);
    exit;
}

$orders = [];
while ($order_data = $order_result->fetch_assoc()) {
    
    // 2. Order items fetch
    $items_stmt = $conn->prepare("
        SELECT 
            oi.id AS order_item_id,
            oi.product_id,
            $name_col AS product_name,
            oi.variant_id,
            $var_col AS variant_name,
            pv.price,
            pv.selling_price,
            pv.stock,
            oi.quantity,
            oi.image_url
        FROM order_items oi
        JOIN products p ON oi.product_id = p.id
        LEFT JOIN product_variants pv ON oi.variant_id = pv.id
        WHERE oi.order_id = ?
    ");
    $items_stmt->bind_param("i", $order_data['id']);
    $items_stmt->execute();
    $items_result = $items_stmt->get_result();
    
    $order_items = [];
    while ($row = $items_result->fetch_assoc()) {
        $order_items[] = $row;
    }
    $items_stmt->close();

    // Merge all data
    $orders[] = [
        "order" => $order_data,
        "items" => $order_items
    ];
}
$order_stmt->close();

// Final Response
echo json_encode([
    "success" => true,
    "orders" => $orders
]);
?>
