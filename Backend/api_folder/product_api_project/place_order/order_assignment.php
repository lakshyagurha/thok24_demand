<?php
include '../../connection.php';

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $order_id = $_POST['order_id'] ?? '';
    $delivery_boy_id = $_POST['delivery_boy_id'] ?? '';
    $date_time = $_POST['date_time'] ?? '';

    if (empty($order_id) || empty($delivery_boy_id) || empty($date_time)) {
        echo json_encode(["success" => false, "message" => "All fields are required"]);
        exit;
    }

    // Insert query
    $query = "INSERT INTO order_assignment (order_id, delivery_boy_id, date_time) 
              VALUES ('$order_id', '$delivery_boy_id', '$date_time')";

    if (mysqli_query($conn, $query)) {
        echo json_encode(["success" => true, "message" => "Order assignment successful"]);
    } else {
        echo json_encode(["success" => false, "message" => "Order assignment failed"]);
    }
}
?>
