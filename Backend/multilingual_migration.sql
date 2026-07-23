-- Multilingual Support Migration SQL
-- Alters products, category, variants, info, and highlight tables to add name_hi, name_hn, description_hi, description_hn, etc.

ALTER TABLE `main_category` 
  ADD COLUMN `name_hi` varchar(255) DEFAULT NULL AFTER `name`,
  ADD COLUMN `name_hn` varchar(255) DEFAULT NULL AFTER `name_hi`;

ALTER TABLE `products` 
  ADD COLUMN `name_hi` varchar(255) DEFAULT NULL AFTER `name`,
  ADD COLUMN `name_hn` varchar(255) DEFAULT NULL AFTER `name_hi`,
  ADD COLUMN `description_hi` text DEFAULT NULL AFTER `description`,
  ADD COLUMN `description_hn` text DEFAULT NULL AFTER `description_hi`;

ALTER TABLE `product_variants`
  ADD COLUMN `name_hi` varchar(100) DEFAULT NULL AFTER `name`,
  ADD COLUMN `name_hn` varchar(100) DEFAULT NULL AFTER `name_hi`;

ALTER TABLE `product_info`
  ADD COLUMN `attribute_hi` text DEFAULT NULL AFTER `attribute`,
  ADD COLUMN `attribute_hn` text DEFAULT NULL AFTER `attribute_hi`,
  ADD COLUMN `value_hi` text DEFAULT NULL AFTER `value`,
  ADD COLUMN `value_hn` text DEFAULT NULL AFTER `value_hi`;

ALTER TABLE `product_highlights`
  ADD COLUMN `attribute_hi` text DEFAULT NULL AFTER `attribute`,
  ADD COLUMN `attribute_hn` text DEFAULT NULL AFTER `attribute_hi`,
  ADD COLUMN `value_hi` text DEFAULT NULL AFTER `value`,
  ADD COLUMN `value_hn` text DEFAULT NULL AFTER `value_hi`;
