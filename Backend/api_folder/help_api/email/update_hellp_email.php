<?php
include '../../connection.php';
header('Content-Type: application/json');

// Read POST data
$id = $_POST['id'] ?? null;
$email = $_POST['email'] ?? null;

// Validate input
if (!$id || !$email) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing ID or call value'
    ]);
    exit;
}

// Prepare and run update query
$sql = "UPDATE help_email SET email = ? WHERE id = ?";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "si", $email, $id);

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        'success' => true,
        'message' => 'Email updated successfully'
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update Calling number'
    ]);
}
?>
