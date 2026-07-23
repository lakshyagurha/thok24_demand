<?php
include '../../connection.php';
include '../../translate_helper.php';
header('Content-Type: application/json');

// Read JSON input
$json = file_get_contents('php://input');
$data = json_decode($json, true);

// Validate JSON
if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(['success' => false, 'message' => 'Invalid JSON']);
    exit;
}

// Check empty body
if (empty($data)) {
    echo json_encode(['success' => false, 'message' => 'Empty input data']);
    exit;
}

// Extract values
$name = trim($data['name'] ?? '');
$name_hi = trim($data['name_hi'] ?? '');
$name_hn = trim($data['name_hn'] ?? '');
$description = trim($data['description'] ?? '');
$description_hi = trim($data['description_hi'] ?? '');
$description_hn = trim($data['description_hn'] ?? '');
$main_category_id = isset($data['main_category_id']) ? (int)$data['main_category_id'] : null;
$type = $data['types'] ?? 'normal';

// Validate required fields
if (!$name || !$main_category_id) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields'
    ]);
    exit;
}

// Auto translate if empty
if (empty($name_hi) || empty($name_hn)) {
    $t_name = auto_translate_field($name);
    if (empty($name_hi)) $name_hi = $t_name['hi'];
    if (empty($name_hn)) $name_hn = $t_name['hn'];
}

if (!empty($description)) {
    if (empty($description_hi) || empty($description_hn)) {
        $t_desc = auto_translate_field($description);
        if (empty($description_hi)) $description_hi = $t_desc['hi'];
        if (empty($description_hn)) $description_hn = $t_desc['hn'];
    }
} else {
    $description = "test";
    $description_hi = "टेस्ट";
    $description_hn = "test";
}

// Prepare insert
$stmt = $conn->prepare("
    INSERT INTO products (name, name_hi, name_hn, description, description_hi, description_hn, main_category_id, types)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
");

$stmt->bind_param("ssssssis", $name, $name_hi, $name_hn, $description, $description_hi, $description_hn, $main_category_id, $type);

// Execute
if ($stmt->execute()) {
    echo json_encode([
        'success' => true,
        'id' => $conn->insert_id
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Insert failed: ' . $stmt->error
    ]);
}

$stmt->close();
?>
