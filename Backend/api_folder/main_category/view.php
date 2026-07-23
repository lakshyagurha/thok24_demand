<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");



include '../connection.php';

$lang = isset($_GET['lang']) ? trim($_GET['lang']) : '';
if (!in_array($lang, ['en', 'hi', 'hn'])) {
    $lang = '';
}

$query = "SELECT * FROM main_category";
$exe = mysqli_query($conn, $query);

$arr = [];

while ($row = mysqli_fetch_assoc($exe)) {
    if (!empty($lang) && $lang !== 'en') {
        $col = "name_" . $lang;
        if (isset($row[$col]) && !empty(trim($row[$col]))) {
            $row['name'] = $row[$col];
        }
    }
    $arr[] = $row;
}

echo json_encode($arr);
?>
