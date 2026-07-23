<?php
include '../../connection.php';
header('Content-Type: application/json');

// Step 1: Read and decode JSON
$json = file_get_contents('php://input');
$data = json_decode($json, true);

include '../../translate_helper.php';

if (!$data || !isset($data['id'])) {
    echo json_encode(['success' => false, 'message' => 'Invalid or missing product ID']);
    exit;
}

$product_id = $data['id'];
$name = $data['name'] ?? '';
$name_hi = $data['name_hi'] ?? '';
$name_hn = $data['name_hn'] ?? '';
$description = $data['description'] ?? '';
$description_hi = $data['description_hi'] ?? '';
$description_hn = $data['description_hn'] ?? '';
$main_category_id = isset($data['main_category_id']) ? (int)$data['main_category_id'] : null;
$variants = $data['variants'] ?? [];
$info = $data['info'] ?? [];
$highlights = $data['highlights'] ?? [];
$imageUrls = $data['images'] ?? [];

// Auto translate if empty
if (empty($name_hi) || empty($name_hn)) {
    $t_name = auto_translate_field($name);
    if (empty($name_hi)) $name_hi = $t_name['hi'];
    if (empty($name_hn)) $name_hn = $t_name['hn'];
}

if (empty($description_hi) || empty($description_hn)) {
    $t_desc = auto_translate_field($description);
    if (empty($description_hi)) $description_hi = $t_desc['hi'];
    if (empty($description_hn)) $description_hn = $t_desc['hn'];
}

// Step 2: Update product info
$stmt = $conn->prepare("UPDATE products 
    SET name = ?, name_hi = ?, name_hn = ?, description = ?, description_hi = ?, description_hn = ?, main_category_id = ? WHERE id = ?");
$stmt->bind_param("ssssssii", $name, $name_hi, $name_hn, $description, $description_hi, $description_hn,  $main_category_id, $product_id);
if (!$stmt->execute()) {
    echo json_encode(['success' => false, 'message' => 'Failed to update product: ' . $stmt->error]);
    exit;
}
$stmt->close();

// Step 3: Variants
$existingVariantIds = [];
$res = $conn->query("SELECT id FROM product_variants WHERE product_id = $product_id");
while ($row = $res->fetch_assoc()) {
    $existingVariantIds[] = $row['id'];
}

$frontendVariantIds = [];
foreach ($variants as $v) {
    $variantId = $v['id'] ?? null;
    if ($variantId) $frontendVariantIds[] = $variantId;

    $vname = $v['name'] ?? '';
    $vname_hi = $v['name_hi'] ?? '';
    $vname_hn = $v['name_hn'] ?? '';
    $price = $v['price'] ?? 0;
    $selling_price = $v['selling_price'] ?? 0;
    $wholesale_price = $v['wholesale_price'] ?? 0;
    $stock = $v['stock_quantity'] ?? 0;

    if (empty($vname_hi) || empty($vname_hn)) {
        $t_vname = auto_translate_field($vname);
        if (empty($vname_hi)) $vname_hi = $t_vname['hi'];
        if (empty($vname_hn)) $vname_hn = $t_vname['hn'];
    }

    if ($variantId) {
        $stmt = $conn->prepare("UPDATE product_variants 
            SET name=?, name_hi=?, name_hn=?, price=?, selling_price=?, wholesale_price=?, stock=? 
            WHERE id=? AND product_id=?");
        $stmt->bind_param("sssdddiii", $vname, $vname_hi, $vname_hn, $price, $selling_price, $wholesale_price, $stock, $variantId, $product_id);
        $stmt->execute();
        $stmt->close();
    } else {
        $stmt = $conn->prepare("INSERT INTO product_variants 
            (product_id, name, name_hi, name_hn, price, selling_price, wholesale_price, stock) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("isssdddi", $product_id, $vname, $vname_hi, $vname_hn, $price, $selling_price, $wholesale_price, $stock);
        $stmt->execute();
        $stmt->close();
    }
}
// Delete removed variants
$toDeleteVariants = array_diff($existingVariantIds, array_filter($frontendVariantIds));
if (!empty($toDeleteVariants)) {
    $ids = implode(",", $toDeleteVariants);
    $conn->query("DELETE FROM product_variants WHERE id IN ($ids) AND product_id = $product_id");
}

// Step 4: Info
$existingInfoIds = [];
$res = $conn->query("SELECT id FROM product_info WHERE product_id = $product_id");
while ($row = $res->fetch_assoc()) { $existingInfoIds[] = $row['id']; }

$frontendInfoIds = [];
foreach ($info as $i) {
    $infoId = $i['id'] ?? null;
    if ($infoId) $frontendInfoIds[] = $infoId;

    $attr = $i['attribute'] ?? '';
    $attr_hi = $i['attribute_hi'] ?? '';
    $attr_hn = $i['attribute_hn'] ?? '';
    $val = $i['value'] ?? '';
    $val_hi = $i['value_hi'] ?? '';
    $val_hn = $i['value_hn'] ?? '';

    if (empty($attr_hi) || empty($attr_hn)) {
        $t_attr = auto_translate_field($attr);
        if (empty($attr_hi)) $attr_hi = $t_attr['hi'];
        if (empty($attr_hn)) $attr_hn = $t_attr['hn'];
    }
    if (empty($val_hi) || empty($val_hn)) {
        $t_val = auto_translate_field($val);
        if (empty($val_hi)) $val_hi = $t_val['hi'];
        if (empty($val_hn)) $val_hn = $t_val['hn'];
    }

    if ($infoId) {
        $stmt = $conn->prepare("UPDATE product_info SET attribute=?, attribute_hi=?, attribute_hn=?, value=?, value_hi=?, value_hn=? WHERE id=? AND product_id=?");
        $stmt->bind_param("ssssssii", $attr, $attr_hi, $attr_hn, $val, $val_hi, $val_hn, $infoId, $product_id);
        $stmt->execute();
        $stmt->close();
    } else {
        $stmt = $conn->prepare("INSERT INTO product_info (product_id, attribute, attribute_hi, attribute_hn, value, value_hi, value_hn) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("issssss", $product_id, $attr, $attr_hi, $attr_hn, $val, $val_hi, $val_hn);
        $stmt->execute();
        $stmt->close();
    }
}
// Delete removed info
$toDeleteInfo = array_diff($existingInfoIds, array_filter($frontendInfoIds));
if (!empty($toDeleteInfo)) {
    $ids = implode(",", $toDeleteInfo);
    $conn->query("DELETE FROM product_info WHERE id IN ($ids) AND product_id = $product_id");
}

// Step 5: Highlights
$existingHighlightIds = [];
$res = $conn->query("SELECT id FROM product_highlights WHERE product_id = $product_id");
while ($row = $res->fetch_assoc()) { $existingHighlightIds[] = $row['id']; }

$frontendHighlightIds = [];
foreach ($highlights as $h) {
    $highlightId = $h['id'] ?? null;
    if ($highlightId) $frontendHighlightIds[] = $highlightId;

    $attr = $h['attribute'] ?? '';
    $attr_hi = $h['attribute_hi'] ?? '';
    $attr_hn = $h['attribute_hn'] ?? '';
    $val = $h['value'] ?? '';
    $val_hi = $h['value_hi'] ?? '';
    $val_hn = $h['value_hn'] ?? '';

    if (empty($attr_hi) || empty($attr_hn)) {
        $t_attr = auto_translate_field($attr);
        if (empty($attr_hi)) $attr_hi = $t_attr['hi'];
        if (empty($attr_hn)) $attr_hn = $t_attr['hn'];
    }
    if (empty($val_hi) || empty($val_hn)) {
        $t_val = auto_translate_field($val);
        if (empty($val_hi)) $val_hi = $t_val['hi'];
        if (empty($val_hn)) $val_hn = $t_val['hn'];
    }

    if ($highlightId) {
        $stmt = $conn->prepare("UPDATE product_highlights SET attribute=?, attribute_hi=?, attribute_hn=?, value=?, value_hi=?, value_hn=? WHERE id=? AND product_id=?");
        $stmt->bind_param("ssssssii", $attr, $attr_hi, $attr_hn, $val, $val_hi, $val_hn, $highlightId, $product_id);
        $stmt->execute();
        $stmt->close();
    } else {
        $stmt = $conn->prepare("INSERT INTO product_highlights (product_id, attribute, attribute_hi, attribute_hn, value, value_hi, value_hn) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("issssss", $product_id, $attr, $attr_hi, $attr_hn, $val, $val_hi, $val_hn);
        $stmt->execute();
        $stmt->close();
    }
}
// Delete removed highlights
$toDeleteHighlights = array_diff($existingHighlightIds, array_filter($frontendHighlightIds));
if (!empty($toDeleteHighlights)) {
    $ids = implode(",", $toDeleteHighlights);
    $conn->query("DELETE FROM product_highlights WHERE id IN ($ids) AND product_id = $product_id");
}

// Step 6: Images
if (is_array($imageUrls)) {
    $existingImages = [];
    $res = $conn->query("SELECT image_url FROM product_images WHERE product_id = $product_id");
    while ($row = $res->fetch_assoc()) { $existingImages[] = $row['image_url']; }

    $toDelete = array_diff($existingImages, $imageUrls);

    foreach ($toDelete as $delUrl) {
        $stmt = $conn->prepare("DELETE FROM product_images WHERE product_id = ? AND image_url = ?");
        $stmt->bind_param("is", $product_id, $delUrl);
        $stmt->execute();
        $stmt->close();

        $filePath = "../../uploads/" . basename($delUrl);
        if (file_exists($filePath)) { unlink($filePath); }
    }
}

echo json_encode(['success' => true, 'message' => 'Product updated successfully']);
