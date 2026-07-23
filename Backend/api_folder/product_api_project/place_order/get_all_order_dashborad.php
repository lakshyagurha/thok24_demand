<?php
include '../../connection.php';
header('Content-Type: application/json');

// ========================
// 1. Fetch All Orders (with address & items)
// ========================
$order_stmt = $conn->prepare("
    SELECT 
        o.*, 
        DATE_FORMAT(o.order_datetime, '%Y-%m-%d %H:%i:%s') as formatted_datetime,
        da.name AS name,
        da.phone AS phone,
        da.full_address,
        da.pin_code,
        da.landmark
    FROM orders o
    LEFT JOIN delivery_address da ON o.location_id = da.id
    ORDER BY o.id DESC
");
$order_stmt->execute();
$order_result = $order_stmt->get_result();

$orders = [];
while ($order_data = $order_result->fetch_assoc()) {
    // Fetch Order Items
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

// ========================
// 2. Dashboard Summary (Today Sales + Weekly Sales)
// ========================
$today = date('Y-m-d');

// Today Sales
$today_stmt = $conn->prepare("SELECT IFNULL(SUM(final_amount), 0) as today_sales FROM orders WHERE DATE(order_datetime) = ?");
$today_stmt->bind_param("s", $today);
$today_stmt->execute();
$today_result = $today_stmt->get_result();
$today_sales = $today_result->fetch_assoc()['today_sales'] ?? 0;
$today_stmt->close();

// Weekly Sales (last 7 days)
$weekly_stmt = $conn->prepare("
    SELECT DATE(order_datetime) as sale_date, SUM(final_amount) as total_sales
    FROM orders
    WHERE order_datetime >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
    GROUP BY DATE(order_datetime)
    ORDER BY sale_date ASC
");
$weekly_stmt->execute();
$weekly_result = $weekly_stmt->get_result();

$weekly_sales = [];
while ($row = $weekly_result->fetch_assoc()) {
    $weekly_sales[] = [
        "date" => $row['sale_date'],
        "sales" => (float)$row['total_sales']
    ];
}
$weekly_stmt->close();

// ========================
// 3. Final Response
// ========================
echo json_encode([
    "success" => true,
    "orders" => $orders,
    "dashboard" => [
        "today_sales" => (float)$today_sales,
        "weekly_sales" => $weekly_sales
    ]
]);

$conn->close();
?>
