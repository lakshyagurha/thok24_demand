<?php
include '../../connection.php';
header('Content-Type: application/json');

if (isset($_FILES['image']) && isset($_POST['product_id'])) {
    $productId = $_POST['product_id'];
    $targetDir = "../uploads/";
    $fileName = uniqid() . '_' . basename($_FILES["image"]["name"]);
    $targetFile = $targetDir . $fileName;

    if (move_uploaded_file($_FILES["image"]["tmp_name"], $targetFile)) {
        $url = "uploads/" . $fileName;

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
