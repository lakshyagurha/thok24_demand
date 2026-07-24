<?php
include_once('../connection.php');
header('Content-Type: application/json');

// Get raw POST data
$rawData = file_get_contents("php://input");
$data = json_decode($rawData, true);

if (!isset($data['user_id']) || !isset($data['message'])) {
    echo json_encode(["success" => false, "message" => "Missing user_id or message"]);
    exit;
}

$userId = $data['user_id'];
$userMessage = $data['message'];

function tableExists($conn, $table) {
    $result = $conn->query("SHOW TABLES LIKE '$table'");
    return $result && $result->num_rows > 0;
}

// 1. Save user message to chat_messages if table exists
if (tableExists($conn, 'chat_messages')) {
    $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'user', ?)");
    $stmt->bind_param("is", $userId, $userMessage);
    $stmt->execute();
}

$cleanMsg = trim(strtolower($userMessage));

// Check for "bill dikhao" or "show bill" or "hisaab" or "parchi" or "order dikhao"
if (preg_match('/\b(bill|parchi|summary|hisab|hisaab|parchi|dikh|show)\b/i', $cleanMsg)) {
    // Fetch Cart Items
    $cartQuery = $conn->prepare("
        SELECT c.id, c.product_id, c.variant_id, c.quantity, c.image_url,
               p.name as product_name, pv.name as variant_name, pv.price, pv.selling_price
        FROM cart_items c
        JOIN products p ON c.product_id = p.id
        JOIN product_variants pv ON c.variant_id = pv.id
        WHERE c.user_id = ?
    ");
    $cartQuery->bind_param("i", $userId);
    $cartQuery->execute();
    $cartRes = $cartQuery->get_result();
    
    $cartItems = [];
    $subtotal = 0.0;
    while ($row = $cartRes->fetch_assoc()) {
        $cartItems[] = [
            "id" => (int)$row['id'],
            "product_id" => (int)$row['product_id'],
            "variant_id" => (int)$row['variant_id'],
            "name" => $row['product_name'],
            "product_name" => $row['product_name'],
            "variant_name" => $row['variant_name'],
            "price" => (float)$row['price'],
            "selling_price" => (float)$row['selling_price'],
            "quantity" => (int)$row['quantity'],
            "image_url" => $row['image_url']
        ];
        $subtotal += (float)$row['selling_price'] * (int)$row['quantity'];
    }
    
    if (empty($cartItems)) {
        $botReply = "Didi, abhi aapki parchi khali hai. Kuch mangvana ho toh boliye! 🛍️";
        if (tableExists($conn, 'chat_messages')) {
            $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
            $stmt->bind_param("is", $userId, $botReply);
            $stmt->execute();
        }
        echo json_encode([
            "success" => true,
            "reply" => $botReply,
            "items" => [],
            "message_type" => "text"
        ]);
        exit;
    }
    
    $handling = 5.0;
    $delivery = $subtotal < 500 ? 10.0 : 0.0;
    $finalAmount = $subtotal + $handling + $delivery;
    
    $botReply = "Ji Didi, ye raha aapka bill/parchi. Sab sahi hai na?";
    if (tableExists($conn, 'chat_messages')) {
        $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
        $stmt->bind_param("is", $userId, $botReply);
        $stmt->execute();
    }
    
    echo json_encode([
        "success" => true,
        "reply" => $botReply,
        "items" => $cartItems,
        "message_type" => "cartSummary",
        "subtotal" => $subtotal,
        "final_amount" => $finalAmount
    ]);
    exit;
}

// Check for "confirm" or "book" or "order book" or "pakka"
if (preg_match('/\b(confirm|book|pakka|pikka|chahiye)\b/i', $cleanMsg)) {
    // Fetch Cart Items
    $cartQuery = $conn->prepare("
        SELECT c.id, c.product_id, c.variant_id, c.quantity, c.image_url,
               p.name as product_name, pv.name as variant_name, pv.price, pv.selling_price
        FROM cart_items c
        JOIN products p ON c.product_id = p.id
        JOIN product_variants pv ON c.variant_id = pv.id
        WHERE c.user_id = ?
    ");
    $cartQuery->bind_param("i", $userId);
    $cartQuery->execute();
    $cartRes = $cartQuery->get_result();
    
    $cartItems = [];
    $subtotal = 0.0;
    while ($row = $cartRes->fetch_assoc()) {
        $cartItems[] = [
            "id" => (int)$row['id'],
            "product_id" => (int)$row['product_id'],
            "variant_id" => (int)$row['variant_id'],
            "name" => $row['product_name'],
            "product_name" => $row['product_name'],
            "variant_name" => $row['variant_name'],
            "price" => (float)$row['price'],
            "selling_price" => (float)$row['selling_price'],
            "quantity" => (int)$row['quantity'],
            "image_url" => $row['image_url']
        ];
        $subtotal += (float)$row['selling_price'] * (int)$row['quantity'];
    }
    
    if (empty($cartItems)) {
        $botReply = "Didi, abhi aapki parchi khali hai. Kuch add karne ko boliye, jaise '2 kilo aata bhej do'. 😊";
        if (tableExists($conn, 'chat_messages')) {
            $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
            $stmt->bind_param("is", $userId, $botReply);
            $stmt->execute();
        }
        echo json_encode([
            "success" => true,
            "reply" => $botReply,
            "items" => [],
            "message_type" => "text"
        ]);
        exit;
    }
    
    $handling = 5.0;
    $delivery = $subtotal < 500 ? 10.0 : 0.0;
    $finalAmount = $subtotal + $handling + $delivery;
    
    $botReply = "Didi, maine checkout page khol diya hai. Apni details verify karke order place kar lijiye! 🛍️";
    if (tableExists($conn, 'chat_messages')) {
        $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
        $stmt->bind_param("is", $userId, $botReply);
        $stmt->execute();
    }
    
    echo json_encode([
        "success" => true,
        "reply" => $botReply,
        "items" => $cartItems,
        "message_type" => "checkout",
        "subtotal" => $subtotal,
        "final_amount" => $finalAmount
    ]);
    exit;
}

$curl_err = '';
$response = '';
$responseData = [];

// GEMINI API CALL FOR INTENT EXTRACTION
// We'll use a strict prompt to output JSON.
// The API key MUST come from the environment. Never commit a key to source.
$geminiApiKey = getenv('GEMINI_API_KEY') ?: '';
if ($geminiApiKey === '') {
    // No key configured: fall back to deterministic regex extraction rather than
    // failing the request outright. Voice ordering degrades, but still works.
    $geminiApiKey = 'DUMMY_KEY_FOR_MOCKING';
    error_log("GEMINI_API_KEY not set; falling back to regex-only intent extraction.");
}

// Basic Regex Mocking if API Key is dummy or fails
$mockedExtraction = [];
if (preg_match('/(\d+)\s*(kilo|kg|packet|pack|liter|ml|g|gm|pc|piece)s?\s+([a-zA-Z\s]+)/i', $userMessage, $matches)) {
    $mockedExtraction[] = [
        "product_name" => trim($matches[3]),
        "quantity" => (int)$matches[1],
        "unit" => strtolower($matches[2])
    ];
} elseif (preg_match('/([a-zA-Z\s]+)\s*(\d+)\s*(kilo|kg|packet|pack|liter|ml|g|gm|pc|piece)/i', $userMessage, $matches)) {
    $mockedExtraction[] = [
        "product_name" => trim($matches[1]),
        "quantity" => (int)$matches[2],
        "unit" => strtolower($matches[3])
    ];
}

$extractedIntents = [];
if ($geminiApiKey === 'DUMMY_KEY_FOR_MOCKING') {
    // Fallback to basic mocking
    $extractedIntents = $mockedExtraction;
} else {
    // Actual cURL call to Gemini API
    $geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" . $geminiApiKey;
    
    $prompt = "You are a grocery intent extraction bot. Extract the grocery items the user wants to order from this message: '$userMessage'.
    Output ONLY a valid JSON array of objects with keys: 'product_name', 'quantity' (integer), 'unit' (string). No markdown, no backticks.";
    
    $postData = [
        "contents" => [
            ["parts" => [["text" => $prompt]]]
        ]
    ];
    
    $ch = curl_init($geminiUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($postData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
    $response = curl_exec($ch);
    
    $curl_err = '';
    if ($response === false) {
        $curl_err = curl_error($ch);
        error_log("Gemini API Curl Error: " . $curl_err);
    }
    curl_close($ch);
    
    $responseData = json_decode($response, true);
    if (isset($responseData['candidates'][0]['content']['parts'][0]['text'])) {
        $jsonText = trim($responseData['candidates'][0]['content']['parts'][0]['text']);
        // Strip markdown backticks if any
        $jsonText = str_replace(['```json', '```'], '', $jsonText);
        $decoded = json_decode(trim($jsonText), true);
        if (is_array($decoded)) {
            $extractedIntents = $decoded;
        }
    }
}

// Fallback if no intents found
if (empty($extractedIntents)) {
    // Check if it's a "regular order" intent
    if ((stripos($userMessage, 'regular') !== false || stripos($userMessage, 'wahi') !== false || stripos($userMessage, 'pichla') !== false) && tableExists($conn, 'regular_orders')) {
        // Fetch from regular_orders table
        $regQ = $conn->prepare("
            SELECT r.product_id, r.variant_id, p.name, pv.price, pv.selling_price
            FROM regular_orders r 
            JOIN products p ON r.product_id = p.id
            JOIN product_variants pv ON r.variant_id = pv.id
            WHERE r.user_id = ? ORDER BY r.frequency_score DESC LIMIT 5
        ");
        $regQ->bind_param("i", $userId);
        $regQ->execute();
        $regRes = $regQ->get_result();
        
        $addedItems = [];
        while ($row = $regRes->fetch_assoc()) {
            $pid = $row['product_id'];
            $vid = $row['variant_id'];
            
            // Fetch Image URL
            $imgUrl = '';
            $imgQ = $conn->prepare("SELECT image_url FROM product_images WHERE product_id = ? LIMIT 1");
            $imgQ->bind_param("i", $pid);
            $imgQ->execute();
            $imgRes = $imgQ->get_result();
            if ($imgRes->num_rows > 0) {
                $imgRow = $imgRes->fetch_assoc();
                $httpHost = $_SERVER['HTTP_HOST'] ?? 'localhost';
                $isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || ($_SERVER['SERVER_PORT'] ?? 80) == 443;
                $protocol = $isHttps ? 'https' : 'http';
                $baseFolder = (strpos($httpHost, 'localhost') !== false || strpos($httpHost, '192.168.') !== false) ? '/dxmart_api' : '/api_folder';
                $imgUrl = $protocol . "://" . $httpHost . $baseFolder . "/product_api_project/" . $imgRow['image_url'];
            }
            $imgQ->close();
            
            // Add to cart
            $cartIns = $conn->prepare("INSERT INTO cart_items (user_id, product_id, variant_id, quantity, image_url) VALUES (?, ?, ?, 1, ?) ON DUPLICATE KEY UPDATE quantity = quantity + 1, image_url = VALUES(image_url)");
            $cartIns->bind_param("iiis", $userId, $pid, $vid, $imgUrl);
            $cartIns->execute();
            $cartItemId = $cartIns->insert_id;
            
            if ($cartItemId == 0) {
                $checkIdQ = $conn->prepare("SELECT id FROM cart_items WHERE user_id = ? AND product_id = ? AND variant_id = ?");
                $checkIdQ->bind_param("iii", $userId, $pid, $vid);
                $checkIdQ->execute();
                $checkIdRes = $checkIdQ->get_result();
                if ($checkIdRes->num_rows > 0) {
                    $checkIdRow = $checkIdRes->fetch_assoc();
                    $cartItemId = (int)$checkIdRow['id'];
                }
                $checkIdQ->close();
            }
            $cartIns->close();
            
            $addedItems[] = [
                "id" => $cartItemId,
                "product_id" => (int)$pid,
                "variant_id" => (int)$vid,
                "name" => $row['name'],
                "product_name" => $row['name'],
                "variant_name" => "",
                "price" => (float)$row['price'],
                "selling_price" => (float)$row['selling_price'],
                "quantity" => 1,
                "image_url" => $imgUrl
            ];
        }
        
        $botReply = "Aapka regular order cart mein add kar diya gaya hai. Kuch aur chahiye?";
        
        // Save bot response if table exists
        if (tableExists($conn, 'chat_messages')) {
            $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
            $stmt->bind_param("is", $userId, $botReply);
            $stmt->execute();
        }
        
        echo json_encode([
            "success" => true,
            "reply" => $botReply,
            "items" => $addedItems,
            "debug_gemini_raw" => $response,
            "debug_curl_err" => $curl_err,
            "debug_response_data" => $responseData
        ]);
        exit;
    } else {
        $botReply = "Maaf karna, main samajh nahi paya. Kripya quantity ke saath product ka naam likhein. Jaise: '2 kilo aata'.";
        if (tableExists($conn, 'chat_messages')) {
            $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
            $stmt->bind_param("is", $userId, $botReply);
            $stmt->execute();
        }
        
        echo json_encode([
            "success" => true,
            "reply" => $botReply,
            "items" => [],
            "debug_gemini_raw" => $response,
            "debug_curl_err" => $curl_err,
            "debug_response_data" => $responseData
        ]);
        exit;
    }
}

// MATCHING AND CART INSERTION
$addedProducts = [];
$failedProducts = [];

foreach ($extractedIntents as $intent) {
    $pname = $intent['product_name'] ?? '';
    $qty = $intent['quantity'] ?? 1;
    $unit = $intent['unit'] ?? '';
    
    // Search in product_aliases if exists, else fallback to searching products directly
    $searchToken = "%" . trim(strtolower($pname)) . "%";
    if (tableExists($conn, 'product_aliases')) {
        $searchQ = $conn->prepare("
            SELECT p.id as product_id, p.name as product_name, pv.id as variant_id, pv.price, pv.selling_price
            FROM product_aliases pa
            JOIN products p ON pa.product_id = p.id
            JOIN product_variants pv ON p.id = pv.product_id
            WHERE pa.alias LIKE ? LIMIT 1
        ");
        $searchQ->bind_param("s", $searchToken);
    } else {
        $searchQ = $conn->prepare("
            SELECT p.id as product_id, p.name as product_name, pv.id as variant_id, pv.price, pv.selling_price
            FROM products p
            JOIN product_variants pv ON p.id = pv.product_id
            WHERE p.name LIKE ? LIMIT 1
        ");
        $searchQ->bind_param("s", $searchToken);
    }
    $searchQ->execute();
    $searchRes = $searchQ->get_result();
    
    if ($searchRes->num_rows > 0) {
        $row = $searchRes->fetch_assoc();
        $pid = $row['product_id'];
        $vid = $row['variant_id'];
        $full_name = $row['product_name'];
        
        // Image URL fetch logic (simplified)
        $imgUrl = '';
        $imgQ = $conn->prepare("SELECT image_url FROM product_images WHERE product_id = ? LIMIT 1");
        $imgQ->bind_param("i", $pid);
        $imgQ->execute();
        $imgRes = $imgQ->get_result();
        if ($imgRes->num_rows > 0) {
            $imgRow = $imgRes->fetch_assoc();
            $httpHost = $_SERVER['HTTP_HOST'] ?? 'localhost';
            $isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || ($_SERVER['SERVER_PORT'] ?? 80) == 443;
            $protocol = $isHttps ? 'https' : 'http';
            $baseFolder = (strpos($httpHost, 'localhost') !== false || strpos($httpHost, '192.168.') !== false) ? '/dxmart_api' : '/api_folder';
            $imgUrl = $protocol . "://" . $httpHost . $baseFolder . "/product_api_project/" . $imgRow['image_url'];
        }
        $imgQ->close();
        
        // Check if exists in cart
        $checkCart = $conn->prepare("SELECT id FROM cart_items WHERE user_id = ? AND product_id = ? AND variant_id = ?");
        $checkCart->bind_param("iii", $userId, $pid, $vid);
        $checkCart->execute();
        $cartRes = $checkCart->get_result();
        
        $cartItemId = 0;
        if ($cartRes->num_rows > 0) {
            $cartRow = $cartRes->fetch_assoc();
            $cartItemId = (int)$cartRow['id'];
            $upd = $conn->prepare("UPDATE cart_items SET quantity = quantity + ? WHERE id = ?");
            $upd->bind_param("ii", $qty, $cartItemId);
            $upd->execute();
            $upd->close();
        } else {
            $ins = $conn->prepare("INSERT INTO cart_items (user_id, product_id, variant_id, quantity, image_url) VALUES (?, ?, ?, ?, ?)");
            $ins->bind_param("iiiis", $userId, $pid, $vid, $qty, $imgUrl);
            $ins->execute();
            $cartItemId = $ins->insert_id;
            $ins->close();
        }
        $checkCart->close();
        
        $addedProducts[] = [
            "id" => $cartItemId,
            "product_id" => (int)$pid,
            "variant_id" => (int)$vid,
            "name" => $full_name,
            "product_name" => $full_name,
            "variant_name" => "",
            "price" => (float)$row['price'],
            "selling_price" => (float)$row['selling_price'],
            "quantity" => (int)$qty,
            "image_url" => $imgUrl
        ];
    } else {
        $failedProducts[] = $pname;
    }
}

// FORMULATE RESPONSE
$botReply = "";
if (count($addedProducts) > 0) {
    $botReply .= "Ji, maine cart mein add kar diya hai: ";
    $items = [];
    foreach ($addedProducts as $p) {
        $items[] = $p['quantity'] . " " . $p['name'];
    }
    $botReply .= implode(", ", $items) . ". ";
}

if (count($failedProducts) > 0) {
    $botReply .= "Lekin mujhe ye items nahi mile: " . implode(", ", $failedProducts) . ". ";
}

if ($botReply === "") {
    $botReply = "Maaf karna, mujhe aapki request samajh nahi aayi.";
}

// Save bot response if table exists
if (tableExists($conn, 'chat_messages')) {
    $stmt = $conn->prepare("INSERT INTO chat_messages (user_id, role, message) VALUES (?, 'bot', ?)");
    $stmt->bind_param("is", $userId, $botReply);
    $stmt->execute();
}

echo json_encode([
    "success" => true,
    "reply" => $botReply,
    "items" => $addedProducts,
    "debug_gemini_raw" => $response,
    "debug_curl_err" => $curl_err,
    "debug_response_data" => $responseData
]);
?>
