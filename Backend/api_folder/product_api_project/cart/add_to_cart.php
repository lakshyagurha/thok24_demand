<?php
include '../../connection.php';
header('Content-Type: application/json');

$data = json_decode(file_get_contents("php://input"), true);

$user_id    = isset($data['user_id']) ? (int)$data['user_id'] : 0;
$product_id = isset($data['product_id']) ? (int)$data['product_id'] : 0;
$variant_id = isset($data['variant_id']) ? $data['variant_id'] : null;
$quantity   = isset($data['quantity']) && $data['quantity'] > 0 ? (int)$data['quantity'] : 1;
$image_url = isset($data['image_url']) ? $data['image_url'] : null;

if (!$user_id || !$product_id) {
    echo json_encode(["success" => false, "message" => "Missing data"]);
    exit;
}

if ($variant_id === null) {
    $stmt = $conn->prepare("SELECT id, quantity FROM cart_items WHERE user_id = ? AND product_id = ? AND variant_id IS NULL");
    $stmt->bind_param("ii", $user_id, $product_id);
} else {
    $stmt = $conn->prepare("SELECT id, quantity FROM cart_items WHERE user_id = ? AND product_id = ? AND variant_id = ?");
    $stmt->bind_param("iii", $user_id, $product_id, $variant_id);
}
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    $newQty = $row['quantity'] + $quantity;
    $upd = $conn->prepare("UPDATE cart_items SET quantity = ? WHERE id = ?");
    $upd->bind_param("ii", $newQty, $row['id']);
    $upd->execute();
    $upd->close();
} else {
    if ($variant_id === null) {
        $ins = $conn->prepare("INSERT INTO cart_items (user_id, product_id, variant_id, quantity, image_url) VALUES (?, ?, NULL, ?, ?)");
        $ins->bind_param("iiis", $user_id, $product_id, $quantity,$image_url);
    } else {
        $ins = $conn->prepare("INSERT INTO cart_items (user_id, product_id, variant_id, quantity, image_url) VALUES (?, ?, ?, ?,?)");
        $ins->bind_param("iiiis", $user_id, $product_id, $variant_id, $quantity, $image_url);
    }
    $ins->execute();
    $ins->close();
}

echo json_encode(["success" => true, "message" => "Cart updated"]);
