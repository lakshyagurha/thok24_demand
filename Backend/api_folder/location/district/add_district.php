<?php
include '../../connection.php';

header('Content-Type: application/json'); // Always set this

if (!isset($_POST['district_name'])) {
    echo json_encode(["success" => false, "message" => "Missing district_name"]);
    return;
}

$district_name = $_POST['district_name'];
$query = "INSERT INTO district(district_name) VALUES ('$district_name')";
$exe = mysqli_query($conn, $query);

if ($exe) {
    $arr["success"] = true; // return boolean true
    $arr["message"] = "District added successfully";
} else {
    $arr["success"] = false;
    $arr["message"] = "Failed to insert into database";
}

echo json_encode($arr);
?>
