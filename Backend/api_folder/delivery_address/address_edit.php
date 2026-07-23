<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

include '../connection.php';

// Required fields check
if (
    isset($_POST['address_id']) &&
    isset($_POST['user_id']) &&
    isset($_POST['name']) &&
    isset($_POST['phone']) &&
    isset($_POST['full_address']) &&
    isset($_POST['pin_code']) &&
    isset($_POST['landmark'])
) {
    $address_id   = mysqli_real_escape_string($conn, $_POST['address_id']);
    $user_id      = mysqli_real_escape_string($conn, $_POST['user_id']);
    $name         = mysqli_real_escape_string($conn, $_POST['name']);
    $phone        = mysqli_real_escape_string($conn, $_POST['phone']);
    $full_address = mysqli_real_escape_string($conn, $_POST['full_address']);
    $pin_code     = mysqli_real_escape_string($conn, $_POST['pin_code']);
    $landmark     = mysqli_real_escape_string($conn, $_POST['landmark']);

    // Update query
    $updateQuery = "UPDATE delivery_address 
                    SET name = '$name', 
                        phone = '$phone', 
                        full_address = '$full_address', 
                        pin_code = '$pin_code', 
                        landmark = '$landmark'
                    WHERE id = '$address_id' AND user_id = '$user_id'";

    if (mysqli_query($conn, $updateQuery)) {
        echo json_encode([
            "success" => "true",
            "message" => "Address updated successfully"
        ]);
    } else {
        echo json_encode([
            "success" => "false",
            "message" => "Failed to update address"
        ]);
    }
} else {
    echo json_encode([
        "success" => "false",
        "message" => "Required fields are missing"
    ]);
}
?>
