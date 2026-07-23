<?php
include '../../connection.php';
header('Content-Type: application/json');

$data = json_decode(file_get_contents("php://input"), true);

$id = $data['id'] ?? '';
$quantity = $data['quantity'] ?? 1;

$stmt = $conn->prepare("UPDATE cart_items SET quantity = ? WHERE id = ?");
$stmt->bind_param("ii", $quantity, $id);
$stmt->execute();

echo json_encode(["success" => true, "message" => "Quantity updated"]);
