<?php
include '../connection.php';


$title = $_POST['title'] ?? null;
$description = $_POST['description'] ?? null;
$code_name = $_POST['code_name'] ?? null;
$discount = $_POST['discount'] ?? null;
$min_amount = $_POST['min_amount'] ?? null;
$expri_date = $_POST['expri_date'] ?? null;
$status = $_POST['status'] ?? null;




$stmt = $conn->prepare("INSERT INTO coupon (title, description,code_name,discount,expri_date,status, min_amount) VALUES (?, ?,?,?,?,?,?)");
$stmt->bind_param("sssissi", $title, $description,$code_name,$discount,$expri_date,$status,$min_amount);
$success = $stmt->execute();

echo json_encode(["success" => $success ? "true" : "false", "filename" => $uniqueName]);
?>
