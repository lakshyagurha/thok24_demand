<?php
include '../connection.php'; // DB connection file
header('Content-Type: application/json');

// Read POST data
$id = $_POST['id'] ?? null;
$time = $_POST['time'] ?? null;

// Validate input
if (!$id || !$time) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing ID or time value'
    ]);
    exit;
}

// Prepare and run update query
$sql = "UPDATE deliver_time SET time = ? WHERE id = ?";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "si", $time, $id);

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        'success' => true,
        'message' => 'Delivery time updated successfully'
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update delivery time'
    ]);
}
?>
