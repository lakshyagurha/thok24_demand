<?php
include '../../connection.php';
header('Content-Type: application/json');

// Read POST data
$id = $_POST['id'] ?? null;
$number = $_POST['number'] ?? null;

// Validate input
if (!$id || !$number) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing ID or call value'
    ]);
    exit;
}

// Prepare and run update query
$sql = "UPDATE help_whatsapp SET whatsapp_no = ? WHERE id = ?";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "si", $number, $id);

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        'success' => true,
        'message' => 'Whatsapp Number updated successfully'
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to update Calling number'
    ]);
}
?>
