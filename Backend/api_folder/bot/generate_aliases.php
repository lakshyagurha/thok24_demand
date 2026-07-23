<?php
include_once('../connection.php');

// Simple function to extract keywords
function generateBasicAliases($productName) {
    $aliases = [];
    $lowerName = strtolower($productName);
    
    // Exact name
    $aliases[] = $lowerName;
    
    // Split by spaces to find keywords
    $words = explode(" ", $lowerName);
    
    // Clean up words and filter small ones
    foreach ($words as $word) {
        $clean = preg_replace('/[^a-z0-9]/', '', $word);
        if (strlen($clean) > 2) {
            $aliases[] = $clean;
        }
    }
    
    // specific hardcoded maps for common grocery items (Hinglish/Hindi mapping)
    $mapping = [
        'moong' => ['dal', 'daal', 'green moong', 'moong dal', 'moong daal', 'mung'],
        'chana' => ['dal', 'daal', 'chole', 'kabuli chana', 'chana dal'],
        'atta' => ['aata', 'flour', 'gehu', 'wheat flour'],
        'rice' => ['chawal', 'basmati', 'masoori'],
        'ghee' => ['desi ghee', 'butter'],
        'oil' => ['tel', 'mustard oil', 'sarso tel', 'refined oil'],
        'sugar' => ['chini', 'cheeni', 'shakkar'],
        'tea' => ['chai', 'chai patti', 'taj mahal'],
        'coffee' => ['kofi', 'bru', 'nescafe'],
        'milk' => ['dudh', 'doodh', 'amul taaza'],
        'paneer' => ['cheese', 'malai paneer'],
        'curd' => ['dahi', 'masti dahi'],
        'bread' => ['paw', 'pav'],
        'butter' => ['makkhan']
    ];
    
    foreach ($mapping as $key => $synonyms) {
        if (strpos($lowerName, $key) !== false) {
            $aliases = array_merge($aliases, $synonyms);
        }
    }
    
    return array_unique($aliases);
}

// Fetch all products
$query = "SELECT id, name FROM products";
$result = $conn->query($query);

$addedCount = 0;

if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $productId = $row['id'];
        $productName = $row['name'];
        
        $aliases = generateBasicAliases($productName);
        
        foreach ($aliases as $alias) {
            // Check if already exists
            $checkQ = $conn->prepare("SELECT id FROM product_aliases WHERE product_id = ? AND alias = ?");
            $checkQ->bind_param("is", $productId, $alias);
            $checkQ->execute();
            $checkRes = $checkQ->get_result();
            
            if ($checkRes->num_rows == 0) {
                // Insert
                $insQ = $conn->prepare("INSERT INTO product_aliases (product_id, language, alias) VALUES (?, 'auto', ?)");
                $insQ->bind_param("is", $productId, $alias);
                if ($insQ->execute()) {
                    $addedCount++;
                }
            }
        }
    }
}

echo json_encode([
    "success" => true,
    "message" => "Successfully generated $addedCount new product aliases."
]);
?>
