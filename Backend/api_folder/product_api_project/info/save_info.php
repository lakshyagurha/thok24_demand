<?php
include '../../connection.php';

include '../../translate_helper.php';

header('Content-Type: application/json');

$product_id = $_POST['product_id'] ?? '';
$attribute = $_POST['attribute'] ?? '';
$attribute_hi = $_POST['attribute_hi'] ?? '';
$attribute_hn = $_POST['attribute_hn'] ?? '';
$value = $_POST['value'] ?? '';
$value_hi = $_POST['value_hi'] ?? '';
$value_hn = $_POST['value_hn'] ?? '';

if ($product_id && $attribute && $value) {
    if (empty($attribute_hi) || empty($attribute_hn)) {
        $t_attr = auto_translate_field($attribute);
        if (empty($attribute_hi)) $attribute_hi = $t_attr['hi'];
        if (empty($attribute_hn)) $attribute_hn = $t_attr['hn'];
    }
    if (empty($value_hi) || empty($value_hn)) {
        $t_val = auto_translate_field($value);
        if (empty($value_hi)) $value_hi = $t_val['hi'];
        if (empty($value_hn)) $value_hn = $t_val['hn'];
    }

    $stmt = $conn->prepare("INSERT INTO product_info (product_id, attribute, attribute_hi, attribute_hn, value, value_hi, value_hn) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("issssss", $product_id, $attribute, $attribute_hi, $attribute_hn, $value, $value_hi, $value_hn);

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
