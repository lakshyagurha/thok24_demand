<?php
include '../connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $name = $_POST['name'];
    $email = $_POST['email'];
    $password = password_hash($_POST['password'], PASSWORD_DEFAULT); // Encrypt password
    $date_time = $_POST['date_time'];


    // Check if email already exists
    $check_query = "SELECT * FROM users WHERE email = '$email'";
    $check_result = mysqli_query($conn, $check_query);

    if (mysqli_num_rows($check_result) > 0) {
        echo json_encode(["status" => "error", "message" => "Email already registered"]);
    } else {
        // Insert new user
        $query = "INSERT INTO users (name, email, password,status, date_time) VALUES ('$name', '$email', '$password', 'active', '$date_time')";
        if (mysqli_query($conn, $query)) {
            echo json_encode(["status" => "success", "message" => "Signup Successful"]);
        } else {
            echo json_encode(["status" => "error", "message" => "Signup Failed"]);
        }
    }
}
?>
