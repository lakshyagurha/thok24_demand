<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

include '../../connection.php';

$query = "SELECT * FROM district";
$exe = mysqli_query($conn, $query);

$districts = [];

while ($row = mysqli_fetch_assoc($exe)) {
    $districts[] = $row;
}

echo json_encode([
    "success" => true,
    "districts" => $districts
]);
?>
