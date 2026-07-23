<?php
// This script runs in background, so no output should be sent
// Errors can be logged but not shown to user

// Enable error logging for debugging (remove in production if needed)
ini_set('log_errors', 1);
ini_set('error_log', 'email_errors.log');

// Include PHPMailer files with correct paths
require_once __DIR__ . '/PHPMailer/PHPMailer.php';
require_once __DIR__ . '/PHPMailer/SMTP.php';
require_once __DIR__ . '/PHPMailer/Exception.php';

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// Get POST data from main script
$data = $_POST;

// Extract and validate data
$user_email = isset($data['user_email']) ? filter_var($data['user_email'], FILTER_SANITIZE_EMAIL) : null;
$user_name = isset($data['user_name']) ? htmlspecialchars($data['user_name']) : null;
$order_id = isset($data['order_id']) ? (int)$data['order_id'] : 0;
$dateTimeNow = isset($data['dateTimeNow']) ? htmlspecialchars($data['dateTimeNow']) : 'N/A';
$deliveryDate = isset($data['deliveryDate']) ? htmlspecialchars($data['deliveryDate']) : 'N/A';
$deliverTime = isset($data['deliverTime']) ? htmlspecialchars($data['deliverTime']) : 'N/A';
$payment_method = isset($data['payment_method']) ? htmlspecialchars($data['payment_method']) : 'COD';
$address = isset($data['address']) ? $data['address'] : 'N/A';
$cart_items = isset($data['cart_items']) ? json_decode($data['cart_items'], true) : [];
$cart_total = isset($data['cart_total']) ? (float)$data['cart_total'] : 0;
$discount_amount = isset($data['discount_amount']) ? (float)$data['discount_amount'] : 0;
$delivery_charge = isset($data['delivery_charge']) ? (float)$data['delivery_charge'] : 0;
$handling_charge = isset($data['handling_charge']) ? (float)$data['handling_charge'] : 0;
$final_amount = isset($data['final_amount']) ? (float)$data['final_amount'] : 0;
$company_email = isset($data['company_email']) ? filter_var($data['company_email'], FILTER_SANITIZE_EMAIL) : null;
$email_type = isset($data['email_type']) ? $data['email_type'] : 'user';

// Function to send email
function sendOrderMail($to, $subject, $body, $from_email, $from_name = 'Digixcode') {
    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host       = 'smtp.gmail.com';  
        $mail->SMTPAuth   = true;
        $mail->Username   = 'digixcde.pab@gmail.com'; // Your company email
        $mail->Password   = 'iykqneuhvgukqud';  // Gmail App Password
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = 587;

        $mail->setFrom($from_email, $from_name);
        $mail->addAddress($to);

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body    = $body;
        $mail->AltBody = strip_tags($body);

        $mail->send();
        error_log("Email successfully sent to: $to");
        return true;
    } catch (Exception $e) {
        error_log("Email sending failed to $to: " . $mail->ErrorInfo);
        return false;
    }
}

// Professional email template function
function generateEmailTemplate($data, $type = 'user') {
    if ($type === 'user') {
        $template = '
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Order Confirmation</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 0;
                    background-color: #f9f9f9;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    background-color: #ffffff;
                    padding: 20px;
                    border: 1px solid #ddd;
                    border-radius: 5px;
                }
                .header {
                    text-align: center;
                    padding-bottom: 20px;
                    border-bottom: 1px solid #eee;
                }
                .header h1 {
                    color: #2c3e50;
                    margin: 0;
                }
                .order-details, .order-items, .order-summary {
                    margin: 20px 0;
                    padding: 15px;
                    background-color: #f8f9fa;
                    border-radius: 5px;
                }
                .order-item {
                    padding: 10px;
                    border-bottom: 1px solid #eee;
                }
                .order-item:last-child {
                    border-bottom: none;
                }
                .total-amount {
                    font-size: 18px;
                    font-weight: bold;
                    color: #27ae60;
                    margin-top: 10px;
                    padding-top: 10px;
                    border-top: 1px solid #ddd;
                }
                .footer {
                    margin-top: 30px;
                    padding-top: 20px;
                    border-top: 1px solid #eee;
                    text-align: center;
                    color: #7f8c8d;
                    font-size: 14px;
                }
                .highlight {
                    background-color: #f1c40f;
                    padding: 2px 5px;
                    border-radius: 3px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Order Confirmation</h1>
                </div>
                
                <p>Dear ' . htmlspecialchars($data['user_name']) . ',</p>
                <p>Thank you for your order! We are pleased to confirm that we have received your order and it is now being processed.</p>
                
                <div class="order-details">
                    <h2>Order Details</h2>
                    <p><strong>Order ID:</strong> <span class="highlight">#' . $data['order_id'] . '</span></p>
                    <p><strong>Order Date:</strong> ' . $data['dateTimeNow'] . '</p>
                    <p><strong>Payment Method:</strong> ' . $data['payment_method'] . '</p>
                    <p><strong>Delivery Date:</strong> ' . $data['deliveryDate'] . ' at ' . $data['deliverTime'] . '</p>
                    <p><strong>Delivery Address:</strong><br>' . nl2br(htmlspecialchars($data['address'])) . '</p>
                </div>
                
                <div class="order-items">
                    <h2>Ordered Items</h2>';
        
        foreach ($data['cart_items'] as $item) {
            $template .= '
                    <div class="order-item">
                        <p><strong>' . htmlspecialchars($item['product_name']) . '</strong></p>
                        <p>Quantity: ' . $item['quantity'] . ' × ₹' . number_format($item['price'], 2) . '</p>
                    </div>';
        }
        
        $template .= '
                </div>
                
                <div class="order-summary">
                    <h2>Order Summary</h2>
                    <p><strong>Subtotal:</strong> ₹' . number_format($data['cart_total'], 2) . '</p>';
        
        if ($data['discount_amount'] > 0) {
            $template .= '<p><strong>Discount:</strong> -₹' . number_format($data['discount_amount'], 2) . '</p>';
        }
        
        $template .= '
                    <p><strong>Delivery Charge:</strong> ₹' . number_format($data['delivery_charge'], 2) . '</p>
                    <p><strong>Handling Charge:</strong> ₹' . number_format($data['handling_charge'], 2) . '</p>
                    <div class="total-amount">
                        <strong>Total Amount: ₹' . number_format($data['final_amount'], 2) . '</strong>
                    </div>
                </div>
                
                <p>We will notify you once your order has been shipped. If you have any questions about your order, please contact our customer service team.</p>
                
                <div class="footer">
                    <p>Thank you for shopping with us!</p>
                    <p>© ' . date('Y') . ' Digixcode. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>';
        
        return $template;
    } else {
        // Company email template
        $template = '
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>New Order Notification</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    margin: 0;
                    padding: 0;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                }
                .header {
                    text-align: center;
                    padding-bottom: 20px;
                    border-bottom: 1px solid #eee;
                }
                .order-details {
                    margin: 20px 0;
                    padding: 15px;
                    background-color: #f8f9fa;
                    border-radius: 5px;
                }
                .order-items {
                    margin: 20px 0;
                }
                .order-item {
                    padding: 10px;
                    border-bottom: 1px solid #eee;
                }
                .highlight {
                    background-color: #f1c40f;
                    padding: 2px 5px;
                    border-radius: 3px;
                }
                .urgent {
                    color: #e74c3c;
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>New Order Received</h1>
                </div>
                
                <div class="order-details">
                    <h2>Order Details</h2>
                    <p><strong>Order ID:</strong> <span class="highlight">#' . $data['order_id'] . '</span></p>
                    <p><strong>Customer:</strong> ' . htmlspecialchars($data['user_name']) . ' (' . htmlspecialchars($data['user_email']) . ')</p>
                    <p><strong>Order Date:</strong> ' . htmlspecialchars($data['dateTimeNow']) . '</p>
                    <p><strong>Payment Method:</strong> ' . htmlspecialchars($data['payment_method']) . '</p>
                    <p><strong>Delivery Date:</strong> ' . htmlspecialchars($data['deliveryDate']) . ' at ' . htmlspecialchars($data['deliverTime']) . '</p>
                    <p><strong>Delivery Address:</strong><br>' . nl2br(htmlspecialchars($data['address'])) . '</p>
                    <p class="urgent"><strong>Total Amount:</strong> ₹' . number_format($data['final_amount'], 2) . '</p>
                </div>
                
                <div class="order-items">
                    <h2>Ordered Items</h2>';
        
        foreach ($data['cart_items'] as $item) {
            $template .= '
                    <div class="order-item">
                        <p><strong>' . htmlspecialchars($item['product_name']) . '</strong></p>
                        <p>Quantity: ' . $item['quantity'] . ' × ₹' . number_format($item['price'], 2) . '</p>
                    </div>';
        }
        
        $template .= '
                </div>
                
                <p>This order requires your attention. Please process it according to the delivery schedule.</p>
            </div>
        </body>
        </html>';
        
        return $template;
    }
}

// Process both user and company emails
if ($user_email) {
    $user_template = generateEmailTemplate([
        'user_name' => $user_name,
        'order_id' => $order_id,
        'dateTimeNow' => $dateTimeNow,
        'payment_method' => $payment_method,
        'deliveryDate' => $deliveryDate,
        'deliverTime' => $deliverTime,
        'address' => $address,
        'cart_items' => $cart_items,
        'cart_total' => $cart_total,
        'discount_amount' => $discount_amount,
        'delivery_charge' => $delivery_charge,
        'handling_charge' => $handling_charge,
        'final_amount' => $final_amount
    ], 'user');
    
    sendOrderMail($user_email, "Your Order Confirmation - #$order_id", $user_template, $company_email);
}

if ($company_email) {
    $company_template = generateEmailTemplate([
        'user_name' => $user_name,
        'user_email' => $user_email,
        'order_id' => $order_id,
        'dateTimeNow' => $dateTimeNow,
        'payment_method' => $payment_method,
        'deliveryDate' => $deliveryDate,
        'deliverTime' => $deliverTime,
        'address' => $address,
        'cart_items' => $cart_items,
        'final_amount' => $final_amount
    ], 'company');
    
    sendOrderMail($company_email, "New Order Received - #$order_id", $company_template, $company_email);
}

// Log completion
error_log("Background email processing completed for order: #$order_id");
?>