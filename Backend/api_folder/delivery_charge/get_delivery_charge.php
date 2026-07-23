<?php
include '../connection.php'; // your DB connection

header('Content-Type: application/json');

// Fetch single delivery time (e.g., id = 1)
$sql = "SELECT * FROM delivery_charge LIMIT 1";
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
