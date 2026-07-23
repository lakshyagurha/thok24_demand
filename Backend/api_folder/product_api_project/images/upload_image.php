<?php
include '../../connection.php';

header('Content-Type: application/json');

if (isset($_FILES['image']) && isset($_POST['product_id'])) {
    $productId = $_POST['product_id'];
    $uploadFolder = "uploads/";
    $targetDir = __DIR__ . "/$uploadFolder";  // ✅ Server path
    $fileName = uniqid() . '_' . basename($_FILES["image"]["name"]);
    $targetFile = $targetDir . $fileName;

    if (move_uploaded_file($_FILES["image"]["tmp_name"], $targetFile)) {
        $url = $uploadFolder . $fileName;  // ✅ URL path

        $stmt = $conn->prepare("INSERT INTO product_images (product_id, image_url) VALUES (?, ?)");
        $stmt->bind_param("is", $productId, $url);

        if ($stmt->execute()) {
            echo json_encode(['success' => true, 'image_url' => $url]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Insert failed: ' . $stmt->error]);
        }

        $stmt->close();
    } else {
        echo json_encode(['success' => false, 'message' => 'Upload failed']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Missing image or product_id']);
}
