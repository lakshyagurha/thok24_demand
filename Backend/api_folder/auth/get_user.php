<?php

include '../connection.php';

if (isset($_GET['email'])) {
    $email = $_GET['email'];

    $query = "SELECT * FROM users WHERE email = '$email'"; // ✅ Poora user detail fetch karega
    $result = mysqli_query($conn, $query);

    if (mysqli_num_rows($result) > 0) {
        $row = mysqli_fetch_assoc($result);
        echo json_encode([
            "status" => "success",
            "user" => $row // ✅ Poora user ka detail JSON format me bhej raha hai
        ]);
    } else {
        echo json_encode(["status" => "error", "message" => "User not found"]);
    }
} else {
    // echo json_encode(["status" => "error", "message" => "Email parameter missing"]);
}
?>
