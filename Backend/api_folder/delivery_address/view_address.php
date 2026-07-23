<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");

include '../connection.php';

$user_id = isset($_POST['user_id']) ? mysqli_real_escape_string($conn, $_POST['user_id']) : '';

if ($user_id != '') {
    $query = "SELECT * FROM delivery_address WHERE user_id = '$user_id'";
    $exe = mysqli_query($conn, $query);

    $arr = [];
    while ($row = mysqli_fetch_assoc($exe)) {
        $arr[] = $row;
    }

    echo json_encode([
        "status" => "success",
        "data" => $arr
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "User ID not provided"
    ]);
}
?>
