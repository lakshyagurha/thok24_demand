<?php
include '../connection.php';
header('Content-Type: application/json');

if (!isset($_POST['user_id']) || !isset($_POST['new_status'])) {
    echo json_encode(["success" => false, "message" => "Missing parameters"]);
    exit;
}

$user_id = $_POST['user_id'];
$new_status = $_POST['new_status']; // 'active' or 'blocked'

$query = "UPDATE users SET status = '$new_status' WHERE id = $user_id";
if (mysqli_query($conn, $query)) {
    echo json_encode(["success" => true, "message" => "Status updated"]);
} else {
    echo json_encode(["success" => false, "message" => "Failed to update status"]);
}
?>
