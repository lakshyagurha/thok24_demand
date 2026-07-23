<?php
include '../connection.php';
header("Content-Type: application/json");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $new_password = password_hash($_POST['new_password'], PASSWORD_DEFAULT);

    $update_query = "UPDATE users SET password = '$new_password' WHERE email = '$email'";
    
    if (mysqli_query($conn, $update_query)) {
        echo json_encode(["status" => "success", "message" => "Password Updated"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update password"]);
    }
}
?>
