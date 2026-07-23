<?php
include '../connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = $_POST['email'] ?? '';
    $new_name = $_POST['name'] ?? '';

    // Input validation
    if (empty($email) || empty($new_name)) {
        echo json_encode(["status" => "error", "message" => "Email and Name are required"]);
        exit;
    }

    // Check if email exists
    $check_query = "SELECT * FROM users WHERE email = '$email'";
    $check_result = mysqli_query($conn, $check_query);

    if (mysqli_num_rows($check_result) > 0) {
        // Update the name
        $update_query = "UPDATE users SET name = '$new_name' WHERE email = '$email'";
        if (mysqli_query($conn, $update_query)) {
            echo json_encode(["status" => "success", "message" => "Name updated successfully"]);
        } else {
            echo json_encode(["status" => "error", "message" => "Failed to update name"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Email not found"]);
    }
}
?>
