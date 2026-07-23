<?php

$servername = "localhost"; 
$username = "root";
$password = "";
$database = "dxmart";

// Connection bana rahe hain
$conn = new mysqli($servername, $username, $password, $database);

// Connection check kar rahe hain
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// echo "Database connected successfully";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");



// Yahan se aage tum queries likh sakte ho

?>





