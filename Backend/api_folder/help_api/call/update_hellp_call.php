<?php
include '../../connection.php';
header('Content-Type: application/json');

// Read POST data
$id = $_POST['id'] ?? null;
$call = $_POST['call'] ?? null;

// Validate input
if (!$id || !$call) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing ID or call value'
    ]);
    exit;
}

// Prepare and run update query
$sql = "UPDATE help_call SET call_help = ? WHERE id = ?";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "si", $call, $id);

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        'success' => true,
        'message' => 'Calling Number updated successfully'
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update Calling number'
    ]);
}
?>
