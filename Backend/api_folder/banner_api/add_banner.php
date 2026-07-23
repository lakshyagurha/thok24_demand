<?php
include '../connection.php';

$data = $_POST['data'] ?? null;
$originalName = $_POST['name'] ?? null;
$category_id = $_POST['category_id'] ?? null;

if (!$data || !$originalName || !$category_id) {
    echo json_encode(["success" => "false", "message" => "Missing data"]);
    exit;
}

// Get extension from original file name
$ext = pathinfo($originalName, PATHINFO_EXTENSION);

// Generate unique filename
$milliseconds = round(microtime(true) * 1000);
$uniqueName = "banner_image_" . $milliseconds . "." . $ext;

// Final path (inside banner folder)
$path = "banner/" . $uniqueName;

// Save file
if (!file_put_contents($path, base64_decode($data))) {
    echo json_encode(["success" => "false", "message" => "Failed to save image"]);
    exit;
}

// Insert to DB securely
$stmt = $conn->prepare("INSERT INTO banner (category_id, banner_image) VALUES (?, ?)");
$stmt->bind_param("is", $category_id, $path);
$success = $stmt->execute();

echo json_encode(["success" => $success ? "true" : "false", "filename" => $uniqueName]);
?>
