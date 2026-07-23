<?php
/**
 * Auto-Translate API endpoint for Admin Panel.
 * Receives English text and returns Hindi & Hinglish translations.
 */

include '../../connection.php';
include '../../translate_helper.php';

header('Content-Type: application/json');

// Get inputs from GET or POST
$text = isset($_REQUEST['text']) ? trim($_REQUEST['text']) : '';

if (empty($text)) {
    echo json_encode([
        'success' => false,
        'message' => 'Text parameter is required'
    ]);
    exit;
}

// Perform translation & transliteration
$translations = auto_translate_field($text);

echo json_encode([
    'success' => true,
    'original' => $text,
    'hi' => $translations['hi'],
    'hn' => $translations['hn']
]);
?>
