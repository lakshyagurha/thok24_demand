<?php
include '../../connection.php';

header('Content-Type: application/json');

// Check for POST request
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Get data from POST request
    $district_id = isset($_POST['district_id']) ? $_POST['district_id'] : '';
    $district_name = isset($_POST['district_name']) ? $_POST['district_name'] : '';

    // Validate inputs
    if (empty($district_id) || empty($district_name)) {
        echo json_encode([
            'success' => false,
            'message' => 'District ID and District Name are required'
        ]);
        exit;
    }

    // Prepare and execute update query
    $stmt = $conn->prepare("UPDATE district SET district_name = ? WHERE id = ?");
    $stmt->bind_param("si", $district_name, $district_id);

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'District updated successfully'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to update District'
        ]);
    }

    $stmt->close();
    $conn->close();
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid Request Method'
    ]);
}
?>

