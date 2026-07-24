<?php
include '../../connection.php';
header('Content-Type: application/json');

$data = json_decode(file_get_contents("php://input"), true);

$user_id        = isset($data['user_id']) ? (int)$data['user_id'] : 0;
$coupon_code    = isset($data['coupon_code']) ? $data['coupon_code'] : null;
$discount_amount= isset($data['discount_amount']) ? (float)$data['discount_amount'] : 0;
$delivery_charge= isset($data['delivery_charge']) ? (float)$data['delivery_charge'] : 0;
$handling_charge= isset($data['handling_charge']) ? (float)$data['handling_charge'] : 0;
$payment_method = isset($data['payment_method']) ? $data['payment_method'] : 'COD';
$dateTimeNow    = isset($data['dateTimeNow']) ? $data['dateTimeNow'] : 'TEST';
$deliveryDate   = isset($data['deliveryDate']) ? $data['deliveryDate'] : 'TEST';
$deliverTime    = isset($data['deliverTime']) ? $data['deliverTime'] : 'TEST';
$location_id    = isset($data['location_id']) ? (int)$data['location_id'] : 0;
$famount        = isset($data['famount']) ? $data['famount'] : 0;
$gift           = isset($data['gift']) ? $data['gift'] : null;

$user_email     = isset($data['user_email']) ? $data['user_email'] : null;
$user_name      = isset($data['user_name']) ? $data['user_name'] : null;

$company_email = "digixcode.pab@gmail.com";



if (!$user_id) {
    echo json_encode(["success" => false, "message" => "User ID missing"]);
    exit;
}

// 1. Cart का डेटा उठाओ
$stmt = $conn->prepare("
    SELECT c.product_id, c.variant_id, c.quantity, c.image_url, v.price, v.selling_price, p.name as product_name
    FROM cart_items c
    JOIN product_variants v ON c.variant_id = v.id
    JOIN products p ON c.product_id = p.id
    WHERE c.user_id = ?
");


$stmt->bind_param("i", $user_id);
$stmt->execute();
$cart_result = $stmt->get_result();

if ($cart_result->num_rows == 0) {
    echo json_encode(["success" => false, "message" => "Cart is empty"]);
    exit;
}


$cart_items = [];
$cart_total = 0;

while ($row = $cart_result->fetch_assoc()) {
    $mrp_price     = $row['price'];          // original MRP (for display/reference)
    $selling_price = $row['selling_price'];  // actual price customer pays
    $cart_total += $selling_price * $row['quantity'];

    $cart_items[] = [
    'product_id'   => $row['product_id'],
    'variant_id'   => $row['variant_id'],
    'quantity'     => $row['quantity'],
    'price'        => $mrp_price,
    'selling_price'=> $selling_price,
    'image_url'    => $row['image_url'],
    'product_name' => $row['product_name']
    ];
}
$stmt->close();


// 2. Final amount calculate
$final_amount = ($cart_total - $discount_amount) + $delivery_charge + $handling_charge;

// 3. Orders table में insert
$order_stmt = $conn->prepare("
    INSERT INTO orders 
    (user_id, total_amount, coupon_code, discount_amount, delivery_charge, handling_charge, final_amount, status, payment_method, order_datetime, delivery_date, delivery_time, location_id, gift) 
    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?)
");
$order_stmt->bind_param(
    "idsddddssssis",
    $user_id,
    $cart_total,
    $coupon_code,
    $discount_amount,
    $delivery_charge,
    $handling_charge,
    $final_amount,
    $payment_method,
    $dateTimeNow,
    $deliveryDate,
    $deliverTime,
    $location_id,
    $gift
);

$order_stmt->execute();
$order_id = $order_stmt->insert_id;
$order_stmt->close();

// 4. Order items table में save करो + stock update
foreach ($cart_items as $item) {
    $oi_stmt = $conn->prepare("
        INSERT INTO order_items (order_id, product_id, variant_id, quantity, image_url) 
        VALUES (?, ?, ?, ?, ?)
    ");
    $oi_stmt->bind_param("iiiis", $order_id, $item['product_id'], $item['variant_id'], $item['quantity'], $item['image_url']);
    $oi_stmt->execute();
    $oi_stmt->close();

    $stock_stmt = $conn->prepare("
        UPDATE product_variants 
        SET stock = stock - ? 
        WHERE id = ? AND stock >= ?
    ");
    $stock_stmt->bind_param("iii", $item['quantity'], $item['variant_id'], $item['quantity']);
    $stock_stmt->execute();
    $stock_stmt->close();
}

// 5. Cart खाली करो
$del_stmt = $conn->prepare("DELETE FROM cart_items WHERE user_id = ?");
$del_stmt->bind_param("i", $user_id);
$del_stmt->execute();
$del_stmt->close();

$address = "";
$addr_stmt = $conn->prepare("SELECT name, phone, full_address, pin_code, landmark 
                             FROM delivery_address 
                             WHERE user_id = ? 
                             ORDER BY id DESC LIMIT 1");
$addr_stmt->bind_param("i", $user_id);
$addr_stmt->execute();
$addr_res = $addr_stmt->get_result();
if ($addr_res->num_rows > 0) {
    $addr_row = $addr_res->fetch_assoc();
    $address = $addr_row['name'] . " | " . $addr_row['phone'] . "<br>" .
               $addr_row['full_address'] . ", Landmark: " . $addr_row['landmark'] .
               " - " . $addr_row['pin_code'];
}
$addr_stmt->close();


// ================= ASYNCHRONOUS EMAIL SENDING =================
function fire_and_forget_curl($url, $post_data) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($post_data));
    curl_setopt($ch, CURLOPT_TIMEOUT, 1); // 1 second timeout
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, false);
    curl_setopt($ch, CURLOPT_FRESH_CONNECT, true);
    curl_setopt($ch, CURLOPT_FORBID_REUSE, true);
    curl_setopt($ch, CURLOPT_HEADER, false);
    
    // For HTTPS requests — this call carries customer order and email data over the
    // public internet, so certificate verification must stay on.
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
    
    $result = curl_exec($ch);
    
    // Even if it fails, we don't care in fire-and-forget
    if (curl_errno($ch)) {
        error_log("Background request error: " . curl_error($ch));
    }
    
    curl_close($ch);
}

// Prepare email data
$email_data = [
    'user_email' => $user_email,
    'user_name' => $user_name,
    'order_id' => $order_id,
    'dateTimeNow' => $dateTimeNow,
    'deliveryDate' => $deliveryDate,
    'deliverTime' => $deliverTime,
    'payment_method' => $payment_method,
    'address' => $address,
    'cart_items' => json_encode($cart_items),
    'cart_total' => $cart_total,
    'discount_amount' => $discount_amount,
    'delivery_charge' => $delivery_charge,
    'handling_charge' => $handling_charge,
    'final_amount' => $final_amount,
    'company_email' => $company_email,
    'email_type' => 'user' // Add type to distinguish
];

// Send user email in background
if ($user_email) {
    $email_data['email_type'] = 'user';
    fire_and_forget_curl("https://digimart.digixcode.com/api_folder/product_api_project/place_order/send_email_background.php", $email_data);
}

// Send company email in background
$email_data['email_type'] = 'company';
fire_and_forget_curl("https://digimart.digixcode.com/api_folder/product_api_project/place_order/send_email_background.php", $email_data);

// ================= END EMAIL BLOCK =================

echo json_encode([
    "success" => true,
    "message" => "Order placed successfully",
    "order_id" => $order_id,
    "final_amount" => $final_amount
]);
?>