<?php
header('Content-Type: application/json');
error_reporting(0); // hide warnings

include '../connection.php';

// Get POST data safely
$user_id = $_POST['user_id'] ?? '';
$name = $_POST['name'] ?? '';
$phone = $_POST['phone'] ?? '';
$full_address = $_POST['full_address'] ?? '';
$pin_code = $_POST['pin_code'] ?? '';
$landmark = $_POST['landmark'] ?? '';

// Check for empty fields
if (empty($user_id) || empty($name) || empty($phone) || empty($full_address) || empty($pin_code) || empty($landmark)) {
    echo json_encode([
        "success" => "false",
        "message" => "All fields are required"
    ]);
    exit;
}

// Insert to DB securely
$stmt = $conn->prepare("INSERT INTO delivery_address (user_id, name, phone, full_address, pin_code, landmark) VALUES (?, ?, ?, ?, ?, ?)");
if (!$stmt) {
    echo json_encode(["success" => "false", "message" => "Prepare failed: " . $conn->error]);
    exit;
}

$stmt->bind_param("isssss", $user_id, $name, $phone, $full_address, $pin_code, $landmark);
$success = $stmt->execute();

echo json_encode([
    "success" => $success ? "true" : "false",
    "message" => $success ? "Address added successfully" : $stmt->error
]);
?>
