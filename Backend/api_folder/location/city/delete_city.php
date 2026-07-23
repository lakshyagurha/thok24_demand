<?php

include '../../connection.php';

// Check if state_id is provided
if (isset($_POST['city_id'])) {
    $city_id = $_POST['city_id'];

    // Prepare the DELETE query
    $query = "DELETE FROM city WHERE id = '$city_id'";

    // Execute the query
    $exe = mysqli_query($conn, $query);

    // Check if the query was successful
    if ($exe) {
        // Return success response
        $arr["success"] = "true";
        $arr["message"] = "State deleted successfully";
    } else {
        // Return failure response
        $arr["success"] = "false";
        $arr["message"] = "Failed to delete state";
    }
} else {
    // If state_id is not provided
    $arr["success"] = "false";
    $arr["message"] = "State ID not provided";
}

// Return the response as JSON
print(json_encode($arr));

?>
