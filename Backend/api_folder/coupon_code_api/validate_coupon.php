<?php
include '../connection.php';

header('Content-Type: application/json');

// Get the coupon code from query parameter
$couponCode = $_GET['code'] ?? null;

if (!$couponCode) {
    echo json_encode(["success" => false, "message" => "Coupon code is required"]);
    exit;
}

// Prepare and execute query
$stmt = $conn->prepare("SELECT * FROM coupon WHERE code_name = ? ");
$stmt->bind_param("s", $couponCode);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode(["success" => false, "message" => "Invalid coupon code"]);
    exit;
}

$coupon = $result->fetch_assoc();

// Check if coupon is expired
$currentDate = date('d-m-Y');
$expiryDate = $coupon['expri_date'];

// Convert dates to comparable format
$currentDateParts = explode('-', $currentDate);
$expiryDateParts = explode('-', $expiryDate);

$currentTimestamp = mktime(0, 0, 0, $currentDateParts[1], $currentDateParts[0], $currentDateParts[2]);
$expiryTimestamp = mktime(0, 0, 0, $expiryDateParts[1], $expiryDateParts[0], $expiryDateParts[2]);

if ($currentTimestamp > $expiryTimestamp) {
    echo json_encode(["success" => false, "message" => "Coupon has expired"]);
    exit;
}

// Return coupon details if valid
echo json_encode([
    "success" => true, 
    "data" => [
        "title" => $coupon['title'],
        "description" => $coupon['description'],
        "code_name" => $coupon['code_name'],
        "discount" => $coupon['discount'],
        "min_amount" => $coupon['min_amount'],
        "expri_date" => $coupon['expri_date']
    ]
]);

$stmt->close();
$conn->close();
?>