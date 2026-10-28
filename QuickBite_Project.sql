-- Create the database -- 
CREATE database quickbite_analysis;
use quickbite_analysis;

-- Create Tables & Import Data -- 

-- Customers
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  customer_name VARCHAR(100),
  city VARCHAR(50),
  signup_date DATE,
  customer_segment VARCHAR(20)
);

-- Restaurants
CREATE TABLE restaurants (
  restaurant_id INT PRIMARY KEY,
  restaurant_name VARCHAR(100),
  city VARCHAR(50),
  cuisine VARCHAR(50),
  rating DECIMAL(2,1)
);

-- Menu Items
CREATE TABLE menu_items (
  item_id INT PRIMARY KEY,
  restaurant_id INT,
  item_name VARCHAR(100),
  category VARCHAR(50),
  price DECIMAL(10,2)
);

-- Orders
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  restaurant_id INT,
  order_date DATE,
  order_status VARCHAR(20),
  delivery_minutes DECIMAL(5,2),
  order_amount DECIMAL(10,2),
  discount DECIMAL(10,2)
);

-- Payments
CREATE TABLE payments (
  payment_id INT PRIMARY KEY,
  order_id INT,
  payment_method VARCHAR(20),
  payment_status VARCHAR(20),
  payment_date DATE
);

-- Step 3: Understand the Data
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM restaurants;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM payments;

-- Check Missing Values
-- Check for NULLs in customers
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN customer_name IS NULL OR customer_name='' THEN 1 END) AS missing_name,
  COUNT(CASE WHEN city IS NULL OR city='' THEN 1 END) AS missing_city,
  COUNT(CASE WHEN signup_date IS NULL OR signup_date='' THEN 1 END) AS missing_signup_date,
  COUNT(CASE WHEN customer_segment IS NULL OR customer_segment='' THEN 1 END) AS missing_segment
FROM customers;

-- order table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN order_status IS NULL OR order_status='' THEN 1 END) AS missing_status,
  COUNT(CASE WHEN delivery_minutes IS NULL OR delivery_minutes='' THEN 1 END) AS missing_delivery_time,
  COUNT(CASE WHEN order_amount IS NULL OR order_amount='' THEN 1 END) AS missing_amount,
  COUNT(CASE WHEN discount IS NULL OR discount='' THEN 1 END) AS missing_discount
FROM orders;

-- Payment Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN payment_method IS NULL OR payment_method='' THEN 1 END) AS missing_method,
  COUNT(CASE WHEN payment_status IS NULL OR payment_status='' THEN 1 END) AS missing_status,
  COUNT(CASE WHEN payment_date IS NULL OR payment_date='' THEN 1 END) AS missing_date
FROM payments;

-- Restaurants Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN restaurant_name IS NULL OR restaurant_name='' THEN 1 END) AS missing_name,
  COUNT(CASE WHEN city IS NULL OR city='' THEN 1 END) AS missing_city,
  COUNT(CASE WHEN cuisine IS NULL OR cuisine='' THEN 1 END) AS missing_cuisine,
  COUNT(CASE WHEN rating IS NULL OR rating='' THEN 1 END) AS missing_rating
FROM restaurants;

-- Menu Items Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN item_name IS NULL OR item_name='' THEN 1 END) AS missing_item,
  COUNT(CASE WHEN category IS NULL OR category='' THEN 1 END) AS missing_category,
  COUNT(CASE WHEN price IS NULL OR price='' THEN 1 END) AS missing_price
FROM menu_items;

-- Check Distinct Values - To spot inconsistencies:
-- Customer segments
SELECT DISTINCT customer_segment FROM customers;

-- Order statuses
SELECT DISTINCT order_status FROM orders;

-- Payment statuses
SELECT DISTINCT payment_status FROM payments;

-- Cuisine types
SELECT DISTINCT cuisine FROM restaurants;

DESCRIBE customers;
DESCRIBE restaurants;
DESCRIBE menu_items;
DESCRIBE orders;
DESCRIBE payments;

-- Data Cleanning
-- Convert signup_date from text to DATE
SET SQL_SAFE_UPDATES = 0;
-- Run your update
UPDATE customers
SET signup_date = STR_TO_DATE(signup_date, '%d-%m-%Y')
WHERE signup_date IS NOT NULL AND signup_date <> '';

-- Re-enable safe update mode (recommended)
SET SQL_SAFE_UPDATES = 1;

-- Fill missing customer_segment with 'Unknown'
UPDATE customers
SET customer_segment = 'Unknown'
WHERE customer_segment IS NULL OR customer_segment = '';

## Orders
-- Normalize order_status values
UPDATE orders
SET order_status = CASE 
  WHEN order_status IN ('Delivered','Cancelled','Pending') THEN order_status
  ELSE 'Unknown' END;

-- Ensure discount is not greater than order_amount
UPDATE orders
SET discount = order_amount
WHERE discount > order_amount OR discount IS NULL;

### Payments
-- Remove orphan payments (orders that don’t exist)
DELETE FROM payments
WHERE order_id NOT IN (SELECT order_id FROM orders);

-- Normalize payment_status values
UPDATE payments
SET payment_status = CASE 
  WHEN payment_status IN ('Paid','Pending','Failed') THEN payment_status
  ELSE 'Unknown' END;
  
  ### Clean Menu Items
-- Remove invalid prices
DELETE FROM menu_items
WHERE price IS NULL OR price <= 0;

-- Standardize category values
UPDATE menu_items
SET category = CASE 
  WHEN category IN ('Main Course','Starter','Beverage','Dessert') THEN category
  ELSE 'Other' END;
  
  ## Validation After Cleaning
-- Customers
SELECT DISTINCT customer_segment FROM customers;

-- Orders
SELECT DISTINCT order_status FROM orders;

-- Payments
SELECT DISTINCT payment_status FROM payments;

-- Restaurants
SELECT DISTINCT cuisine FROM restaurants;

-- Menu Items
SELECT DISTINCT category FROM menu_items;

## A. Geographic Market Penetration & Volume
-- 1. Total unique operational cities
SELECT COUNT(DISTINCT city) AS total_cities 
FROM restaurants;

-- 2. Restaurant partner count by city
SELECT city, COUNT(restaurant_id) AS restaurant_count 
FROM restaurants 
GROUP BY city 
ORDER BY restaurant_count DESC;

-- 3. Customer base distribution by city
SELECT city, COUNT(customer_id) AS customer_count 
FROM customers 
GROUP BY city 
ORDER BY customer_count DESC;

-- 4. Delivered orders volume by city
SELECT c.city, COUNT(o.order_id) AS delivered_orders 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY delivered_orders DESC;

-- 5. City with highest order volume
SELECT c.city, COUNT(o.order_id) AS order_volume 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY order_volume DESC 
LIMIT 1;

## B. City-Wise Revenue & Margin Performance
-- 6. Total delivered net revenue by city
SELECT c.city, SUM(o.order_amount - o.discount) AS city_net_revenue 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY city_net_revenue DESC;

-- 7. Average order value (AOV) by city
SELECT c.city, AVG(o.order_amount - o.discount) AS avg_order_value 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY avg_order_value DESC;

-- 8. Total promotional discount given by city
SELECT c.city, SUM(o.discount) AS total_city_discount 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
GROUP BY c.city 
ORDER BY total_city_discount DESC;

-- 9. Discount share percentage of gross revenue by city
SELECT c.city, 
       (SUM(o.discount) * 100.0 / SUM(o.order_amount)) AS discount_percentage 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
GROUP BY c.city 
ORDER BY discount_percentage DESC;

-- 10. Cities generating net revenue above average city revenue
WITH city_rev AS (
  SELECT c.city, SUM(o.order_amount - o.discount) AS net_revenue 
  FROM orders o 
  JOIN customers c ON o.customer_id = c.customer_id 
  WHERE o.order_status='Delivered' 
  GROUP BY c.city
)
SELECT city, net_revenue 
FROM city_rev 
WHERE net_revenue > (SELECT AVG(net_revenue) FROM city_rev) 
ORDER BY net_revenue DESC;

## C. Delivery Efficiency & SLA Breaches
-- 11. Average delivery time by city
SELECT c.city, AVG(o.delivery_minutes) AS avg_delivery_time 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY avg_delivery_time ASC;

-- 12. City with lowest average delivery time (fastest fulfillment)
SELECT c.city, AVG(o.delivery_minutes) AS fastest_avg_delivery 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY fastest_avg_delivery ASC 
LIMIT 1;

-- 13. Percentage of delayed orders (> 45 mins) by city
SELECT c.city, 
       (COUNT(CASE WHEN o.delivery_minutes > 45 THEN 1 END) * 100.0 / COUNT(*)) AS delayed_order_pct 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY delayed_order_pct DESC;

-- 14. Cities with severe delivery delays (> 60 mins)
SELECT c.city, COUNT(CASE WHEN o.delivery_minutes > 60 THEN 1 END) AS severe_delays 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
HAVING COUNT(CASE WHEN o.delivery_minutes > 60 THEN 1 END) > 0 
ORDER BY severe_delays DESC;

## D. Operational Failures & Customer Tier Penetration
-- 15. Order cancellation percentage by city
SELECT c.city, 
       (COUNT(CASE WHEN o.order_status='Cancelled' THEN 1 END) * 100.0 / COUNT(*)) AS cancellation_rate 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
GROUP BY c.city 
ORDER BY cancellation_rate DESC;

-- 16. Total revenue lost from cancellations by city
SELECT c.city, SUM(o.order_amount - o.discount) AS lost_cancelled_revenue 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Cancelled' 
GROUP BY c.city 
ORDER BY lost_cancelled_revenue DESC;

-- 17. Orders pending fulfillment by city
SELECT c.city, COUNT(*) AS pending_orders 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Pending' 
GROUP BY c.city 
ORDER BY pending_orders DESC;

-- 18. Premium vs Regular customer revenue contribution by city
SELECT c.city, 
       SUM(CASE WHEN c.customer_segment='Premium' THEN (o.order_amount - o.discount) ELSE 0 END) AS premium_rev, 
       SUM(CASE WHEN c.customer_segment='Regular' THEN (o.order_amount - o.discount) ELSE 0 END) AS regular_rev 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city;

-- 19. Classify cities into Market Maturity Tiers
WITH city_metrics AS (
  SELECT c.city, 
         COUNT(o.order_id) AS total_orders, 
         AVG(o.delivery_minutes) AS avg_delivery
  FROM orders o 
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status='Delivered'
  GROUP BY c.city
)
SELECT city, total_orders, avg_delivery,
       CASE 
         WHEN total_orders >= 5 AND avg_delivery <= 50 THEN 'High Growth / High Efficiency'
         WHEN total_orders >= 5 AND avg_delivery > 50 THEN 'High Growth / Bottlenecked'
         ELSE 'Emerging / Low Volume'
       END AS market_tier
FROM city_metrics
order by  city;

## E. City Benchmarking & Rankings
-- 20. Rank cities by total order volume
SELECT c.city, COUNT(o.order_id) AS order_count, 
       RANK() OVER (ORDER BY COUNT(o.order_id) DESC) AS volume_rank 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
GROUP BY c.city;

-- 21. Rank cities by delivered net revenue
SELECT c.city, SUM(o.order_amount - o.discount) AS net_revenue, 
       DENSE_RANK() OVER (ORDER BY SUM(o.order_amount - o.discount) DESC) AS revenue_rank 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city;

-- 22. Top 3 most profitable cities by delivered net revenue
SELECT c.city, SUM(o.order_amount - o.discount) AS top_net_revenue 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status='Delivered' 
GROUP BY c.city 
ORDER BY top_net_revenue DESC 
LIMIT 3;

-- 23. Cumulative revenue concentration across cities
WITH city_rev AS (
  SELECT c.city, SUM(o.order_amount - o.discount) AS net_rev
  FROM orders o 
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status='Delivered'
  GROUP BY c.city
)
SELECT city, net_rev,
       SUM(net_rev) OVER (ORDER BY net_rev DESC) AS cumulative_revenue
FROM city_rev;