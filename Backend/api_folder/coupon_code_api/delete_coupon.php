<?php
include '../connection.php';

header('Content-Type: application/json');

// Get ID from POST
$id = $_POST['id'] ?? null;

if ($id === null) {
    echo json_encode([
        "success" => false,
        "message" => "Coupon ID is required."
    ]);
    exit;
}

// Prepare and execute the delete statement
$stmt = $conn->prepare("DELETE FROM coupon WHERE id = ?");
$stmt->bind_param("i", $id);

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "Coupon deleted successfully."
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "Failed to delete coupon."
    ]);
}
?>
