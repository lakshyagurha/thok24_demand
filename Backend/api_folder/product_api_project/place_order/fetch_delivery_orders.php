<?php
// get_delivery_boy_orders.php
include '../../connection.php';
header('Content-Type: application/json');

// Get delivery boy ID from request
$delivery_boy_id = isset($_GET['delivery_boy_id']) ? (int)$_GET['delivery_boy_id'] : 0;

if ($delivery_boy_id < 1) {
    echo json_encode(["success" => false, "message" => "Invalid delivery boy ID"]);
    exit;
}

// Get pagination parameters
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
$offset = ($page - 1) * $limit;

// Validate parameters
if ($page < 1) $page = 1;
if ($limit < 1) $limit = 10;

// Get total count of orders assigned to this delivery boy
$count_stmt = $conn->prepare("
    SELECT COUNT(*) as total 
    FROM order_assignment oa
    JOIN orders o ON oa.order_id = o.id
    WHERE oa.delivery_boy_id = ?
");
$count_stmt->bind_param("i", $delivery_boy_id);
$count_stmt->execute();
$count_result = $count_stmt->get_result();
$total_data = $count_result->fetch_assoc();
$total_orders = $total_data['total'];
$total_pages = ceil($total_orders / $limit);

// Fetch orders assigned to this delivery boy with pagination
$order_stmt = $conn->prepare("
    SELECT 
        o.*, 
        da.name AS name,
        da.phone AS phone,
        da.full_address,
        da.pin_code,
        da.landmark,
        oa.date_time as assigned_date
    FROM order_assignment oa
    JOIN orders o ON oa.order_id = o.id
    LEFT JOIN delivery_address da ON o.location_id = da.id
    WHERE oa.delivery_boy_id = ?
    ORDER BY oa.date_time DESC
    LIMIT ? OFFSET ?
");
$order_stmt->bind_param("iii", $delivery_boy_id, $limit, $offset);
$order_stmt->execute();
$order_result = $order_stmt->get_result();

if ($order_result->num_rows == 0) {
    echo json_encode([
        "success" => false, 
        "message" => "No orders found for this delivery boy",
        "pagination" => [
            "current_page" => $page,
            "total_pages" => $total_pages,
            "total_orders" => $total_orders,
            "has_next" => $page < $total_pages,
            "has_prev" => $page > 1
        ]
    ]);
    exit;
}

$orders = [];
while ($order_data = $order_result->fetch_assoc()) {
    
    // Order items fetch
    $items_stmt = $conn->prepare("
    SELECT 
        oi.id AS order_item_id,
        oi.product_id,
        p.name AS product_name,
        oi.variant_id,
        pv.*,
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

    $orders[] = [
        "order" => $order_data,
        "items" => $order_items
    ];
}
$order_stmt->close();

// Final Response
echo json_encode([
    "success" => true,
    "orders" => $orders,
    "pagination" => [
        "current_page" => $page,
        "total_pages" => $total_pages,
        "total_orders" => $total_orders,
        "has_next" => $page < $total_pages,
        "has_prev" => $page > 1,
        "limit" => $limit
    ]
]);
?>