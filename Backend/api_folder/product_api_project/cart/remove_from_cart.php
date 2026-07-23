<?php
include '../../connection.php';
header('Content-Type: application/json');

$id = $_GET['id'] ?? '';

$stmt = $conn->prepare("DELETE FROM cart_items WHERE id = ?");
$stmt->bind_param("i", $id);
$stmt->execute();

echo json_encode(["success" => true, "message" => "Removed from cart"]);
