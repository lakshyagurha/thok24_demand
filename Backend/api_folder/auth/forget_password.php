<?php
include '../connection.php';
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];

    // Check if email exists
    $check_query = "SELECT * FROM users WHERE email = '$email'";
    $check_result = mysqli_query($conn, $check_query);

    if (mysqli_num_rows($check_result) > 0) {
        $otp = rand(100000, 999999); // Generate OTP
        $expiry = time() + 300; // OTP valid for 5 min

        // Store OTP in database
        $insert_otp = "INSERT INTO otp_table (email, otp, expiry) VALUES ('$email', '$otp', '$expiry')
                       ON DUPLICATE KEY UPDATE otp='$otp', expiry='$expiry'";
        mysqli_query($conn, $insert_otp);

        // Send OTP via Email (Needs SMTP Setup)
        mail($email, "Password Reset OTP", "Your OTP is: $otp. Valid for 5 minutes.");

        echo json_encode(["status" => "success", "message" => "OTP sent to email"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Email not registered"]);
    }
}
?>
