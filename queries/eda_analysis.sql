/*
Database Exploration
*/

-- Explore All objects in Database
SELECT	* FROM INFORMATION_SCHEMA.TABLES;

-- Explore All columns in database
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';


/*
Dimesnion Exploration
*/

-- All countries from customers
SELECT DISTINCT country FROM gold.dim_customers
WHERE country != 'n/a';

-- All categories in major divisions
SELECT DISTINCT category, subcategory, product_name FROM gold.dim_products
ORDER BY 1, 2, 3;


/*
Date Exploration
*/

-- Date of first and last order + years of sales available
SELECT 
	MIN(order_date) AS first_order_date,
	MAX(order_date) AS last_order_date,
	DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) AS order_range_years
FROM gold.fact_sales;

-- Find youngest and oldest customer
SELECT
	MIN(birthdate) AS oldest_birthdate,
	DATE_PART('year', AGE(MIN(birthdate))) AS oldest_age,
	MAX(birthdate) AS youngest_birthdate,
	DATE_PART('year', AGE(MAX(birthdate))) AS youngest_age
FROM
	gold.dim_customers;


/*
Measure Exploration
*/

-- Total Sales
SELECT SUM(sales_amount) AS total_sales FROM gold.fact_sales;

-- Number of items sold
SELECT SUM(quantity) AS total_quantity FROM gold.fact_sales;

-- Average sales price
SELECT ROUND(AVG(price), 2) AS average_price FROM gold.fact_sales;

-- Total Number of Orders
SELECT COUNT(order_number) AS total_orders FROM gold.fact_sales;
SELECT COUNT(DISTINCT order_number) AS total_orders FROM gold.fact_sales;

-- Total Number of Products
SELECT COUNT(product_name) AS total_products FROM gold.dim_products;
SELECT COUNT(DISTINCT product_name) AS total_products FROM gold.dim_products;

-- Total Number of Customers
SELECT COUNT(customer_key) AS total_customers FROM gold.dim_customers;

-- Total Number of Customers that placed an order
SELECT COUNT(DISTINCT customer_key) AS total_customers FROM gold.fact_sales;


-- Overall Report of Metrics
-- Total Sales
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS total_sales FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity) AS total_quantity FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', ROUND(AVG(price), 2) AS average_price FROM gold.fact_sales
UNION ALL
SELECT 'Total Number Orders', COUNT(DISTINCT order_number) AS total_orders FROM gold.fact_sales
UNION ALL
SELECT 'Total Number Products', COUNT(product_name) AS total_products FROM gold.dim_products
UNION ALL
SELECT 'Total Number Customers', COUNT(customer_key) AS total_customers FROM gold.dim_customers;


/*
Magnitude Exploration
*/

-- Total Customers by Country
SELECT
	country,
	COUNT(customer_key) AS total_customers
FROM 
	gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- Total Customers by Gender
SELECT
	gender,
	COUNT(customer_key) AS total_customers
FROM
	gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;

-- Total Products by Category
SELECT
	category,
	COUNT(product_key) AS total_products
FROM
	gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- Average Cost by Category
SELECT
	category,
	ROUND(AVG(cost), 2) AS avg_costs
FROM
	gold.dim_products
GROUP BY category
ORDER BY avg_costs DESC;

-- Total Revenue by each category
SELECT
	p.category,
	SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Total Revenue by each customer
SELECT
	c.customer_key,
	c.first_name,
	c.last_name,
	SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
GROUP BY 1, 2, 3
ORDER BY total_revenue DESC;

-- Distribution of Sold Items by country
SELECT
	c.country,
	SUM(f.quantity) AS total_sold_items
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC;


/*
Ranking Analysis
*/

-- Top 5 Products by Revenue
SELECT
	p.product_name,
	SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

SELECT * FROM (
SELECT 
	p.product_name,
	SUM(f.sales_amount) AS total_revenue,
	RANK() OVER(ORDER BY SUM(f.sales_amount) DESC) AS ranking
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC) AS results
WHERE ranking <= 5;

-- Worst 5 Products by Revenue
SELECT
	p.product_name,
	SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY p.product_name
LIMIT 5;

SELECT * FROM (
SELECT 
	p.product_name,
	SUM(f.sales_amount) AS total_revenue,
	RANK() OVER(ORDER BY SUM(f.sales_amount) ASC) AS ranking
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY p.product_name) AS results
WHERE ranking <= 5;

-- Top 10 Customers by Revenue
SELECT * FROM(
	SELECT 
		c.customer_key,
		c.first_name,
		c.last_name,
		SUM(f.sales_amount) AS total_revenue,
		RANK() OVER(ORDER BY SUM(f.sales_amount) DESC) AS ranking
	FROM
		gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON c.customer_key = f.customer_key
	GROUP BY
		c.customer_key,
		c.first_name,
		c.last_name
) AS results
WHERE ranking <= 10;

-- Customers with fewest orders placed
SELECT * FROM(
	SELECT 
		c.customer_key,
		c.first_name,
		c.last_name,
		COUNT(DISTINCT order_number) AS total_orders,
		RANK() OVER(ORDER BY COUNT(DISTINCT order_number) ASC) AS ranking
	FROM
		gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON c.customer_key = f.customer_key
	GROUP BY
		c.customer_key,
		c.first_name,
		c.last_name
) AS results
WHERE ranking <= 1;