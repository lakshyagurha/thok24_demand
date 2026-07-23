<?php

include '../connection.php';

if(isset($_POST['id'])){
    $id = $_POST['id'];
} else {
    return;
}

// पहले इमेज का पाथ निकालें
$query = "SELECT banner_image FROM banner WHERE id = '$id'";
$result = mysqli_query($conn, $query);
$row = mysqli_fetch_assoc($result);

if ($row) {
    $imagePath = $row['banner_image'];

    // इमेज फाइल को डिलीट करें
    if (file_exists($imagePath)) {
        unlink($imagePath);
    }

    // अब डेटाबेस से एंट्री हटाएं
    $deleteQuery = "DELETE FROM banner WHERE id = '$id'";
    $exe = mysqli_query($conn, $deleteQuery);

    $arr = [];
    if ($exe) {
        $arr["success"] = "true";
    } else {
        $arr["success"] = "false";
    }

    print(json_encode($arr));
} else {
    echo json_encode(["success" => "false", "message" => "offer banner not found"]);
}

?>
