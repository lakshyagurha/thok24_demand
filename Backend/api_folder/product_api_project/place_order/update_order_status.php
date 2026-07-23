<?php
include '../../connection.php';
header('Content-Type: application/json');

$order_id = isset($_POST['order_id']) ? (int)$_POST['order_id'] : 0;
$new_status   = isset($_POST['status']) ? strtolower($_POST['status']) : '';

if (!$order_id || !$new_status) {
    echo json_encode([
        "success" => false,
        "message" => "Missing order_id or status"
    ]);
    exit;
}

// 1. Pehle old status nikaalo
$old_stmt = $conn->prepare("SELECT status FROM orders WHERE id = ?");
$old_stmt->bind_param("i", $order_id);
$old_stmt->execute();
$old_result = $old_stmt->get_result();

if ($old_result->num_rows == 0) {
    echo json_encode([
        "success" => false,
        "message" => "Order not found"
    ]);
    exit;
}

$old_status = strtolower($old_result->fetch_assoc()['status']);
$old_stmt->close();

// 2. Agar status same hai to kuch mat karo
if ($old_status === $new_status) {
    echo json_encode([
        "success" => true,
        "message" => "Order status is already '$new_status'"
    ]);
    exit;
}

// 3. Order items nikaalo (hume stock adjust karna hai)
$oi_stmt = $conn->prepare("SELECT variant_id, quantity FROM order_items WHERE order_id = ?");
$oi_stmt->bind_param("i", $order_id);
$oi_stmt->execute();
$items = $oi_stmt->get_result();
$oi_stmt->close();

// 4. Stock adjust logic
while ($row = $items->fetch_assoc()) {
    $variant_id = $row['variant_id'];
    $quantity   = $row['quantity'];

    // Case 1: Cancelled → Stock wapas add
    if ($new_status === "cancelled" && $old_status !== "cancelled") {
        $stock_stmt = $conn->prepare("UPDATE product_variants SET stock = stock + ? WHERE id = ?");
        $stock_stmt->bind_param("ii", $quantity, $variant_id);
        $stock_stmt->execute();
        $stock_stmt->close();
    }

    // Case 2: Cancelled se nikal ke (pending/delivered) → Stock ghatana
    if ($old_status === "cancelled" && $new_status !== "cancelled") {
        $stock_stmt = $conn->prepare("UPDATE product_variants SET stock = stock - ? WHERE id = ? AND stock >= ?");
        $stock_stmt->bind_param("iii", $quantity, $variant_id, $quantity);
        $stock_stmt->execute();
        $stock_stmt->close();
    }
}

// 5. Status update karo
$update_stmt = $conn->prepare("UPDATE orders SET status = ? WHERE id = ?");
$update_stmt->bind_param("si", $new_status, $order_id);
$update_stmt->execute();
$update_stmt->close();

echo json_encode([
    "success" => true,
    "message" => "Order status updated successfully with stock adjustment"
]);

$conn->close();
?>
