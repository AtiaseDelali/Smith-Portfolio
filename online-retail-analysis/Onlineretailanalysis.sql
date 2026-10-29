-- =============================================================
-- ONLINE RETAIL ANALYSIS: WHO REALLY PAYS THE BILLS?
-- UK online gift shop, Dec 2009 - Dec 2011
-- Table: clean_transactions (1,033,036 cleaned rows)
-- Tool: SQLite (DBeaver)
-- =============================================================


-- Step 1: Keep only real sales
-- Removes cancelled orders, postage/fee lines and zero prices.
CREATE TABLE sales AS
SELECT *
FROM clean_transactions
WHERE is_cancellation = 0
  AND is_adjustment = 0
  AND is_non_product = 0
  AND quantity > 0
  AND price > 0;


-- Q1: How big is the business?
SELECT ROUND(SUM(line_amount), 2)                           AS total_sales,
       COUNT(DISTINCT invoice)                              AS total_orders,
       COUNT(DISTINCT customer_id)                          AS total_customers,
       COUNT(DISTINCT country)                              AS countries,
       ROUND(SUM(line_amount) / COUNT(DISTINCT invoice), 2) AS avg_order_value
FROM sales;
-- £19.6M sales, 39,516 orders, 5,852 customers, 43 countries.
-- An average order of £497 is very high for a gift shop:
-- most customers are shops buying stock to resell.


-- Q2: Sales by year
SELECT strftime('%Y', invoice_day)  AS year,
       ROUND(SUM(line_amount), 0)   AS sales,
       COUNT(DISTINCT invoice)      AS orders
FROM sales
GROUP BY year;
-- 2010: £9.37M from 19,627 orders. 2011: £9.47M from 18,223 orders.
-- 2011 sold slightly more with fewer orders (and the data stops on 9 Dec 2011).


-- Q3: Best months
SELECT invoice_month,
       ROUND(SUM(line_amount), 0) AS sales
FROM sales
GROUP BY invoice_month
ORDER BY sales DESC
LIMIT 5;
-- The top 5 months are all September, October or November.
-- November is the peak every year (about £1.4M), as shops stock up for Christmas.


-- Q4: Top countries
SELECT country,
       ROUND(SUM(line_amount), 0)   AS sales,
       COUNT(DISTINCT customer_id)  AS customers
FROM sales
GROUP BY country
ORDER BY sales DESC
LIMIT 10;
-- The UK brings in 86% of sales.
-- Ireland (EIRE) is second with only 3 customers.


-- Q5: Countries with the biggest orders
SELECT country,
       ROUND(SUM(line_amount) / COUNT(DISTINCT invoice), 0) AS avg_order_value
FROM sales
GROUP BY country
HAVING COUNT(DISTINCT invoice) >= 50      -- only countries with 50+ orders
ORDER BY avg_order_value DESC
LIMIT 5;
-- The Netherlands averages £2,545 per order, five times the UK.


-- Q6: Top 10 customers
SELECT customer_id,
       country,
       ROUND(SUM(line_amount), 0)  AS sales,
       COUNT(DISTINCT invoice)     AS orders
FROM sales
WHERE customer_id IS NOT NULL
GROUP BY customer_id, country
ORDER BY sales DESC
LIMIT 10;
-- Just 10 customers spent £2.76M, 14% of all sales.
-- The top customer (18102, UK) spent £581K.
-- Customer 16446 is in the top 10 with only 2 orders. Why? See Q8.


-- Q7: Best-selling products
SELECT description,
       SUM(quantity)               AS units_sold,
       ROUND(SUM(line_amount), 0)  AS sales
FROM sales
GROUP BY description
ORDER BY sales DESC
LIMIT 10;
-- The Regency cakestand earns the most (£331K).
-- The white hanging heart T-light holder sold 94,658 units.
-- "Paper Craft, Little Birdie" is #3 with £168K... from a single order.


-- Q8: The order that never happened
SELECT invoice, invoice_date, customer_id, quantity, line_amount
FROM clean_transactions
WHERE description LIKE 'PAPER CRAFT%';
-- One order of 80,995 units (£168K) was cancelled 12 minutes later
-- (invoice C581484). It was almost certainly a typing mistake.
-- Lesson: always check big numbers before trusting a "top 10".


-- Q9: Which day do customers order?
SELECT strftime('%w', invoice_date)  AS day_of_week,     -- 0 = Sunday, 6 = Saturday
       COUNT(DISTINCT invoice)       AS orders
FROM sales
GROUP BY day_of_week;
-- Thursday is the busiest day (8,167 orders).
-- Saturday has only 30 orders in two years, while Sunday has 4,824.
-- The company most likely did not process orders on Saturdays.


-- Q10: Which hour do customers order?
SELECT strftime('%H', invoice_date)  AS hour,
       COUNT(DISTINCT invoice)       AS orders
FROM sales
GROUP BY hour
ORDER BY orders DESC;
-- Most orders arrive between 10:00 and 15:00, peaking at 12:00.
-- Weekdays + office hours + big orders = business customers.


-- Q11: How much was cancelled?
SELECT COUNT(DISTINCT invoice)      AS cancelled_invoices,
       ROUND(SUM(-line_amount), 0)  AS cancelled_value
FROM clean_transactions
WHERE is_cancellation = 1;
-- 8,292 cancelled invoices worth £1.46M.


-- =============================================================
-- SUMMARY
-- This "gift shop" is really a wholesale business: big orders,
-- weekday office-hour buying and a few large customers abroad.
-- Sales depend on autumn (Sep-Nov) and on a small group of top
-- customers. Keep those customers happy, stock up before
-- September, and check unusual orders before they are processed.
-- =============================================================