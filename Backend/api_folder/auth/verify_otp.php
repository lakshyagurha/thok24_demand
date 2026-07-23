<?php
include '../connection.php';
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $otp = $_POST['otp'];

    // Check OTP validity
    $query = "SELECT * FROM otp_table WHERE email = '$email' AND otp = '$otp' AND expiry > " . time();
    $result = mysqli_query($conn, $query);

    if (mysqli_num_rows($result) > 0) {
        echo json_encode(["status" => "success", "message" => "OTP Verified"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Invalid or Expired OTP"]);
    }
}
?>
