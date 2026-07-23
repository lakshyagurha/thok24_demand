<?php
include '../connection.php';
include '../translate_helper.php';

$category_name = $_POST['category_name'] ?? null;
$data = $_POST['data'] ?? null;
$name = $_POST['name'] ?? null;
$name_hi = $_POST['name_hi'] ?? '';
$name_hn = $_POST['name_hn'] ?? '';

if (!$category_name || !$data || !$name) {
    echo json_encode(["success" => "false", "message" => "Missing data"]);
    exit;
}

// Auto translate if empty
if (empty($name_hi) || empty($name_hn)) {
    $trans = auto_translate_field($category_name);
    if (empty($name_hi)) $name_hi = $trans['hi'];
    if (empty($name_hn)) $name_hn = $trans['hn'];
}

// Save file
$path = "category/$name";
file_put_contents($path, base64_decode($data));

// Insert to DB securely
$stmt = $conn->prepare("INSERT INTO main_category (name, name_hi, name_hn, image) VALUES (?, ?, ?, ?)");

$stmt->bind_param("ssss", $category_name, $name_hi, $name_hn, $path);
$success = $stmt->execute();

echo json_encode(["success" => $success ? "true" : "false"]);
?>
