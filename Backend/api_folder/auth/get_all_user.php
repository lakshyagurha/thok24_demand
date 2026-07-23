<?php
include '../connection.php';
header('Content-Type: application/json');

$limit = isset($_GET['limit']) ? intval($_GET['limit']) : 10;
$offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
$search = isset($_GET['search']) ? trim($_GET['search']) : '';

// Build WHERE clause
$where = "";
if (!empty($search)) {
    $search = mysqli_real_escape_string($conn, $search);
    $where = "WHERE name LIKE '%$search%' OR email LIKE '%$search%'";
}

// Get total user count with filter
$countQuery = "SELECT COUNT(*) AS total FROM users $where";
$countResult = mysqli_query($conn, $countQuery);
$totalRow = mysqli_fetch_assoc($countResult);
$total = isset($totalRow['total']) ? (int)$totalRow['total'] : 0;

// Fetch users
$query = "SELECT id, name, email, status, date_time FROM users $where ORDER BY id ASC LIMIT $limit OFFSET $offset";
$result = mysqli_query($conn, $query);

$users = [];
while ($row = mysqli_fetch_assoc($result)) {
    $row['id'] = (int)$row['id']; // force ID to be integer
    $users[] = $row;
}

// Return response
echo json_encode([
    "success" => true,
    "users" => $users,
    "total" => $total
]);
?>
