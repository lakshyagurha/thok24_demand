<?php
include '../../connection.php';
header('Content-Type: application/json');

if (isset($_POST['id'])) {
    $product_id = (int)$_POST['id'];

    // ✅ Step 1: Get all image filenames first
    $imageQuery = $conn->query("SELECT image_url FROM product_images WHERE product_id = $product_id");

    while ($row = $imageQuery->fetch_assoc()) {
        $filePath = "../../product_api_project/" . $row['image_url']; // adjust path as needed

        if (file_exists($filePath)) {
            unlink($filePath); // ✅ delete file from server
        }
    }

    // ✅ Step 2: Delete from DB (variants, info, highlights, images, and product)
    $conn->query("DELETE FROM product_variants WHERE product_id = $product_id");
    $conn->query("DELETE FROM product_info WHERE product_id = $product_id");
    $conn->query("DELETE FROM product_highlights WHERE product_id = $product_id");
    $conn->query("DELETE FROM product_images WHERE product_id = $product_id");

    $stmt = $conn->prepare("DELETE FROM products WHERE id = ?");
    $stmt->bind_param("i", $product_id);

    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Product and images deleted successfully']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Delete failed: ' . $stmt->error]);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Product ID is required']);
}
