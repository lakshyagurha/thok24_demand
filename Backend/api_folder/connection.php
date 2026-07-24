<?php

// Connection settings come from the environment, with local XAMPP dev defaults.
// The local development database is `thok24` — the old "dxmart" name does not exist here.
$servername = getenv('DB_HOST') ?: "localhost";
$username   = getenv('DB_USER') ?: "root";
$password   = getenv('DB_PASSWORD') ?: "";
$database   = getenv('DB_NAME') ?: "thok24";

// Connection bana rahe hain
$conn = new mysqli($servername, $username, $password, $database);

// Connection check kar rahe hain
if ($conn->connect_error) {
    // Don't leak connection internals (host, user, DB name) to the client.
    error_log("DB connection failed: " . $conn->connect_error);
    http_response_code(500);
    die(json_encode(["status" => "error", "message" => "Database unavailable"]));
}

// Hindi/Devanagari product names require utf8mb4 on the connection itself.
$conn->set_charset("utf8mb4");

// echo "Database connected successfully";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Access-Control-Allow-Headers: Content-Type");



// Yahan se aage tum queries likh sakte ho

// Deliberately no closing PHP tag. Any trailing whitespace after one would be
// emitted into every response that includes this file, prepending blank lines
// to the JSON body.

