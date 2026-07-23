<?php
include '../connection.php';
header("Content-Type: application/json");

$user_id    = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
$product_id = isset($_GET['product_id']) ? (int)$_GET['product_id'] : 0;

if (!$user_id || !$product_id) {
    echo json_encode(["success" => false, "message" => "Missing parameters"]);
    exit;
}

$stmt = $conn->prepare("SELECT id FROM wishlist WHERE user_id = ? AND product_id = ?");
$stmt->bind_param("ii", $user_id, $product_id);
$stmt->execute();
$stmt->store_result();

if ($stmt->num_rows > 0) {
    echo json_encode(["success" => true, "is_wishlisted" => true]);
} else {
    echo json_encode(["success" => true, "is_wishlisted" => false]);
}
$stmt->close();
$conn->close();
