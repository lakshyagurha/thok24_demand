<?php
include '../../connection.php';
header('Content-Type: application/json');

$variant_id = $_POST['variant_id'] ?? '';
$stock = $_POST['stock'] ?? '';

if (!$variant_id || $stock === '') {
    echo json_encode(['success' => false, 'message' => 'Invalid input']);
    exit;
}

$variant_id = intval($variant_id);
$stock = intval($stock);

$sql = "UPDATE product_variants SET stock = $stock WHERE id = $variant_id";
if ($conn->query($sql)) {
    echo json_encode(['success' => true, 'message' => 'Stock updated successfully']);
} else {
    echo json_encode(['success' => false, 'message' => 'Update failed: ' . $conn->error]);
}
?>
