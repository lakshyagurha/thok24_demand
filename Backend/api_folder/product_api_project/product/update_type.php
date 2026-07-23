<?php

include '../../connection.php';


$id = $_POST['id'] ?? '';
$type = $_POST['type'] ?? '';

// Debug line: check input
file_put_contents('log.txt', "ID: $id | Type: $type\n", FILE_APPEND);

$sql = "UPDATE products SET types = '$type' WHERE id = $id";

// Debug line: log SQL error if any
if (mysqli_query($conn, $sql)) {
    echo json_encode(['status' => 'success']);
} else {
    file_put_contents('log.txt', "MySQL Error: " . mysqli_error($conn) . "\n", FILE_APPEND);
    echo json_encode(['status' => 'error']);
}
?>
