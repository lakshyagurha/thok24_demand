<?php
include '../../connection.php';

header('Content-Type: application/json');

// Check for POST request
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Get data from POST request
    $city_id = isset($_POST['city_id']) ? $_POST['city_id'] : '';
    $city_name = isset($_POST['city_name']) ? $_POST['city_name'] : '';

    // Validate inputs
    if (empty($city_id) || empty($city_name)) {
        echo json_encode([
            'success' => false,
            'message' => 'City ID and City Name are required'
        ]);
        exit;
    }

    // Prepare and execute update query
    $stmt = $conn->prepare("UPDATE city SET city_name = ? WHERE id = ?");
    $stmt->bind_param("si", $city_name, $city_id);

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

