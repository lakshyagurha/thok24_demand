<?php
include '../../connection.php';

include '../../translate_helper.php';

header('Content-Type: application/json');

$product_id = $_POST['product_id'] ?? '';
$name = $_POST['name'] ?? '';
$name_hi = $_POST['name_hi'] ?? '';
$name_hn = $_POST['name_hn'] ?? '';
$price = $_POST['price'] ?? '';
$selling_price = $_POST['selling_price'] ?? '';
$wholesale_price = $_POST['wholesale_price'] ?? '';
$stock = $_POST['stock_quantity'] ?? '0';

// Input validation
if ($product_id && $name && $price && $selling_price) {
    // Type casting
    $price = floatval($price);
    $selling_price = floatval($selling_price);
    $wholesale_price = floatval($wholesale_price);
    $stock = intval($stock);

    // Auto translate if empty
    if (empty($name_hi) || empty($name_hn)) {
        $t_name = auto_translate_field($name);
        if (empty($name_hi)) $name_hi = $t_name['hi'];
        if (empty($name_hn)) $name_hn = $t_name['hn'];
    }

    $stmt = $conn->prepare("INSERT INTO product_variants (product_id, name, name_hi, name_hn, price, selling_price, wholesale_price, stock) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("isssdddi", $product_id, $name, $name_hi, $name_hn, $price, $selling_price, $wholesale_price, $stock);

    if ($stmt->execute()) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Insert failed: ' . $stmt->error]);
    }

    $stmt->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Missing fields']);
}
?>
