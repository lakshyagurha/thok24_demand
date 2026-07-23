-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jan 03, 2026 at 08:17 AM
-- Server version: 11.4.9-MariaDB
-- PHP Version: 8.4.16

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `digixcod_dxmart`
--

-- --------------------------------------------------------

--
-- Table structure for table `admin`
--

CREATE TABLE `admin` (
  `id` int(11) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(100) NOT NULL,
  `current_time` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `admin`
--

INSERT INTO `admin` (`id`, `email`, `password`, `current_time`) VALUES
(1, 'dxmart@gmail.com', 'Dxmart49011', '2025-04-29 08:57:12');

-- --------------------------------------------------------

--
-- Table structure for table `banner`
--

CREATE TABLE `banner` (
  `id` int(11) NOT NULL,
  `category_id` int(11) NOT NULL,
  `banner_image` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `banner`
--

INSERT INTO `banner` (`id`, `category_id`, `banner_image`) VALUES
(3, 5, 'banner/banner_image_1765649426959.png'),
(4, 6, 'banner/banner_image_1765649438024.png'),
(5, 9, 'banner/banner_image_1765649446242.png'),
(6, 23, 'banner/banner_image_1765810375429.png'),
(7, 23, 'banner/banner_image_1765810386127.png'),
(8, 30, 'banner/banner_image_1765810396522.png');

-- --------------------------------------------------------

--
-- Table structure for table `cart_items`
--

CREATE TABLE `cart_items` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `variant_id` int(11) DEFAULT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `image_url` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `city`
--

CREATE TABLE `city` (
  `id` int(11) NOT NULL,
  `district_id` int(10) NOT NULL,
  `city_name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `city`
--

INSERT INTO `city` (`id`, `district_id`, `city_name`) VALUES
(10, 15, 'Lalpur'),
(40, 15, 'Khuti'),
(41, 15, 'Kata Toli');

-- --------------------------------------------------------

--
-- Table structure for table `coupon`
--

CREATE TABLE `coupon` (
  `id` int(11) NOT NULL,
  `title` varchar(50) NOT NULL,
  `description` varchar(50) NOT NULL,
  `code_name` varchar(50) NOT NULL,
  `discount` int(10) NOT NULL,
  `expri_date` varchar(50) NOT NULL,
  `status` varchar(20) NOT NULL,
  `min_amount` int(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `coupon`
--

INSERT INTO `coupon` (`id`, `title`, `description`, `code_name`, `discount`, `expri_date`, `status`, `min_amount`) VALUES
(2, 'First Purchase', '5% off for your first order', 'FIRST5KBF', 5, '12-10-2025', 'Public', 500),
(3, 'Holi offer', '20% off this holi', 'HOLI20', 20, '12-07-2025', 'Private', 100),
(4, 'DIPA WALI OFFER', '20% off this holi', 'DIPALI20', 20, '12-08-2025', 'Public', 500),
(5, 'DASHARAH OFFER', '30 % off this dashraha', 'DASHRA30', 30, '12-09-2025', 'Private', 2500);

-- --------------------------------------------------------

--
-- Table structure for table `delivery_address`
--

CREATE TABLE `delivery_address` (
  `id` int(11) NOT NULL,
  `user_id` int(10) NOT NULL,
  `name` varchar(50) NOT NULL,
  `phone` varchar(12) NOT NULL,
  `full_address` varchar(200) NOT NULL,
  `pin_code` varchar(10) NOT NULL,
  `landmark` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `delivery_address`
--

INSERT INTO `delivery_address` (`id`, `user_id`, `name`, `phone`, `full_address`, `pin_code`, `landmark`) VALUES
(1, 1, 'Arvind Kumar', '8102337432', 'Vill - Paroriya, Post - Badgawan, Chatra, Jharkhand', '825408', 'Sun Temple'),
(3, 8, 'sghsh', '96434490655', 'hshsshsh shsj', '274422', 'bbzh'),
(4, 8, 'sghsh', '96434490655', 'hshsshsh shsj', '274422', 'bbzh'),
(6, 4, 'bbhb', '83889958868', 'vyfc', '652888', 'byccbh'),
(7, 3, 'Rakesh Kumar', '9334325149', 'Kankarbagh Patna', '800020', 'Kankarbagh'),
(8, 7, 'haneer', '7006505391', 'handd', '190011', 'hhh'),
(9, 20, 'Arvind Kumar', '8102337432', 'Vill -  Paroriya, Post - Badgwan,', '825408', 'Sun Temple'),
(10, 1, 'Umesh Kumar', '9905814722', 'Vill - Paroriya Post - Badgwan', '825408', 'Sun Temple');

-- --------------------------------------------------------

--
-- Table structure for table `delivery_boy`
--

CREATE TABLE `delivery_boy` (
  `id` int(11) NOT NULL,
  `name` varchar(80) NOT NULL,
  `email` varchar(80) NOT NULL,
  `mobile` varchar(12) NOT NULL,
  `pin_code` varchar(10) NOT NULL,
  `address` varchar(200) NOT NULL,
  `password` varchar(100) NOT NULL,
  `date_time` varchar(50) NOT NULL,
  `status` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `delivery_boy`
--

INSERT INTO `delivery_boy` (`id`, `name`, `email`, `mobile`, `pin_code`, `address`, `password`, `date_time`, `status`) VALUES
(1, 'Rajesh Kumar', 'rajesh49011@gmail.com', '8102337432', '825408', 'Vill - Paroriya, Post - Badgwan, Chatra Jharkhand ', '$2y$10$dFbrnzcNGGET80HVeG3vb.pB8n5KaynhXSIT/KkarAvnS5Yvu/jTm', '14-10-2025 08:24 AM', 'active'),
(2, 'Pankaj Kumar', 'pankajkumar.hzb143@gmail.com', '6205511717', '834002', 'Ranchi', '$2y$10$jJ1R9az46bmCPCu9VEwk1uLaU/Uu3nXqOW2KOTa3tb9eu5HVEuAw.', '29-10-2025 06:54 PM', 'inactive');

-- --------------------------------------------------------

--
-- Table structure for table `delivery_charge`
--

CREATE TABLE `delivery_charge` (
  `id` int(11) NOT NULL,
  `amount` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `delivery_charge`
--

INSERT INTO `delivery_charge` (`id`, `amount`) VALUES
(1, 10);

-- --------------------------------------------------------

--
-- Table structure for table `deliver_time`
--

CREATE TABLE `deliver_time` (
  `id` int(11) NOT NULL,
  `time` varchar(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `deliver_time`
--

INSERT INTO `deliver_time` (`id`, `time`) VALUES
(1, '10 minutes');

-- --------------------------------------------------------

--
-- Table structure for table `delivey_charge`
--

CREATE TABLE `delivey_charge` (
  `id` int(11) NOT NULL,
  `amount` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `delivey_charge`
--

INSERT INTO `delivey_charge` (`id`, `amount`) VALUES
(1, 10);

-- --------------------------------------------------------

--
-- Table structure for table `district`
--

CREATE TABLE `district` (
  `id` int(11) NOT NULL,
  `district_name` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `district`
--

INSERT INTO `district` (`id`, `district_name`) VALUES
(15, 'Ranchi'),
(37, 'Hazaribag'),
(38, 'Chatra');

-- --------------------------------------------------------

--
-- Table structure for table `free_delivey`
--

CREATE TABLE `free_delivey` (
  `id` int(11) NOT NULL,
  `amount` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `free_delivey`
--

INSERT INTO `free_delivey` (`id`, `amount`) VALUES
(1, 500);

-- --------------------------------------------------------

--
-- Table structure for table `handling_charge`
--

CREATE TABLE `handling_charge` (
  `id` int(11) NOT NULL,
  `amount` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `handling_charge`
--

INSERT INTO `handling_charge` (`id`, `amount`) VALUES
(1, 5);

-- --------------------------------------------------------

--
-- Table structure for table `help_call`
--

CREATE TABLE `help_call` (
  `id` int(11) NOT NULL,
  `call_help` varchar(12) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `help_call`
--

INSERT INTO `help_call` (`id`, `call_help`) VALUES
(1, '6205511711');

-- --------------------------------------------------------

--
-- Table structure for table `help_email`
--

CREATE TABLE `help_email` (
  `id` int(11) NOT NULL,
  `email` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `help_email`
--

INSERT INTO `help_email` (`id`, `email`) VALUES
(1, 'support@digixcode.com');

-- --------------------------------------------------------

--
-- Table structure for table `help_whatsapp`
--

CREATE TABLE `help_whatsapp` (
  `id` int(11) NOT NULL,
  `whatsapp_no` varchar(12) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `help_whatsapp`
--

INSERT INTO `help_whatsapp` (`id`, `whatsapp_no`) VALUES
(1, '6205511711');

-- --------------------------------------------------------

--
-- Table structure for table `main_category`
--

CREATE TABLE `main_category` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `image` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `main_category`
--

INSERT INTO `main_category` (`id`, `name`, `image`) VALUES
(23, 'Atta, Rice, Oil & Dals', 'category/category_image_1765819454311.png'),
(24, 'Breakfast & Sauces', 'category/category_image_1765819468154.png'),
(25, 'Dairy, Bread & Eggs', 'category/category_image_1765819489903.png'),
(26, 'Electronics & Appliances', 'category/category_image_1765819514137.png'),
(27, 'Fruits & Vegetables', 'category/category_image_1765819529904.png'),
(28, 'Ice Creams & More', 'category/category_image_1765819544902.png'),
(29, 'Kitchen & Dining', 'category/category_image_1765819558337.png'),
(30, 'Masala & Dry Fruits', 'category/category_image_1765819574804.png'),
(31, 'Frozen Food', 'category/category_image_1765819597788.png'),
(32, 'Sweet Cravings', 'category/category_image_1765819610814.png'),
(33, 'Tea, Coffee & More', 'category/category_image_1765819620434.png'),
(34, 'Packaged Food', 'category/category_image_1765819632367.png');

-- --------------------------------------------------------

--
-- Table structure for table `minimum_order_amout`
--

CREATE TABLE `minimum_order_amout` (
  `id` int(11) NOT NULL,
  `amount` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `minimum_order_amout`
--

INSERT INTO `minimum_order_amout` (`id`, `amount`) VALUES
(1, 50);

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `total_amount` decimal(10,2) NOT NULL,
  `coupon_code` varchar(50) DEFAULT NULL,
  `discount_amount` decimal(10,2) DEFAULT 0.00,
  `delivery_charge` decimal(10,2) DEFAULT 0.00,
  `handling_charge` decimal(10,2) DEFAULT 0.00,
  `final_amount` decimal(10,2) NOT NULL,
  `status` varchar(50) DEFAULT 'pending',
  `payment_method` varchar(50) DEFAULT 'COD',
  `order_datetime` varchar(50) DEFAULT NULL,
  `delivery_date` varchar(50) DEFAULT NULL,
  `delivery_time` varchar(50) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  `gift` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `orders`
--

INSERT INTO `orders` (`id`, `user_id`, `total_amount`, `coupon_code`, `discount_amount`, `delivery_charge`, `handling_charge`, `final_amount`, `status`, `payment_method`, `order_datetime`, `delivery_date`, `delivery_time`, `location_id`, `gift`) VALUES
(1, 1, 465.00, 'null', 129.00, 30.00, 5.00, 371.00, 'pending', 'COD', '16-12-2025 11:18 PM', '2025-12-16', '9 AM - 2 PM', 1, 'Rs0'),
(2, 1, 620.00, 'null', 384.00, 30.00, 5.00, 271.00, 'pending', 'COD', '20-12-2025 08:44 PM', '2025-12-21', '9 AM - 2 PM', 1, 'Rs0'),
(3, 20, 309.00, 'null', 51.00, 30.00, 5.00, 293.00, 'delivered', 'COD', '21-12-2025 10:13 PM', '2025-12-22', '9 AM - 2 PM', 9, 'noGift'),
(4, 1, 356.00, 'null', 84.00, 30.00, 5.00, 307.00, 'delivered', 'COD', '21-12-2025 10:49 PM', '2025-12-22', '6 AM - 8 AM', 1, 'noGift'),
(5, 20, 290.00, 'null', 10.00, 30.00, 5.00, 315.00, 'pending', 'COD', '21-12-2025 10:55 PM', '2025-12-22', '9 AM - 2 PM', 9, 'noGift'),
(6, 20, 2848.00, 'null', 776.00, 0.00, 5.00, 2077.00, 'delivered', 'COD', '21-12-2025 10:56 PM', '2025-12-21', '9 AM - 2 PM', 9, 'noGift'),
(7, 1, 279.00, 'null', 9.50, 30.00, 5.00, 304.50, 'delivered', 'COD', '22-12-2025 12:11 AM', '2025-12-22', '9 AM - 2 PM', 1, 'noGift'),
(8, 1, 683.00, 'null', 153.00, 0.00, 5.00, 535.00, 'way', 'COD', '22-12-2025 07:38 PM', '2025-12-25', '9 AM - 2 PM', 1, 'noGift'),
(9, 1, 3362.00, 'null', 128.00, 30.00, 5.00, 3269.00, 'delivered', 'COD', '23-12-2025 01:23 AM', '2025-12-24', '6 AM - 8 AM', 10, 'noGift'),
(10, 1, 813.00, 'null', 141.00, 0.00, 5.00, 677.00, 'pending', 'COD', '23-12-2025 01:51 AM', '2025-12-23', '9 AM - 2 PM', 10, 'noGift'),
(11, 1, 58.00, 'null', 2.00, 10.00, 5.00, 71.00, 'pending', 'COD', '23-12-2025 01:51 AM', '2025-12-23', '9 AM - 2 PM', 10, 'noGift'),
(12, 1, 74.00, 'null', 2.50, 10.00, 5.00, 86.50, 'pending', 'COD', '24-12-2025 07:06 PM', '2025-12-25', '9 AM - 2 PM', 1, 'noGift'),
(13, 1, 400.00, 'null', 120.00, 10.00, 5.00, 295.00, 'pending', 'COD', '25-12-2025 11:09 AM', '2025-12-25', '6 AM - 8 AM', 1, 'noGift'),
(14, 1, 500.00, 'null', 105.00, 10.00, 5.00, 410.00, 'pending', 'COD', '25-12-2025 08:27 PM', '2025-12-25', '9 AM - 2 PM', 1, 'noGift'),
(15, 1, 270.00, 'null', 48.00, 10.00, 5.00, 237.00, 'packed', 'COD', '26-12-2025 12:22 AM', '2025-12-27', '9 AM - 2 PM', 1, 'noGift'),
(16, 1, 499.00, 'null', 133.00, 10.00, 5.00, 381.00, 'pending', 'COD', '29-12-2025 02:11 AM', '2026-01-02', '9 AM - 2 PM', 1, 'noGift'),
(17, 1, 12152.00, 'null', 6199.00, 0.00, 5.00, 5958.00, 'pending', 'COD', '01-01-2026 01:51 PM', '2026-01-01', '9 AM - 2 PM', 1, 'noGift'),
(18, 1, 148.00, 'null', 5.00, 10.00, 5.00, 158.00, 'pending', 'COD', '01-01-2026 03:25 PM', '2026-01-01', '9 AM - 2 PM', 1, 'noGift');

-- --------------------------------------------------------

--
-- Table structure for table `order_items`
--

CREATE TABLE `order_items` (
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `variant_id` int(11) DEFAULT NULL,
  `quantity` int(11) NOT NULL,
  `image_url` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `order_items`
--

INSERT INTO `order_items` (`id`, `order_id`, `product_id`, `variant_id`, `quantity`, `image_url`) VALUES
(1, 1, 21, 28, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416570380d9_image.png'),
(2, 2, 24, 32, 4, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69429f3f66f17_image.png'),
(3, 3, 10, 15, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69414052d223a_image.png'),
(4, 3, 8, 13, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69413397316e5_image.png'),
(5, 4, 10, 15, 4, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69414052d223a_image.png'),
(6, 5, 27, 35, 5, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(7, 6, 27, 35, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(8, 6, 21, 28, 6, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416570380d9_image.png'),
(9, 7, 15, 20, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/694157ec4af04_image.png'),
(10, 7, 23, 30, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416a5b1cfbd_image.png'),
(11, 7, 23, 31, 3, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416a5b1cfbd_image.png'),
(12, 8, 10, 15, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69414052d223a_image.png'),
(13, 8, 9, 14, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6941361b0d4fd_image.png'),
(14, 8, 3, 4, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6941021652e72_image.png'),
(15, 9, 10, 15, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69414052d223a_image.png'),
(16, 9, 3, 4, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6941021652e72_image.png'),
(17, 9, 3, 5, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6941021652e72_image.png'),
(18, 9, 37, 45, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942bbdc68e49_image.png'),
(19, 10, 27, 35, 6, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(20, 10, 21, 28, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416570380d9_image.png'),
(21, 11, 27, 35, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(22, 12, 27, 35, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(23, 12, 23, 30, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416a5b1cfbd_image.png'),
(24, 13, 38, 48, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6949a5b6a8018_image.png'),
(25, 14, 9, 14, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6941361b0d4fd_image.png'),
(26, 15, 1, 1, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/694047df1cd48_image.png'),
(27, 15, 10, 15, 2, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69414052d223a_image.png'),
(28, 15, 27, 35, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(29, 16, 1, 1, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/694047df1cd48_image.png'),
(30, 16, 21, 28, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416570380d9_image.png'),
(31, 17, 10, 15, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69414052d223a_image.png'),
(32, 17, 9, 14, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6941361b0d4fd_image.png'),
(33, 17, 35, 43, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942b82c6feb3_image.png'),
(34, 17, 36, 44, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942ba1f29068_image.png'),
(35, 17, 19, 24, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69415feae824d_image.png'),
(36, 17, 22, 29, 1, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/694167cfe935e_image.png'),
(37, 18, 27, 35, 2, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/6942a7ca860ba_image.png'),
(38, 18, 23, 30, 2, 'https://dxmart.digixcode.com/api_folder/product_api_project/uploads/69416a5b1cfbd_image.png');

-- --------------------------------------------------------

--
-- Table structure for table `otp_table`
--

CREATE TABLE `otp_table` (
  `id` int(11) NOT NULL,
  `email` varchar(100) NOT NULL,
  `otp` int(10) NOT NULL,
  `expiry` int(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `otp_table`
--

INSERT INTO `otp_table` (`id`, `email`, `otp`, `expiry`) VALUES
(1, 'arvindk49011@gmail.com', 774278, 1751945729),
(2, 'arvindk49011@gmail.com', 505706, 1751946055),
(3, 'arvindk49011@gmail.com', 749251, 1751946295),
(4, 'anupamkumarnewlife@gmail.com', 521182, 1755070879),
(5, 'mrinmoymodak24@gmail.com', 180923, 1755154413),
(6, 'pankajkumar.hzb143@gmail.com', 983192, 1755263548),
(7, 'arvindk49011@gmail.com', 521276, 1755710073),
(8, 'arvindk49011@gmail.com', 393596, 1756369372),
(9, 'haneefrather12@gmail.com', 158159, 1757269253),
(10, 'haneefrather12@gmail.com', 931142, 1758042110),
(11, 'haneefrather12@gmail.com', 539402, 1758042182),
(12, 'haneefrather12@gmail.com', 121762, 1758042185),
(13, 'haneefrather12@gmail.com', 245472, 1761979640),
(14, 'arvindk49011@gmail.com', 871186, 1764274711),
(15, 'arvindk49011@gmail.com', 733199, 1764274886),
(16, 'arvindk49011@gmail.com', 432645, 1766411969),
(17, 'arvindk49011@gmail.com', 468191, 1767098263),
(18, 'arvindk49011@gmail.com', 240209, 1767224334),
(19, 'arvindk49011@gmail.com', 506135, 1767224388);

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text NOT NULL,
  `main_category_id` int(11) NOT NULL,
  `types` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `name`, `description`, `main_category_id`, `types`) VALUES
(1, 'Bhagyalakshmi Rice Flour', 'test', 23, 'normal,Everyday Essentials,Best selling,Hot deals'),
(2, 'Fortune Chakki Fresh Atta', 'test', 23, 'normal'),
(3, 'Tata Sampann Unpolished Green Moong', 'test', 23, 'normal'),
(4, 'Sri Bhagyalakshmi Ground Nut', 'test', 23, 'normal,Everyday Essentials'),
(5, 'Fortune Suji', 'test', 23, 'normal,Hot deals'),
(6, 'Akshayakalpa Organic Desi Cow Ghee', 'test', 23, 'normal'),
(7, 'Aashirvaad Superior MP Atta', 'test', 23, 'normal'),
(8, 'Fortune Kachi Ghani Mustard Oil | Bottle', 'test', 23, 'normal,Best selling'),
(9, 'Fortune Sona Masoori Supreme Raw Aged Rice', 'test', 23, 'normal'),
(10, 'Fortune Unpolished Kabuli Chana', 'test', 23, 'normal,Best selling'),
(11, '9am Tomato Ketchup, Natural, Tangy, Perfect for Snacks & Breakfast', 'test', 24, 'normal,Everyday Essentials'),
(12, 'Kissan Fresh Tomato Ketchup', 'test', 24, 'normal,Everyday Essentials'),
(13, 'Kellogg\'s Chocos, Moons and Stars Duet, Crunchy Bites and Chhota Laddoo | Pack of 7', 'test', 24, 'normal,Hot deals'),
(14, 'MyFitness Original Peanut Butter Smooth Spread | High Protein', 'test', 24, 'normal'),
(15, 'Hellmann\'s Eggless Mayonnaise World\'s No.1 Mayonnaise Brand', 'test', 24, 'normal,Hot deals'),
(16, 'Akshayakalpa Wild Honey', 'test', 24, 'normal'),
(17, 'Popular Fit Eats Chia Seeds - Raw', 'test', 24, 'normal'),
(18, 'Slurrp Farm Fruit Cereal Trial Pack', 'test', 24, 'normal,Best selling'),
(19, 'Taj Mahal Deccan Rose Tea', 'test', 24, 'normal'),
(20, 'Dabur Honey Squeezy, 100% Pure World\'s No.1 Honey Brand Buy 1 Get 1 Free', 'test', 24, 'normal,Everyday Essentials'),
(21, 'Kellogg\'s Muesli Fruit Nut & Seeds 12-in-1 Power Breakfast', 'test', 24, 'normal,Everyday Essentials'),
(22, 'Khari Foods Kalmi Dates / Khajur', 'test', 24, 'normal'),
(23, 'Amul Taaza Homogenised Toned Milk (Tetra Pack)', 'test', 25, 'normal,Everyday Essentials'),
(24, 'Philips 9 W LED Bulb Cool White | 6500K | Energy Efficient | B22 Base Holder', 'test', 26, 'normal,Best selling'),
(25, 'Nestle EveryDay Dairy Whitener', 'test', 25, 'normal'),
(26, 'Britannia 100% Whole Wheat Bread (No Maida)', 'test', 25, 'normal'),
(27, 'Amul Salted Butter', 'test', 25, 'normal,Everyday Essentials'),
(28, 'Amul Fresh Malai Paneer', 'test', 25, 'normal'),
(29, 'Amul Masti Dahi Cup', 'test', 25, 'normal'),
(30, 'Cake Tale Muffin Vanilla Chocochip', 'test', 25, 'normal'),
(31, 'Theobroma Christmas Plum Cake | Eggless/Veg', 'test', 25, 'normal'),
(32, 'Vijay White Eggs', 'test', 25, 'normal'),
(33, 'Amul Fresh Cream', 'test', 25, 'normal'),
(34, 'Havells Insta Cook QT 1200 W Induction Cooktop Push Button - Black, GHCICDGK120', 'test', 26, 'normal'),
(35, 'Bajaj GX-1 Mixer Grinder 500W | Superior Mixie For Kitchen |3 Stainless Steel Mixer Jars, 2-In-1 For', 'test', 26, 'normal'),
(36, 'Noise ColorFit Icon 2 Vista Smartwatch | Jet Black', 'test', 26, 'normal,Hot deals'),
(37, 'Mivi Roam2 Bluetooth Speaker | Black', 'test', 26, 'normal');

-- --------------------------------------------------------

--
-- Table structure for table `product_highlights`
--

CREATE TABLE `product_highlights` (
  `id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `attribute` varchar(100) NOT NULL,
  `value` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `product_highlights`
--

INSERT INTO `product_highlights` (`id`, `product_id`, `attribute`, `value`) VALUES
(6, 2, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(7, 3, 'brand', ' Tata Sampann'),
(8, 3, 'product type', 'Green Moong'),
(9, 4, 'brand', ' Sri Bhagyalakshmi'),
(10, 4, 'product type', ' Raw Peanut'),
(11, 4, 'polished', ' No'),
(12, 4, 'dietary preference', ' Veg'),
(13, 5, 'brand', ' Fortune'),
(14, 5, ' Fortune Suji Fortune Suji Fortune Suji Fortune Suji Fortune Suji â‚¹ 29   â‚¹45 Add To Cart Fortune', 'Roasted Sooji'),
(15, 5, 'dietary preference', ' Veg'),
(16, 5, 'ingredients', ' Wheat'),
(17, 6, 'brand', ' Akshayakalpa'),
(18, 6, 'product type', ' Cow Ghee'),
(19, 6, 'used for', ' Cooking, Garnishing, and Sweets'),
(20, 6, 'organic', ' Yes'),
(21, 7, 'brand', ' Aashirvaad'),
(22, 7, 'product type', ' Whole Wheat Flour'),
(23, 7, 'material type free', ' Maida-free'),
(24, 7, 'ingredients', ' Whole Wheat'),
(25, 8, 'brand', ' Fortune'),
(26, 8, 'product type', ' Mustard Oil'),
(27, 8, 'processing type', ' Kachi Ghani'),
(28, 8, 'nutrition information', ' Energy (kcal) 900, Carbohydrate (g) 0, Protein (g) 0, Sugar (g) 0, Cholesterol (mg) 0, Fat (g) 100, Mono Unsaturated Fatty Acids Min (g) 65, Polysaturated Fatty Acids Min (g) 28, Omega-3 Fatty Acid (g) 10, Omega-3 Fatty Acid (g) 16'),
(29, 9, 'brand', ' Fortune'),
(30, 9, 'product type', ' Sona Masoori Rice'),
(31, 9, ' Sona Masoori Rice', ' Yes'),
(32, 9, 'used for', ' Biriyani, Lemon Rice, and Pulao'),
(33, 10, 'brand', ' Fortune'),
(34, 10, 'product type', ' Kabuli Chana'),
(35, 10, 'ingredients', ' Organic Kabuli Chana (White Chickpea)'),
(36, 10, 'polished', ' No'),
(37, 11, 'brand', ' 9am'),
(38, 11, 'product type', ' Ketchup'),
(43, 12, 'brand', ' Kissan'),
(44, 12, 'product type', ' Tomato Ketchup'),
(45, 12, 'flavour', ' Tomato'),
(46, 12, 'ingredients', ' Water, Tomato Paste (28%), Sugar, Iodised Salt, Acidity Regulator - E260, Stabilizers - E1422, E415, Preservative - E211, Onion Powder, Garlic Powder, Spices and Condiments'),
(55, 14, 'brand', ' MyFitness'),
(56, 14, 'product type', ' Creamy Peanut Butter'),
(57, 14, 'flavour', ' Peanut Butter'),
(58, 14, 'ingredients', ' Roasted Peanuts (91%), Sugar, Salt, and Stabilizer (Ins 471)'),
(59, 13, 'brand', ' Kellogg\'s'),
(60, 13, 'product type', ' Breakfast Cereal'),
(61, 13, 'flavour', ' Chocolate'),
(62, 13, 'material type free', ' Maida-free'),
(63, 15, 'brand', ' Hellmann\'s'),
(64, 15, 'product type', ' Eggless Mayonnaise'),
(65, 15, 'flavour', ' Original'),
(66, 16, 'brand', ' Akshayakalpa'),
(67, 16, 'product type', ' Wild Honey'),
(68, 16, 'organic', ' Yes'),
(69, 16, 'dietary preference', ' Veg'),
(70, 16, 'ingredients', 'Raw Dorsata Honey'),
(71, 17, 'brand', ' Popular Fit Eats'),
(72, 17, 'product type', ' Chia Seeds-Seeds'),
(73, 17, 'model name', ' Fit Eats'),
(74, 17, 'item form', ' Seed'),
(75, 17, 'nutrition information', 'Energy (kcal) 145.0 (RDA 7.25%), Protein (g) 5.3 (RDA 8.77%), Carbohydrates (g) 5.3 (RDA 8.87%), Total Sugars (g) 11.9 (RDA 3.98%), Added Sugars (g) 0.5 (RDA 0.0%), Dietary Fibre (g) 11.1, Total Fat (g) 11.4 (RDA 38.12%), Saturated Fat (g) 1.5 (RDA 12.46%), Trans Fat (g) 0.0 (RDA 4.00%), Cholesterol (mg) 0.0, Sodium (mg) 0.4 (RDA 0.02%)'),
(76, 18, ' brand', ' Slurrp Farm'),
(77, 18, 'product type', ' Breakfast Cereal'),
(78, 18, 'ideal for', ' Kids'),
(79, 18, 'top nutrients', ' Fibre, Magnesium, Protein'),
(80, 19, 'brand', ' Taj Mahal'),
(81, 19, 'product type', ' Leaf Tea'),
(82, 20, 'Dabur Honey Squeezy, 100% Pure World\'s No.1 Honey Brand Buy 1 Get 1 Free Dabur Honey Squeezy, 100% P', ' Dabur Honey'),
(83, 20, 'product type', ' Honey-Spreads'),
(84, 20, 'health benefits', ' Boosts immunity, aids in weight management, improves digestion, enhances metabolism'),
(85, 20, 'nutrition information', 'Energy (kcal) 320.0, Carbohydrate (g) 80.0, Natural sugars (g) 80.0, Added Sugar (g) 0.0, Protein (g) 0.0, Fat (g) 0.0, Sodium (mg) 17.0, Potassium (mg) 138.0, Calcium (mg) 13.0, Iron (mg) 1.5, Phosphorus (mg) 5.0'),
(86, 21, 'brand', ' Kellogg\'s'),
(87, 21, 'product type', ' Muesli'),
(88, 21, 'flavour', ' Fruits, Nuts'),
(89, 21, 'ingredients', ' Added Flavours (Nature Identical & Artificial - Coconut), Antioxidant (INS 3076), Candied Fruits (Candied Cranberry (3%), Candied Papaya (5%)), Corn Grits (18.3%), Corn Meal, Cocoa Solids, Honey, Jodized Salt, Multigrain Mix (66%) (Rice (9.7%), Refined Wheat Flour (Maida), Rolled Barley (8%), Rolled Oats (8%), Ragi Millet Flour (3.5%), Sugar, Wheat Bran), Mineral, Oligofructose, Vitamins, Colours (INS 140, INS 150D), Nut & Seed (21%) (Almonds (3.5%), Black Currants (3%), Black Raisins (3%), Pumpkin Seeds (3.5%))'),
(90, 22, 'brand', ' Khari Foods'),
(91, 22, 'product type', ' Kalmi Dates'),
(92, 22, 'nutrition information', ' Energy (kcal) 97.04, Protein (g) 0.75, Carbohydrates (g) 23.5, Total Sugars (g) 17.19, Added Sugars (g) 0.0, Total Fat (g) 0.0, Trans Fat (g) 0.0, Saturated Fat (g) 3.64, MUFA (g) 0.0, PUFA (g) 7.0, Dietary Fiber (g) 28.0, Sodium (mg) 28.0 (RDA 14%)'),
(93, 22, 'dietary preference', ' Yes'),
(94, 23, 'brand', ' Amul'),
(95, 23, 'product type', ' Toned Milk'),
(96, 23, 'ingredients', 'Toned Milk (Fat 3.0% Minimum, Snf 8.5% Minimum)'),
(97, 23, 'packaging type', ' Tetrapack'),
(98, 24, 'brand', ' Philips LED'),
(99, 24, 'product type', ' LED Bulb'),
(100, 24, 'voltage', ' 220 - 240 V'),
(101, 24, 'light type', ' LED'),
(102, 25, 'brand', ' Nestle'),
(103, 25, 'product type', 'Dairy Whitener'),
(104, 25, 'ingredients', 'Milk solids, sugar, Maltodextrin (7.7%) and Stabilizer (339iii). Allergan Note: Contains Milk. Medium Fat Dairy Whitener'),
(105, 25, 'dietary preference', ' Veg'),
(106, 26, 'brand', ' Britannia Breads'),
(107, 26, 'product type', ' Whole Wheat Bread'),
(108, 26, 'ingredients', ' Wheat Flour (Atta) (61.8%), Water, Yeast, Wheat Bran, Vital Gluten, Sugar, Iodised Salt, Refined Palmolein Oil, Colour (150a), Preservatives (282 and 200), Emulsifiers (472e, 471 and 481 (i)), Acidity Regulator (260), and Flour Treatment Agent (510)'),
(109, 26, 'nutrition information', ' Energy (kcal) 245.0 (RDA 6%), Protein (g) 8.3, Carbohydrate (g) 50.7, Total Sugars (g) 1.5, Added Sugars (g) 1.5 (RDA 2%), Dietary Fibre (g) 4.4, Total Fat (g) 2.0 (RDA 1%), Saturated Fatty Acids (g) 0.6 (RDA 1%), Mono Unsaturated Fatty Acids (g) 0.5, Poly Unsaturated Fatty Acids (g) 0.6, Trans Fatty Acids (g) 0.0 (RDA 0%), Cholesterol (mg) 0.0, Sodium (mg) 478.6 (RDA 12%)'),
(110, 27, 'brand', ' Amul'),
(111, 27, 'product type', ' Table Butter'),
(112, 27, 'ingredients', 'Butter, iodized salt, natural colour (annatto)'),
(113, 27, 'nutrition information', 'Energy (kcal) 724 (RDA 4%), Total Fat (g) 80.0 (RDA 12%), Saturated Fat (g) 48.0 (RDA 22%), Trans Fat (g) 0.0 (RDA 0%), Cholesterol (mg) 220, Carbohydrate (g) 0.0, Total Sugars (g) 0.0, Added Sugars (g) 0.0 (RDA 0%), Protein (g) 1.0, Sodium (mg) 955 (RDA 5%)'),
(114, 27, 'dietary preference', ' Veg'),
(115, 28, 'brand', ' Amul'),
(116, 28, 'dietary preference', ' Veg'),
(117, 28, 'allergen information', ' Contains: Milk'),
(118, 29, 'brand', ' Amul'),
(119, 29, 'product type', ' Dahi'),
(120, 29, 'ingredients', ' Pasteurised Toned Milk and Active Lactic Culture'),
(121, 29, 'nutrition information', ' Energy 65 (kcal) (3% RDA), Protein 4.0 g, Carbohydrate 4.6 g, Total Sugars 4.6 g, Added Sugars 0.0 g (0% RDA), Total Fat 3.1 g (5% RDA), Saturated Fat 2.0 g (9% RDA), Trans Fat 0.0 g (0% RDA), Cholesterol 9 mg, Sodium 50 mg (3% RDA)'),
(122, 30, 'brand', ' Cake Tale'),
(123, 30, 'dietary preference', ' Veg'),
(124, 30, 'flavour', ' Vanilla Chocochip'),
(125, 31, 'brand', ' Theobroma'),
(126, 31, 'dietary preference', ' Veg'),
(127, 31, 'flavour', ' Plum'),
(128, 31, 'allergen information', ' Contains: Dairy, Gluten, Nuts, and Soy'),
(129, 32, 'brand', ' Vijay'),
(130, 32, 'product type', ' White Egg'),
(131, 32, 'nutrition information', 'Energy (kcal) 155.0, Total Fat (g) 10.83, Protein (g) 13.23, Carbohydrates (g) 0.55, Phosphorous (mg) 140.0, Calcium (mg) 71.81, Iron (mg) 0.98'),
(132, 33, 'brand', ' Amul'),
(133, 33, 'product type', ' Fresh Cream'),
(134, 33, 'dietary preference', ' Veg'),
(135, 34, 'brand', ' Havells'),
(136, 34, 'model name', ' Insta Cook QT'),
(137, 34, 'product dimensions', ' 30 x 38 x 6.8 cm'),
(138, 34, 'wattage', ' 1200 W'),
(139, 34, 'voltage', ' 220 - 240 V'),
(140, 35, 'brand', ' Bajaj'),
(141, 35, 'material type', ' ABS, Stainless Steel'),
(142, 35, 'model name', ' GX-1'),
(143, 35, 'wattage', ' 500 W'),
(144, 35, 'capacity', ' 400 ml, 800 ml, 1.2 L'),
(145, 36, 'brand', ' Noise'),
(146, 36, 'product type', ' Smart Watch'),
(147, 36, 'screen size', ' 1.78 inches'),
(148, 36, 'model name', ' ColourFit Icon 2 Vista'),
(149, 36, 'item included', '1 x Smartwatch and 1 x Magnetic Charger'),
(150, 36, 'battery capacity', ' 240 mAh'),
(151, 37, 'brand', ' Mivi'),
(152, 37, 'product type', ' Bluetooth Speaker'),
(153, 37, 'model name', ' Roam2'),
(154, 37, 'material type', ' Aluminium'),
(155, 37, 'playback time', ' 24 hours'),
(156, 37, 'bluetooth version', ' v5.0'),
(161, 1, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(162, 1, 'Manufacturer Address', 'Sri Bhagyalakshmi Enterprises.No.345/1, New Guddadahalli, Mysore Road Bangalore-560026.'),
(163, 1, 'Country of Origin', 'Sri Bhagyalakshmi Enterprises'),
(164, 1, 'Shelf Life', '91 days');

-- --------------------------------------------------------

--
-- Table structure for table `product_images`
--

CREATE TABLE `product_images` (
  `id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `image_url` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `product_images`
--

INSERT INTO `product_images` (`id`, `product_id`, `image_url`) VALUES
(1, 1, 'uploads/694047df1cd48_image.png'),
(2, 1, 'uploads/694047df4eb88_image.png'),
(3, 2, 'uploads/694048c74364c_image.png'),
(4, 2, 'uploads/694048c77826c_image.png'),
(5, 3, 'uploads/6941021652e72_image.png'),
(6, 3, 'uploads/6941021685c18_image.png'),
(7, 4, 'uploads/694103d9a9603_image.png'),
(8, 4, 'uploads/694103da30965_image.png'),
(9, 5, 'uploads/69412ca93a6e1_image.png'),
(10, 5, 'uploads/69412ca96dc68_image.png'),
(11, 6, 'uploads/69412f3790c8c_image.png'),
(12, 6, 'uploads/69412f38abadb_image.png'),
(13, 7, 'uploads/6941310440462_image.png'),
(14, 7, 'uploads/69413105156a7_image.png'),
(15, 8, 'uploads/69413397316e5_image.png'),
(16, 8, 'uploads/694133977bd24_image.png'),
(17, 9, 'uploads/6941361b0d4fd_image.png'),
(18, 9, 'uploads/6941361b585d5_image.png'),
(19, 10, 'uploads/69414052d223a_image.png'),
(20, 10, 'uploads/6941405328c87_image.png'),
(21, 11, 'uploads/6941419697377_image.png'),
(22, 11, 'uploads/694141971f178_image.png'),
(23, 12, 'uploads/694144ec28d64_image.png'),
(24, 12, 'uploads/694144ec59bab_image.png'),
(25, 13, 'uploads/694146c99e059_image.png'),
(26, 13, 'uploads/694146c9e8027_image.png'),
(27, 14, 'uploads/694155dc2e000_image.png'),
(28, 14, 'uploads/694155dc91914_image.png'),
(29, 14, 'uploads/69415695653ff_image.png'),
(30, 14, 'uploads/69415695e0c1a_image.png'),
(31, 15, 'uploads/694157ec4af04_image.png'),
(32, 15, 'uploads/694157ec7d902_image.png'),
(33, 16, 'uploads/694159861a9d6_image.png'),
(34, 16, 'uploads/694159864beaf_image.png'),
(35, 17, 'uploads/69415b69ca7db_image.png'),
(36, 17, 'uploads/69415b6a51dc9_image.png'),
(37, 18, 'uploads/69415dd6a61a5_image.png'),
(38, 18, 'uploads/69415dd6f0127_image.png'),
(39, 18, 'uploads/69415dd747802_image.png'),
(40, 18, 'uploads/69415dd7915d7_image.png'),
(41, 19, 'uploads/69415feae824d_image.png'),
(42, 19, 'uploads/69415feb260db_image.png'),
(43, 20, 'uploads/6941613f803b3_image.png'),
(44, 20, 'uploads/6941613fc9e61_image.png'),
(45, 21, 'uploads/69416570380d9_image.png'),
(46, 21, 'uploads/6941657082380_image.png'),
(47, 22, 'uploads/694167cfe935e_image.png'),
(48, 22, 'uploads/694167d03f052_image.png'),
(49, 23, 'uploads/69416a5b1cfbd_image.png'),
(50, 23, 'uploads/69416a5b4fbf8_image.png'),
(51, 24, 'uploads/69429f3f66f17_image.png'),
(52, 24, 'uploads/69429f404ffc2_image.png'),
(53, 25, 'uploads/6942a2136dc3c_image.png'),
(54, 25, 'uploads/6942a21427710_image.png'),
(55, 26, 'uploads/6942a64863872_image.png'),
(56, 26, 'uploads/6942a6491c7a5_image.png'),
(57, 27, 'uploads/6942a7ca860ba_image.png'),
(58, 27, 'uploads/6942a7cab837d_image.png'),
(59, 28, 'uploads/6942a947795ce_image.png'),
(60, 28, 'uploads/6942a947c4c22_image.png'),
(61, 29, 'uploads/6942aae3ece5b_image.png'),
(62, 29, 'uploads/6942aae44439d_image.png'),
(63, 29, 'uploads/6942aae48f443_image.png'),
(64, 30, 'uploads/6942ad64d296b_image.png'),
(65, 30, 'uploads/6942ad665b799_image.png'),
(66, 31, 'uploads/6942aef42ca63_image.png'),
(67, 31, 'uploads/6942aef45e4d1_image.png'),
(68, 32, 'uploads/6942b090c61d0_image.png'),
(69, 32, 'uploads/6942b09103db9_image.png'),
(70, 33, 'uploads/6942b3b053784_image.png'),
(71, 33, 'uploads/6942b3b08565d_image.png'),
(72, 34, 'uploads/6942b662385cb_image.png'),
(73, 34, 'uploads/6942b6626a3dd_image.png'),
(74, 34, 'uploads/6942b6629b987_image.png'),
(75, 35, 'uploads/6942b82c6feb3_image.png'),
(76, 35, 'uploads/6942b82ca2222_image.png'),
(77, 35, 'uploads/6942b82cd401d_image.png'),
(78, 36, 'uploads/6942ba1f29068_image.png'),
(79, 36, 'uploads/6942ba1f8aca6_image.png'),
(80, 36, 'uploads/6942ba1fbc5af_image.png'),
(81, 37, 'uploads/6942bbdc68e49_image.png'),
(82, 37, 'uploads/6942bbdce4570_image.png'),
(83, 37, 'uploads/6942bbdd21901_image.png');

-- --------------------------------------------------------

--
-- Table structure for table `product_info`
--

CREATE TABLE `product_info` (
  `id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `attribute` varchar(100) NOT NULL,
  `value` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `product_info`
--

INSERT INTO `product_info` (`id`, `product_id`, `attribute`, `value`) VALUES
(10, 2, 'brand', 'Fortune'),
(11, 2, 'Product type', ' Atta'),
(12, 2, 'key features', ' Made with Superior Wheat Blend, Absorbs More Water for Soft Rotis, Intensive Wheat Cleaning Process, and No Preservatives Added'),
(13, 2, 'Ingredients', 'Wheat'),
(14, 3, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(15, 3, 'Manufacturer Address', 'Soham Maritime Private Limited, Old Delhi Road, Vill: Bhadua, Post: Mollahber, P. S. Dankuni, District-Hooghly, West Bengal - 712 250. Lic. No. 10016031002002'),
(16, 3, 'key features', 'Unpolished for natural goodness, rich in essential nutrients, retains natural aroma and taste, premium quality assurance'),
(19, 4, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(20, 4, 'Manufacturer Name', ' Sri Bhagyalakshmi Agro Foods Pvt Ltd'),
(21, 5, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(22, 5, 'customer care details', ' In case of any issue, contact us E-mail address: support@zeptonow.com'),
(23, 5, 'Manufacturer Address', 'B.L Agro Industries Ltd, B31, Rd No. 2, Parsakhera Industrial Area, Parsaskhera Industrial Area, Bareilly, Uttar Pradesh 243506.'),
(24, 5, 'Manufacturer Name', 'B.L Agro Industries Ltd'),
(25, 6, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(26, 6, 'Manufacturer Name', ' Akshaykalpa'),
(27, 6, 'Shelf Life', ' 9 months'),
(28, 7, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(29, 7, 'Seller License No.', ' 11521998000248'),
(30, 8, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(31, 8, 'Manufacturer Address', 'Adani Wilmar Limited, Adani Corporate House, Shantigram, Near Vaishnodevi Circle, S G Highway, Ahmedabad-382421, Gujarat, India.'),
(32, 9, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(33, 9, 'Manufacturer Name', ' Adani Wilmar Ltd'),
(34, 9, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(35, 10, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(36, 10, 'Seller License No.', ' 12822999000310'),
(37, 10, 'Country of Origin', ' India'),
(38, 11, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(39, 11, 'Manufacturer Name', ' damyaa pj foods pvt ltd'),
(42, 12, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(43, 12, 'Manufacturer Address', ' Hindustan Unilever Limited, Unilever House, B.D. Sawant Marg, Chakala, Andheri E, Mumbai - 400099.'),
(49, 14, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(50, 14, 'Manufacturer Address', 'SuperNutri Foods, Palitana Road, Talaja 364140, Gujarat.'),
(51, 14, 'Manufacturer Name', ' SuperNutri Foods'),
(52, 13, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(53, 13, 'Manufacturer Address', 'Kelloggs India Pvt Ltd, Plot No. L2 & L3, Taloja MIDC, Dist. Rajgad, Maharashtra - 410208.'),
(54, 15, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(55, 15, 'Manufacturer Name', ' Hellmann\'s'),
(56, 15, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(57, 15, 'Country of Origin', ' Canada'),
(58, 16, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(59, 16, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(60, 17, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(61, 17, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(62, 17, 'Manufacturer Name', ' ?Popular Essentials Inc'),
(63, 18, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(64, 18, 'Slurrp Farm Fruit Cereal Trial Pack Slurrp Farm Fruit Cereal Trial Pack â‚¹ 223   â‚¹297 Add To Cart', ' COMMODUM GROCERIES PRIVATE LIMITED, Regd. Office: 44, Saket Building, Mullick Bazaar, Park Street, Kolkata, West Bengal, India, 700016. For Support ReachOut : support+commodum@zeptonow.com'),
(65, 19, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(66, 19, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(67, 19, 'Country of Origin', ' India'),
(68, 20, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(69, 20, 'Seller Name', ' Geddit Convenience Private Limited'),
(70, 20, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(71, 20, 'Shelf Life', ' 18 months'),
(72, 21, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(73, 21, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(74, 21, 'Manufacturer Address', 'Kelloggs India Pvt Ltd, Plot No. L2 & L3, Taloja MIDC, Dist. Rajgad, Maharashtra - 410208.'),
(75, 22, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(76, 22, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(77, 22, 'Manufacturer Address', ' Delhi'),
(78, 23, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(79, 23, 'Manufacturer Address', 'Gujarat Co-Operative Milk Marketing Federation, Po Box 10, Amul Dairy Road, Anand 388 001, Gujarat, India.'),
(80, 23, 'Shelf Life', ' 180 days'),
(81, 24, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(82, 24, ' â‚¹ 59   â‚¹155 Add To Cart Philips LED   Compare Philips 9 W LED Bulb Cool White | 6500K | Energy ', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(83, 24, 'Manufacturer Name', 'Philips Lighting'),
(84, 25, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(85, 25, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(86, 25, 'Manufacturer Name', 'Nestle India Limited'),
(87, 26, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(88, 26, 'Manufacturer Name', ' Britannia Industries'),
(89, 26, 'Manufacturer Address', ' Bangalore - Prestige Shantiniketan, Tower C, The Business Precinct, 16th & 17th Floor, Whitefield Main Road, Mahadevapura Post, Bangalore - 560 048.'),
(90, 27, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(91, 27, 'Manufacturer Name', 'Gujarat Co-Operative Milk Marketing Federation'),
(92, 27, 'Manufacturer Address', ' Gujarat Co-Operative Milk Marketing Federation, Po Box 10, Amul Dairy Road, Anand 388 001, Gujarat, India.'),
(93, 28, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(94, 28, 'Manufacturer Name', ' Gujarat Co-Operative Milk Marketing Federation'),
(95, 28, 'Manufacturer Address', ' Gujarat Co-Operative Milk Marketing Federation, Po Box 10, Amul Dairy Road, Anand 388 001, Gujarat, India.'),
(96, 29, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(97, 29, 'Seller Address', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(98, 29, 'Manufacturer Name', 'Gcmmf Ltd'),
(99, 30, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(100, 30, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(101, 30, 'Seller Name', ' Geddit Convenience Private Limited'),
(102, 31, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(103, 31, 'Seller Address', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(104, 31, 'Seller License No.', '11521998000248'),
(105, 32, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(106, 32, 'Seller Address', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(107, 32, 'Manufacturer Name', ' Vijay Eggs'),
(108, 33, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(109, 33, 'Seller Address', ' Geddit Convenience Private Limited'),
(110, 33, 'Seller Address', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(111, 34, 'disclaimer', ' All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(112, 34, 'warranty', ' 1 year'),
(113, 34, 'Seller Address', 'Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(114, 35, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(115, 35, 'Seller Address', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(116, 35, 'warranty', ' 1 year'),
(117, 36, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(118, 36, 'Seller Address', ' Geddit Convenience Private Limited, Unit 803, Lodha Supremus, Saki Vihar Road, Opp MTNL, Office, Powai, Mumbai, Maharashtra, India,400072 For Support ReachOut : support+geddit@zeptonow.com'),
(119, 36, 'warranty', ' 1 year manufacturer warranty'),
(120, 37, 'disclaimer', 'All images are for representational purposes only. It is advised that you read the batch and manufacturing details, directions for use, allergen information, health and nutritional claims (wherever applicable), and other details mentioned on the label before consuming the product. For combo items, individual prices can be viewed on the page.'),
(121, 37, 'warranty', ' 1 year'),
(122, 37, 'Manufacturer Name', 'Mivi -Customer Care No (Call) : 80999 73333 -Customer Care No (Whatsapp) : 86888 96578 -Customer Care mail id : supportteam@mini.in. -Brand Website : www.mivi.in'),
(128, 1, 'brand', ' Sri Bhagyalakshmi'),
(129, 1, 'product type', 'Rice Flour'),
(130, 1, 'weight', '500 g'),
(131, 1, 'key features', 'Bhagyalakshmi rice flour is a fine powder made from finely ground rice grains and ensures perfect results every time for traditional delicacies'),
(132, 1, 'ingredients', 'Rice');

-- --------------------------------------------------------

--
-- Table structure for table `product_variants`
--

CREATE TABLE `product_variants` (
  `id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `selling_price` decimal(10,2) NOT NULL,
  `wholesale_price` double(10,2) NOT NULL,
  `stock` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `product_variants`
--

INSERT INTO `product_variants` (`id`, `product_id`, `name`, `price`, `selling_price`, `wholesale_price`, `stock`) VALUES
(1, 1, '500 g', 34.00, 30.00, 28.00, 98),
(2, 2, '10 kg', 628.00, 474.00, 400.00, 100),
(3, 2, '5 kg', 413.00, 328.00, 200.00, 100),
(4, 3, '500 g', 94.00, 67.00, 50.00, 98),
(5, 3, '1 kg', 180.00, 100.00, 70.00, 99),
(6, 4, '500', 110.00, 90.00, 85.00, 100),
(7, 4, '1kg', 220.00, 180.00, 170.00, 100),
(8, 5, '500', 29.00, 45.00, 40.00, 100),
(9, 5, '1kg', 58.00, 80.00, 72.00, 100),
(10, 6, '300ml', 600.00, 500.00, 450.00, 50),
(11, 7, '1kg', 40.00, 35.00, 30.00, 100),
(12, 7, '5kg', 200.00, 175.00, 150.00, 100),
(13, 8, '1kg', 220.00, 190.00, 170.00, 99),
(14, 9, '5kg', 500.00, 395.00, 350.00, 97),
(15, 10, '1kg', 89.00, 68.00, 55.00, 90),
(16, 11, '850g', 130.00, 76.00, 69.00, 200),
(17, 12, '850g', 100.00, 93.00, 85.00, 200),
(18, 13, '140g', 70.00, 53.00, 0.00, 300),
(19, 14, '1.25kg', 536.00, 500.00, 470.00, 100),
(20, 15, '85g', 38.00, 29.00, 30.00, 199),
(21, 16, '250g', 425.00, 399.00, 350.00, 50),
(22, 17, '100g', 95.00, 65.00, 50.00, 150),
(23, 18, '1 pack (3x50g)', 297.00, 223.00, 200.00, 200),
(24, 19, '50g', 40.00, 35.00, 30.00, 149),
(25, 19, '100g', 85.00, 69.00, 55.00, 100),
(26, 19, '250g', 200.00, 185.00, 173.00, 50),
(27, 20, '2x225g', 249.00, 171.00, 160.00, 50),
(28, 21, '750g', 465.00, 336.00, 325.00, 41),
(29, 22, '250g', 399.00, 257.00, 239.00, 49),
(30, 23, '200ml', 16.00, 15.50, 14.00, 96),
(31, 23, '1 L', 75.00, 75.00, 74.50, 47),
(32, 24, '1 pc', 155.00, 59.00, 39.00, 96),
(33, 25, '200g', 130.00, 129.00, 129.00, 100),
(34, 26, '400', 55.00, 48.00, 45.00, 50),
(35, 27, '100g', 58.00, 56.00, 52.00, 33),
(36, 28, '200', 92.00, 82.00, 80.00, 50),
(37, 29, '200g', 23.00, 24.00, 22.00, 50),
(38, 30, '150g', 139.00, 111.00, 108.00, 50),
(39, 31, '350g', 490.00, 419.00, 100.00, 20),
(40, 32, '30pcs', 345.00, 260.00, 250.00, 200),
(41, 33, '250ml', 70.00, 66.00, 60.00, 50),
(42, 34, '1 pc', 4995.00, 2299.00, 2000.00, 130),
(43, 35, '1 set', 4125.00, 2999.00, 2700.00, 34),
(44, 36, '1 pc', 6999.00, 2199.00, 2000.00, 109),
(45, 37, '1pc', 2999.00, 999.00, 850.00, 102710),
(46, 1, '1 Kg', 60.00, 50.00, 40.00, 100),
(47, 1, '2 Kg', 100.00, 80.00, 70.00, 100);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(100) NOT NULL,
  `status` varchar(10) NOT NULL,
  `date_time` varchar(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password`, `status`, `date_time`) VALUES
(1, 'Arvind Kumar', 'arvindk49011@gmail.com', '$2y$10$O/BUWU/3Jb3nM11A/XVNyOuoKmxoO3WVJH3wNFiD/DWA/YCU2fgbG', 'blocked', '14-10-2025 08:03 AM'),
(2, 'userName', '8102337432', '$2y$10$ohIWItTDkk2TkH.nJvbxaeo5V4of39zAam9rL1bf0fwGY9j1UAX9m', 'blocked', '17-10-2025 10:41 PM'),
(3, 'Nitesh', 'digixcodeleads@gmail.com', '$2y$10$mYUtyFZdUzb1MXLRYPn4jeajcLlinMvCSTz2sbCMXIhLALzX7Mw42', 'active', '27-10-2025 07:02 PM'),
(4, 'Pankaj Kumar', 'pankajkumar.hzb143@gmail.com', '$2y$10$WaycxwHIfr4ysFX5rGM3beWT6kUlcvmzqGveyjMQLh9bwyanDJwGu', 'active', '29-10-2025 06:06 PM'),
(5, 'Sumer singh ', 'sumersinghsolanki76@gmail.com', '$2y$10$K4CXwpcmqNDnRJ1MdAPzu.4P7i6nuloukOCB9FZcXeC/rXZZstylG', 'active', '30-10-2025 08:19 PM'),
(6, 'bishal bohora', 'bbx340@gmail.com', '$2y$10$4bvjv5G1nSNo7fai2brQv.LnM/3xeU1dNtnLxMEL5k6oXmM4njz9S', 'active', '31-10-2025 05:07 PM'),
(7, 'haneef', 'haneefrather12@gmail.com', '$2y$10$4WWuK/vR1JtmWJI8P2K1TeYOC4SvvjFh75q5hB4jG7jnrUNNxGKyy', 'active', '01-11-2025 12:11 PM'),
(8, 'Sudhir', 'sudhirshahi2703@gmail.com', '$2y$10$UP2fOjRWM3rh2TMHu0SMgegSwjDPGUmgn6ut3URlbDcbS4G.6BAOG', 'active', '02-11-2025 09:00 PM'),
(9, 'Deb', 'debkumar1430@gmail.com', '$2y$10$54Ulh402/6LaWsJ4CJKrg.1mRKwFTJxYWIzFqJLCppmqkuczIsNzu', 'active', '02-11-2025 11:24 PM'),
(10, 'Atul', 'atulkumar.contact@gmail.com', '$2y$10$jerKKBzqwcTBXOgrBvKSh.PkpTdAQaRcxaWodV7d0tP4tdTsjEuUG', 'active', '07-11-2025 12:16 PM'),
(11, 'tanoy', 'tanoybiswas1555@gmail.com ', '$2y$10$nS1gCG1pAedEID27fAJvsOeOWGryexmM1oxesZAbbahuu6UdIIeOK', 'active', '08-11-2025 12:15 PM'),
(12, 'Pankaj', 'pankaj@gmail.com', '$2y$10$TP5f6hVd6GFaVURKIy1SF.h5LfbVDwK5gHzOwi0LhJo2v1JiGXhO2', 'active', '08-11-2025 08:55 PM'),
(13, 'Pankaj ', 'test@gmail.com', '$2y$10$z/3nbleJm9TvGLG/pOjAa.MRpX5xpyDucPC3iQNERcOKz8xKLNt96', 'active', '08-11-2025 08:56 PM'),
(14, 'Ajmal', 'ajmalhmir@gmail.com', '$2y$10$Qp6gKQskdfGLqDx1YBOtW.af29GeNrbHFo7bqH9MtcNs31sJwFIuu', 'active', '18-11-2025 09:27 PM'),
(15, 'sumanth shetty', 'sumanthshetty89@gmail.com', '$2y$10$cb2k/TiOpaiUYS7Qa/uWa.LqO5rpLhgK/3KbeLxsSoc2vTR..LnM2', 'active', '27-11-2025 01:10 PM'),
(16, 'test', 'test12@gmail.com', '$2y$10$bHjmiXCsP15xcBQfNzC4XeigfBgpzn.WdpYn2liQryfrK2Ob5jkLi', 'active', '28-11-2025 01:29 PM'),
(17, 'Adline Shami ', 'adlinepinky95@gmail.com', '$2y$10$u8cRE2JlSEnH.nMDEakFCOQaIhSEnkF7RCABM4lvTGj2acBPzYotq', 'active', '02-12-2025 10:59 PM'),
(18, 'EASWARA MOORTHY ', 'moorthyeaswara@yahoo.com', '$2y$10$AdUQYphpJxNFtnP6nqWFuOjmA4eKsK3vUokIGzCXcAR1Y6DmORp5K', 'active', '05-12-2025 08:52 PM'),
(19, 'shivani', 'shivani49011@gmail.com', '$2y$10$sVGCXffGf4PXFYyqz0kJkOKc5PmrfUSDZ/2PJboMcGRLJHB0HVM9S', 'active', '16-12-2025 12:36 PM'),
(20, 'Rahul Kumar', 'rahul49011@gmail.com', '$2y$10$uQgW7TverRs1vX2yjx1x4.3EgR8oy7U1WjewQm1xXlW4CjEtw5eea', 'active', '21-12-2025 09:51 PM'),
(21, 'Rahul ', 'rahul4911@gmail.com', '$2y$10$yCycAzpHch67NYZXeUbHee1UShPISOw9SfHbuTFbafejrQriNS9Aq', 'active', '23-12-2025 01:05 AM'),
(22, 'aarav ', 'aaravmishraoffical@gmail.com', '$2y$10$l3d9GIcHgICmWHMtP1LGJOwNfPqMVsNRAXnJNyg8AAW37.loJodEK', 'active', '24-12-2025 11:51 AM'),
(23, 'Umesh', 'Umesh490111@gmail.com', '$2y$10$Fkw7Q9Rufjb.JmwegPyI2.u.Y.EiqcvuywC0n9IRhKGwOLZFKL2I2', 'active', '30-12-2025 04:17 PM');

-- --------------------------------------------------------

--
-- Table structure for table `wishlist`
--

CREATE TABLE `wishlist` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `wishlist`
--

INSERT INTO `wishlist` (`id`, `user_id`, `product_id`, `created_at`) VALUES
(11, 1, 27, '2025-12-25 18:49:27'),
(12, 1, 24, '2025-12-30 09:34:49');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin`
--
ALTER TABLE `admin`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `banner`
--
ALTER TABLE `banner`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cart_items`
--
ALTER TABLE `cart_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `cart_product_fk` (`product_id`),
  ADD KEY `cart_variants_fk` (`variant_id`);

--
-- Indexes for table `city`
--
ALTER TABLE `city`
  ADD PRIMARY KEY (`id`),
  ADD KEY `city_fk` (`district_id`);

--
-- Indexes for table `coupon`
--
ALTER TABLE `coupon`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `delivery_address`
--
ALTER TABLE `delivery_address`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `delivery_boy`
--
ALTER TABLE `delivery_boy`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `delivery_charge`
--
ALTER TABLE `delivery_charge`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `deliver_time`
--
ALTER TABLE `deliver_time`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `delivey_charge`
--
ALTER TABLE `delivey_charge`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `district`
--
ALTER TABLE `district`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `free_delivey`
--
ALTER TABLE `free_delivey`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `handling_charge`
--
ALTER TABLE `handling_charge`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `help_call`
--
ALTER TABLE `help_call`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `help_email`
--
ALTER TABLE `help_email`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `help_whatsapp`
--
ALTER TABLE `help_whatsapp`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `main_category`
--
ALTER TABLE `main_category`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `minimum_order_amout`
--
ALTER TABLE `minimum_order_amout`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `order_items`
--
ALTER TABLE `order_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `order_id` (`order_id`);

--
-- Indexes for table `otp_table`
--
ALTER TABLE `otp_table`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD KEY `m_category_fk` (`main_category_id`);

--
-- Indexes for table `product_highlights`
--
ALTER TABLE `product_highlights`
  ADD PRIMARY KEY (`id`),
  ADD KEY `product_highlight_fk` (`product_id`);

--
-- Indexes for table `product_images`
--
ALTER TABLE `product_images`
  ADD PRIMARY KEY (`id`),
  ADD KEY `product_fk` (`product_id`);

--
-- Indexes for table `product_info`
--
ALTER TABLE `product_info`
  ADD PRIMARY KEY (`id`),
  ADD KEY `info_product_fk` (`product_id`);

--
-- Indexes for table `product_variants`
--
ALTER TABLE `product_variants`
  ADD PRIMARY KEY (`id`),
  ADD KEY `variants_fk` (`product_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `wishlist`
--
ALTER TABLE `wishlist`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_wishlist` (`user_id`,`product_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `admin`
--
ALTER TABLE `admin`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `banner`
--
ALTER TABLE `banner`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `cart_items`
--
ALTER TABLE `cart_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=58;

--
-- AUTO_INCREMENT for table `city`
--
ALTER TABLE `city`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- AUTO_INCREMENT for table `coupon`
--
ALTER TABLE `coupon`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `delivery_address`
--
ALTER TABLE `delivery_address`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `delivery_boy`
--
ALTER TABLE `delivery_boy`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `delivery_charge`
--
ALTER TABLE `delivery_charge`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `deliver_time`
--
ALTER TABLE `deliver_time`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `delivey_charge`
--
ALTER TABLE `delivey_charge`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `district`
--
ALTER TABLE `district`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;

--
-- AUTO_INCREMENT for table `free_delivey`
--
ALTER TABLE `free_delivey`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `handling_charge`
--
ALTER TABLE `handling_charge`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `help_call`
--
ALTER TABLE `help_call`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `help_email`
--
ALTER TABLE `help_email`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `help_whatsapp`
--
ALTER TABLE `help_whatsapp`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `main_category`
--
ALTER TABLE `main_category`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- AUTO_INCREMENT for table `minimum_order_amout`
--
ALTER TABLE `minimum_order_amout`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT for table `order_items`
--
ALTER TABLE `order_items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `otp_table`
--
ALTER TABLE `otp_table`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `product_highlights`
--
ALTER TABLE `product_highlights`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=169;

--
-- AUTO_INCREMENT for table `product_images`
--
ALTER TABLE `product_images`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=86;

--
-- AUTO_INCREMENT for table `product_info`
--
ALTER TABLE `product_info`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=137;

--
-- AUTO_INCREMENT for table `product_variants`
--
ALTER TABLE `product_variants`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `wishlist`
--
ALTER TABLE `wishlist`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `cart_items`
--
ALTER TABLE `cart_items`
  ADD CONSTRAINT `cart_product_fk` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `cart_variants_fk` FOREIGN KEY (`variant_id`) REFERENCES `product_variants` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `city`
--
ALTER TABLE `city`
  ADD CONSTRAINT `city_fk` FOREIGN KEY (`district_id`) REFERENCES `district` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `order_items`
--
ALTER TABLE `order_items`
  ADD CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `products`
--
ALTER TABLE `products`
  ADD CONSTRAINT `m_category_fk` FOREIGN KEY (`main_category_id`) REFERENCES `main_category` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `product_highlights`
--
ALTER TABLE `product_highlights`
  ADD CONSTRAINT `product_highlight_fk` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `product_images`
--
ALTER TABLE `product_images`
  ADD CONSTRAINT `product_fk` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `product_info`
--
ALTER TABLE `product_info`
  ADD CONSTRAINT `info_product_fk` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `product_variants`
--
ALTER TABLE `product_variants`
  ADD CONSTRAINT `variants_fk` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
