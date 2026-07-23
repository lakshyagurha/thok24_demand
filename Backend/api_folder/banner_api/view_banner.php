<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include '../connection.php';

$response = [];

// 1️⃣ Fetch banner with main category name + image
$offer_query = "
SELECT 
    b.id, 
    b.banner_image, 
    b.category_id, 
    mc.name AS category_name,
    mc.image AS category_image
FROM banner b
JOIN main_category mc ON b.category_id = mc.id
ORDER BY b.id DESC
";

$offer_result = mysqli_query($conn, $offer_query);
$offer_data = [];

if ($offer_result) {
    while ($row = mysqli_fetch_assoc($offer_result)) {
        $offer_data[] = $row;
    }
    $response['offer_banners'] = $offer_data;
} else {
    $response['offer_banners'] = [];
    $response['error'] = mysqli_error($conn);
}

// 2️⃣ Fetch main categories with image
$cat_query = "SELECT id, name, image FROM main_category ORDER BY name ASC";
$cat_result = mysqli_query($conn, $cat_query);
$category_data = [];

if ($cat_result) {
    while ($row = mysqli_fetch_assoc($cat_result)) {
        $category_data[] = $row;
    }
    $response['main_categories'] = $category_data;
} else {
    $response['main_categories'] = [];
    $response['error'] = mysqli_error($conn);
}

// ✅ Final JSON
echo json_encode([
    "success" => true,
    "data" => $response
]);

mysqli_close($conn);
?>
