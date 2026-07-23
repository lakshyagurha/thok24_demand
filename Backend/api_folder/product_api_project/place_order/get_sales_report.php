<?php
include '../../connection.php';
header('Content-Type: application/json');

$sql = "SELECT o.id AS order_id, o.order_datetime, o.status,
               p.id AS product_id, p.name AS product_name, p.image_url,
               v.id AS variant_id, v.name AS variant_name, v.price, v.selling_price
        FROM orders o
        JOIN order_items oi ON o.id = oi.order_id
        JOIN products p ON oi.product_id = p.id
        LEFT JOIN product_variants v ON oi.variant_id = v.id
        ORDER BY o.order_datetime DESC";

$result = $conn->query($sql);

$orders = [];
while ($row = $result->fetch_assoc()) {
    $order_id = $row['order_id'];

    if (!isset($orders[$order_id])) {
        $orders[$order_id] = [
            "order_id" => $order_id,
            "order_datetime" => $row['order_datetime'],
            "status" => $row['status'],
            "items" => []
        ];
    }

    $orders[$order_id]["items"][] = [
        "product_id" => $row['product_id'],
        "product_name" => $row['product_name'],
        "image_url" => $row['image_url'],
        "variant_id" => $row['variant_id'],
        "variant_name" => $row['variant_name'],
        "price" => $row['price'],
        "selling_price" => $row['selling_price']
    ];
}

if (!empty($orders)) {
    echo json_encode(["success" => true, "orders" => array_values($orders)]);
} else {
    echo json_encode(["success" => false, "message" => "No orders found"]);
}
?>
