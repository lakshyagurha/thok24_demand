<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

include '../../connection.php';

$response = ["success" => false, "message" => "Unknown error"];

if (isset($_POST['district_id'])) {
    $district_id = $_POST['district_id'];

    // First delete all cities under this district (if needed)
    // $deleteCities = mysqli_query($conn, "DELETE FROM city WHERE district_id = '$district_id'");

    // Now delete the district
    $deleteDistrict = mysqli_query($conn, "DELETE FROM district WHERE id = '$district_id'");

    if ($deleteDistrict) {
        $response["success"] = true; // ✅ boolean
        $response["message"] = "District deleted successfully";
    } else {
        $response["message"] = "Failed to delete district";
    }
} else {
    $response["message"] = "District ID not provided";
}

echo json_encode($response);
?>
