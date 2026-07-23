<?php

include '../connection.php';
include '../translate_helper.php';

if (!isset($_POST['category_id']) || !isset($_POST['category_name'])) {
    echo json_encode(["success" => "false", "message" => "Missing required fields"]);
    return;
}

$category_id = mysqli_real_escape_string($conn, $_POST['category_id']);
$category_name = mysqli_real_escape_string($conn, $_POST['category_name']);
$name_hi = isset($_POST['name_hi']) ? trim($_POST['name_hi']) : '';
$name_hn = isset($_POST['name_hn']) ? trim($_POST['name_hn']) : '';

// Auto translate if empty
if (empty($name_hi) || empty($name_hn)) {
    $trans = auto_translate_field($_POST['category_name']);
    if (empty($name_hi)) $name_hi = $trans['hi'];
    if (empty($name_hn)) $name_hn = $trans['hn'];
}

$name_hi_esc = mysqli_real_escape_string($conn, $name_hi);
$name_hn_esc = mysqli_real_escape_string($conn, $name_hn);

$query = "UPDATE main_category SET name = '$category_name', name_hi = '$name_hi_esc', name_hn = '$name_hn_esc'";

// यदि नई इमेज अपलोड की गई है, तो उसे अपडेट करें
if (isset($_POST['data']) && isset($_POST['name'])) {
    $data = $_POST['data'];
    $name = $_POST['name'];
    $path = "category/$name";
    
    // पुरानी इमेज को हटाने के लिए पहले उसका पथ खोजें
    $oldImageQuery = "SELECT image FROM main_category WHERE id = '$category_id'";
    $result = mysqli_query($conn, $oldImageQuery);
    
    if ($row = mysqli_fetch_assoc($result)) {
        $oldImagePath = $row['image'];
        if (file_exists($oldImagePath)) {
            unlink($oldImagePath); // पुरानी इमेज हटाएं
        }
    }

    // नई इमेज सेव करें और डेटाबेस अपडेट करें
    file_put_contents($path, base64_decode($data));
    $query .= ", image = '$path'";
}

$query .= " WHERE id = '$category_id'";

$exe = mysqli_query($conn, $query);

if ($exe) {
    echo json_encode(["success" => "true"]);
} else {
    echo json_encode(["success" => "false", "message" => mysqli_error($conn)]);
}

?>
