<?php
include '../../connection.php';
header('Content-Type: application/json');

$user_id = $_GET['user_id'] ?? '';
$lang = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

$name_col = "p.name";
$desc_col = "p.description";
$var_col = "v.name";

if ($lang === 'hi' || $lang === 'hn') {
    $name_col = "COALESCE(NULLIF(p.name_$lang, ''), p.name)";
    $desc_col = "COALESCE(NULLIF(p.description_$lang, ''), p.description)";
    $var_col = "COALESCE(NULLIF(v.name_$lang, ''), v.name)";
}

$sql = "SELECT c.id, c.product_id, c.variant_id, c.quantity, c.image_url,
        $name_col AS name, $desc_col AS description, 
        $var_col AS variant_name, v.price, v.selling_price,
        v.stock  -- ✅ Add this
        FROM cart_items c
        JOIN products p ON p.id = c.product_id
        LEFT JOIN product_variants v ON v.id = c.variant_id
        WHERE c.user_id = ?";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $user_id);
$stmt->execute();
$result = $stmt->get_result();

$cart = [];
while ($row = $result->fetch_assoc()) {
    $cart[] = $row;
}

echo json_encode(["success" => true, "cart" => $cart]);
?>
