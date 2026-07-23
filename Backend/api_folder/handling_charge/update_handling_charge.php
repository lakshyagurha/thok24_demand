<?php
include '../connection.php'; // DB connection file
header('Content-Type: application/json');

// Read POST data
$id = $_POST['id'] ?? null;
$amount = $_POST['amount'] ?? null;

// Validate input
if (!$id || !$amount) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing ID or amount value'
    ]);
    exit;
}

// Prepare and run update query
$sql = "UPDATE handling_charge SET amount = ? WHERE id = ?";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "ii", $amount, $id);

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        'success' => true,
        'message' => 'Handinling Charge  updated successfully'
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update Handinling Charge'
    ]);
}
?>
