<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

include '../../connection.php';

if (!isset($_POST['district_id'])) {
    echo json_encode([
        "success" => false,
        "message" => "district_id is required"
    ]);
    exit;
}

$district_id = $_POST['district_id'];

$query = "SELECT * FROM city WHERE district_id = '$district_id'";
$exe = mysqli_query($conn, $query);

$cities = [];

while ($row = mysqli_fetch_assoc($exe)) {
    $cities[] = $row;
}

echo json_encode([
    "success" => true,
    "cities" => $cities
]);
?>
