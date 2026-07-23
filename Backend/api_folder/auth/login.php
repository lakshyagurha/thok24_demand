<?php
include '../connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];


    $query = "SELECT * FROM users WHERE email = '$email'";
    $result = mysqli_query($conn, $query);
    $user = mysqli_fetch_assoc($result);

    if ($user && password_verify($password, $user['password'])) {
    
        // Latest user info wapas fetch karein
        $updatedUser = mysqli_fetch_assoc(mysqli_query($conn, "SELECT * FROM users WHERE email = '$email'"));

        echo json_encode(["status" => "success", "message" => "Login Successful", "user" => $updatedUser]);
    } else {
        echo json_encode(["status" => "error", "message" => "Invalid Email or Password"]);
    }
}
?>
