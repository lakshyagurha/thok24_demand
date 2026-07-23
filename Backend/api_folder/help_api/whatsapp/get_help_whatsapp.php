<?php

include '../../connection.php';

header('Content-Type: application/json');

// Fetch single help whatsapp (e.g., id = 1)
$sql = "SELECT * FROM help_whatsapp LIMIT 1";
$result = mysqli_query($conn, $sql);

if ($result && mysqli_num_rows($result) > 0) {
    $row = mysqli_fetch_assoc($result);
    echo json_encode([
        'success' => true,
        'data' => $row
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'No data found'
    ]);
}
?>
