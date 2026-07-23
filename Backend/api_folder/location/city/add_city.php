<?php
include '../../connection.php';

header("Content-Type: application/json");

if (!isset($_POST['district_id']) || !isset($_POST['city_name'])) {
    echo json_encode([
        "success" => false,
        "message" => "Missing required parameters"
    ]);
    return;
}

$district_id = $_POST['district_id'];
$city_name = $_POST['city_name'];

$query = "INSERT INTO city(district_id, city_name) VALUES ('$district_id', '$city_name')";
$exe = mysqli_query($conn, $query);

if ($exe) {
    $arr["success"] = true;  // ✅ boolean
    $arr["message"] = "City added successfully";
} else {
    $arr["success"] = false; // ✅ boolean
    $arr["message"] = "Failed to insert city";
}

echo json_encode($arr);
?>
