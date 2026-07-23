<?php
include '../connection.php';

header('Content-Type: application/json');

// Prepare query
$sql = "SELECT * FROM coupon ORDER BY id DESC";
$result = mysqli_query($conn, $sql);

// Prepare response
$response = [];

if ($result && mysqli_num_rows($result) > 0) {
    while ($row = mysqli_fetch_assoc($result)) {
        $response[] = $row;
    }

    echo json_encode([
        "success" => true,
        "data" => $response
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "No coupons found."
    ]);
}
?>
