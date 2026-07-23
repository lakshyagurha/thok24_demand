<?php
include 'connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'];
    $password = $_POST['password'];

    $query = "SELECT * FROM admin WHERE email = '$email'";
    $result = mysqli_query($conn, $query);
    $user = mysqli_fetch_assoc($result);

    // Compare plain password directly (NOT recommended for production)
    if ($user && $password === $user['password']) {
        echo json_encode(["status" => "success", "message" => "Login Successful", "user" => $user]);
    } else {
        echo json_encode(["status" => "error", "message" => "Invalid Email or Password"]);
    }
}
?>

