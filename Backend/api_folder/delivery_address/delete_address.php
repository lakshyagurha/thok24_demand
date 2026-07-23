<?php
include '../connection.php';

if (isset($_POST['id'])) {
    $id = mysqli_real_escape_string($conn, $_POST['id']); // Security ke liye escape

    $deleteQuery = "DELETE FROM delivery_address WHERE id = '$id'";
    $exe = mysqli_query($conn, $deleteQuery);

    $arr = [];
    if ($exe) {
        $arr["success"] = "true";
    } else {
        $arr["success"] = "false";
    }

    echo json_encode($arr);
} else {
    echo json_encode([
        "success" => "false",
        "message" => "ID not provided"
    ]);
}
?>
