<?php
/**
 * Database Migration and Backfill Script.
 * Runs SQL alterations to add translation columns (if they don't exist)
 * and backfills all existing English categories, products, and details.
 */

include 'connection.php';
include 'translate_helper.php';

header('Content-Type: application/json');

// Disable execution time limit for bulk translation
set_time_limit(0);

$response = [
    'success' => true,
    'steps' => [],
    'errors' => []
];

// Helper to run query and log success/failure
function run_query($conn, $sql, $label, &$response) {
    try {
        if ($conn->query($sql)) {
            $response['steps'][] = "$label: Success";
        } else {
            // If error is "Duplicate column name", ignore it
            if ($conn->errno == 1060) {
                $response['steps'][] = "$label: Already exists (Skipped)";
            } else {
                $response['steps'][] = "$label: Failed - " . $conn->error;
                $response['errors'][] = "$label: " . $conn->error;
            }
        }
    } catch (mysqli_sql_exception $e) {
        if ($e->getCode() == 1060 || $conn->errno == 1060 || strpos($e->getMessage(), 'Duplicate column') !== false) {
            $response['steps'][] = "$label: Already exists (Skipped)";
        } else {
            $response['steps'][] = "$label: Failed - " . $e->getMessage();
            $response['errors'][] = "$label: " . $e->getMessage();
        }
    } catch (Exception $e) {
        $response['steps'][] = "$label: Failed - " . $e->getMessage();
        $response['errors'][] = "$label: " . $e->getMessage();
    }
}

// ================= STEP 1: ALTER SCHEMAS =================

$response['steps'][] = "--- Executing Alter Table Queries ---";

// main_category
run_query($conn, "ALTER TABLE `main_category` ADD COLUMN `name_hi` varchar(255) DEFAULT NULL AFTER `name` ;", "category name_hi", $response);
run_query($conn, "ALTER TABLE `main_category` ADD COLUMN `name_hn` varchar(255) DEFAULT NULL AFTER `name_hi`;", "category name_hn", $response);

// products
run_query($conn, "ALTER TABLE `products` ADD COLUMN `name_hi` varchar(255) DEFAULT NULL AFTER `name`;", "products name_hi", $response);
run_query($conn, "ALTER TABLE `products` ADD COLUMN `name_hn` varchar(255) DEFAULT NULL AFTER `name_hi`;", "products name_hn", $response);
run_query($conn, "ALTER TABLE `products` ADD COLUMN `description_hi` text DEFAULT NULL AFTER `description`;", "products description_hi", $response);
run_query($conn, "ALTER TABLE `products` ADD COLUMN `description_hn` text DEFAULT NULL AFTER `description_hi`;", "products description_hn", $response);

// product_variants
run_query($conn, "ALTER TABLE `product_variants` ADD COLUMN `name_hi` varchar(100) DEFAULT NULL AFTER `name`;", "product_variants name_hi", $response);
run_query($conn, "ALTER TABLE `product_variants` ADD COLUMN `name_hn` varchar(100) DEFAULT NULL AFTER `name_hi`;", "product_variants name_hn", $response);

// product_info
run_query($conn, "ALTER TABLE `product_info` ADD COLUMN `attribute_hi` text DEFAULT NULL AFTER `attribute`;", "product_info attribute_hi", $response);
run_query($conn, "ALTER TABLE `product_info` ADD COLUMN `attribute_hn` text DEFAULT NULL AFTER `attribute_hi`;", "product_info attribute_hn", $response);
run_query($conn, "ALTER TABLE `product_info` ADD COLUMN `value_hi` text DEFAULT NULL AFTER `value`;", "product_info value_hi", $response);
run_query($conn, "ALTER TABLE `product_info` ADD COLUMN `value_hn` text DEFAULT NULL AFTER `value_hi`;", "product_info value_hn", $response);

// product_highlights
run_query($conn, "ALTER TABLE `product_highlights` ADD COLUMN `attribute_hi` text DEFAULT NULL AFTER `attribute`;", "product_highlights attribute_hi", $response);
run_query($conn, "ALTER TABLE `product_highlights` ADD COLUMN `attribute_hn` text DEFAULT NULL AFTER `attribute_hi`;", "product_highlights attribute_hn", $response);
run_query($conn, "ALTER TABLE `product_highlights` ADD COLUMN `value_hi` text DEFAULT NULL AFTER `value`;", "product_highlights value_hi", $response);
run_query($conn, "ALTER TABLE `product_highlights` ADD COLUMN `value_hn` text DEFAULT NULL AFTER `value_hi`;", "product_highlights value_hn", $response);


// ================= STEP 2: BACKFILL TRANSLATIONS =================

$response['steps'][] = "--- Backfilling Translations ---";

// 1. Categories
$categories_count = 0;
$res = $conn->query("SELECT id, name, name_hi, name_hn FROM main_category");
while ($row = $res->fetch_assoc()) {
    if (empty($row['name_hi']) || empty($row['name_hn'])) {
        try {
            $trans = auto_translate_field($row['name']);
            $stmt = $conn->prepare("UPDATE main_category SET name_hi = ?, name_hn = ? WHERE id = ?");
            $stmt->bind_param("ssi", $trans['hi'], $trans['hn'], $row['id']);
            $stmt->execute();
            $stmt->close();
            $categories_count++;
        } catch (Exception $e) {
            $response['errors'][] = "Category {$row['id']} failed: " . $e->getMessage();
        }
    }
}
$response['steps'][] = "Categories backfilled: $categories_count";

// 2. Products
$products_count = 0;
$res = $conn->query("SELECT id, name, name_hi, name_hn, description, description_hi, description_hn FROM products");
while ($row = $res->fetch_assoc()) {
    $needs_update = false;
    $name_hi = $row['name_hi'];
    $name_hn = $row['name_hn'];
    $desc_hi = $row['description_hi'];
    $desc_hn = $row['description_hn'];

    try {
        if (empty($name_hi) || empty($name_hn)) {
            $t_name = auto_translate_field($row['name']);
            $name_hi = $t_name['hi'];
            $name_hn = $t_name['hn'];
            $needs_update = true;
        }

        if (empty($desc_hi) || empty($desc_hn)) {
            $t_desc = auto_translate_field($row['description']);
            $desc_hi = $t_desc['hi'];
            $desc_hn = $t_desc['hn'];
            $needs_update = true;
        }

        if ($needs_update) {
            $stmt = $conn->prepare("UPDATE products SET name_hi = ?, name_hn = ?, description_hi = ?, description_hn = ? WHERE id = ?");
            $stmt->bind_param("ssssi", $name_hi, $name_hn, $desc_hi, $desc_hn, $row['id']);
            $stmt->execute();
            $stmt->close();
            $products_count++;
        }
    } catch (Exception $e) {
        $response['errors'][] = "Product {$row['id']} failed: " . $e->getMessage();
    }
}
$response['steps'][] = "Products backfilled: $products_count";

// 3. Variants
$variants_count = 0;
$res = $conn->query("SELECT id, name, name_hi, name_hn FROM product_variants");
while ($row = $res->fetch_assoc()) {
    if (empty($row['name_hi']) || empty($row['name_hn'])) {
        try {
            $trans = auto_translate_field($row['name']);
            $stmt = $conn->prepare("UPDATE product_variants SET name_hi = ?, name_hn = ? WHERE id = ?");
            $stmt->bind_param("ssi", $trans['hi'], $trans['hn'], $row['id']);
            $stmt->execute();
            $stmt->close();
            $variants_count++;
        } catch (Exception $e) {
            $response['errors'][] = "Variant {$row['id']} failed: " . $e->getMessage();
        }
    }
}
$response['steps'][] = "Variants backfilled: $variants_count";

// 4. Info
$info_count = 0;
$res = $conn->query("SELECT id, attribute, attribute_hi, attribute_hn, value, value_hi, value_hn FROM product_info");
while ($row = $res->fetch_assoc()) {
    $needs_update = false;
    $attr_hi = $row['attribute_hi'];
    $attr_hn = $row['attribute_hn'];
    $val_hi = $row['value_hi'];
    $val_hn = $row['value_hn'];

    try {
        if (empty($attr_hi) || empty($attr_hn)) {
            $t_attr = auto_translate_field($row['attribute']);
            $attr_hi = $t_attr['hi'];
            $attr_hn = $t_attr['hn'];
            $needs_update = true;
        }

        if (empty($val_hi) || empty($val_hn)) {
            $t_val = auto_translate_field($row['value']);
            $val_hi = $t_val['hi'];
            $val_hn = $t_val['hn'];
            $needs_update = true;
        }

        if ($needs_update) {
            $stmt = $conn->prepare("UPDATE product_info SET attribute_hi = ?, attribute_hn = ?, value_hi = ?, value_hn = ? WHERE id = ?");
            $stmt->bind_param("ssssi", $attr_hi, $attr_hn, $val_hi, $val_hn, $row['id']);
            $stmt->execute();
            $stmt->close();
            $info_count++;
        }
    } catch (Exception $e) {
        $response['errors'][] = "Info item {$row['id']} failed: " . $e->getMessage();
    }
}
$response['steps'][] = "Product Info items backfilled: $info_count";

// 5. Highlights
$highlights_count = 0;
$res = $conn->query("SELECT id, attribute, attribute_hi, attribute_hn, value, value_hi, value_hn FROM product_highlights");
while ($row = $res->fetch_assoc()) {
    $needs_update = false;
    $attr_hi = $row['attribute_hi'];
    $attr_hn = $row['attribute_hn'];
    $val_hi = $row['value_hi'];
    $val_hn = $row['value_hn'];

    try {
        if (empty($attr_hi) || empty($attr_hn)) {
            $t_attr = auto_translate_field($row['attribute']);
            $attr_hi = $t_attr['hi'];
            $attr_hn = $t_attr['hn'];
            $needs_update = true;
        }

        if (empty($val_hi) || empty($val_hn)) {
            $t_val = auto_translate_field($row['value']);
            $val_hi = $t_val['hi'];
            $val_hn = $t_val['hn'];
            $needs_update = true;
        }

        if ($needs_update) {
            $stmt = $conn->prepare("UPDATE product_highlights SET attribute_hi = ?, attribute_hn = ?, value_hi = ?, value_hn = ? WHERE id = ?");
            $stmt->bind_param("ssssi", $attr_hi, $attr_hn, $val_hi, $val_hn, $row['id']);
            $stmt->execute();
            $stmt->close();
            $highlights_count++;
        }
    } catch (Exception $e) {
        $response['errors'][] = "Highlight {$row['id']} failed: " . $e->getMessage();
    }
}
$response['steps'][] = "Product Highlights backfilled: $highlights_count";

echo json_encode($response);
?>
