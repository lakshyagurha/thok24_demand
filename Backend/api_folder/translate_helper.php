<?php
/**
 * Translation Helper for Multilingual support.
 * Uses free Google Translate cURL APIs for translation (English -> Hindi)
 * and transliteration (Hindi -> Hinglish).
 */

function translate_text($text, $from = 'en', $to = 'hi') {
    $text = trim($text);
    if (empty($text)) return '';
    
    // If text is purely numeric or special characters, return as is
    if (is_numeric($text)) return $text;

    $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" . $from . "&tl=" . $to . "&dt=t&q=" . urlencode($text);
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36");
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    $response = curl_exec($ch);
    curl_close($ch);
    
    if ($response) {
        $result = json_decode($response, true);
        if (isset($result[0]) && is_array($result[0])) {
            $translated = '';
            foreach ($result[0] as $sentence) {
                if (isset($sentence[0])) {
                    $translated .= $sentence[0];
                }
            }
            if (!empty($translated)) {
                return trim($translated);
            }
        }
    }
    return $text; // Fallback to original text if translation failed
}

function transliterate_hindi_to_hinglish($hindi_text) {
    $hindi_text = trim($hindi_text);
    if (empty($hindi_text)) return '';
    if (is_numeric($hindi_text)) return $hindi_text;

    $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=hi&tl=en&dt=rm&q=" . urlencode($hindi_text);
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36");
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    $response = curl_exec($ch);
    curl_close($ch);
    
    if ($response) {
        $result = json_decode($response, true);
        if (isset($result[0]) && is_array($result[0])) {
            $transliteration = '';
            foreach ($result[0] as $part) {
                if (isset($part[3])) {
                    $transliteration .= $part[3];
                }
            }
            if (!empty($transliteration)) {
                return trim($transliteration);
            }
        }
    }
    return $hindi_text; // Fallback
}

/**
 * Convenience function to auto-generate translation & transliteration.
 * Returns array: ['hi' => 'translated_text', 'hn' => 'transliterated_text']
 */
function auto_translate_field($english_text) {
    $english_text = trim($english_text);
    if (empty($english_text)) {
        return ['hi' => '', 'hn' => ''];
    }
    
    // Step 1: English -> Hindi
    $hindi = translate_text($english_text, 'en', 'hi');
    usleep(50000); // 50ms delay to prevent rate limit
    
    // Step 2: Hindi -> Hinglish (transliteration)
    $hinglish = transliterate_hindi_to_hinglish($hindi);
    usleep(50000); // 50ms delay
    
    return [
        'hi' => $hindi,
        'hn' => $hinglish
    ];
}
?>
