<?php
include '../connection.php';
header("Content-Type: application/json");

$data = json_decode(file_get_contents("php://input"), true);

$user_id    = isset($data['user_id']) ? (int)$data['user_id'] : 0;
$product_id = isset($data['product_id']) ? (int)$data['product_id'] : 0;

if (!$user_id || !$product_id) {
    echo json_encode(["success" => false, "message" => "Missing parameters"]);
    exit;
}

$stmt = $conn->prepare("DELETE FROM wishlist WHERE user_id = ? AND product_id = ?");
$stmt->bind_param("ii", $user_id, $product_id);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "Removed from wishlist"]);
} else {
    echo json_encode(["success" => false, "message" => "Failed to remove"]);
}
$stmt->close();
$conn->close();
