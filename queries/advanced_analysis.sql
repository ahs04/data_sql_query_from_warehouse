/*
========================================================================
Advanced Analytics
========================================================================
*/


/*
Change over time
*/

-- Sales over time
SELECT
	EXTRACT(YEAR FROM order_date) AS order_year,
	EXTRACT(MONTH FROM order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY EXTRACT(YEAR FROM order_date), EXTRACT(MONTH FROM order_date)
ORDER BY order_year, order_month;

SELECT
	date_trunc('month', order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);

/*
Culmulative  Analysis
*/

-- Total sales per month and running total of sales over time
SELECT
	order_date,
	total_sales,
	SUM(total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales,
	AVG(avg_price) OVER(ORDER BY order_date) AS moving_average_price
FROM
(SELECT
	DATE_TRUNC('month', order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	ROUND(AVG(price), 2) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date));


/*
Performance Analysis
*/

-- Yearly performance of products by comparing its sales to both average
-- sales performance of product and previous year's sales

WITH yearly_product_sales AS (
    SELECT
        EXTRACT(YEAR FROM f.order_date) AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY EXTRACT(YEAR FROM f.order_date), p.product_name
),
sales_with_analytics AS (
    SELECT
        order_year,
        product_name,
        current_sales,
        AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
        LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_year_sales
    FROM yearly_product_sales
)
SELECT
    order_year,
    product_name,
    current_sales,
    avg_sales,
    current_sales - avg_sales AS diff_avg,
    prev_year_sales,
    current_sales - prev_year_sales AS diff_prev_year,
    CASE
        WHEN current_sales > avg_sales THEN 'above avg'
        WHEN current_sales < avg_sales THEN 'below avg'
        ELSE 'avg'
    END AS avg_change,
    CASE
        WHEN prev_year_sales IS NULL THEN 'N/A'
        WHEN current_sales > prev_year_sales THEN 'increase'
        WHEN current_sales < prev_year_sales THEN 'decrease'
        ELSE 'no change'
    END AS yoy_change
FROM sales_with_analytics
ORDER BY product_name, order_year;


/*
Part to Whole Analysis
*/

-- Which categories contribute most to overall sales
WITH category_sales AS(
SELECT
	category,
	SUM(sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY category
)
SELECT 
	category, 
	total_sales,
	SUM(total_sales) OVER() AS overall_sales,
	CONCAT(ROUND(total_sales/SUM(total_sales) OVER() * 100, 2), '%') AS percentage_of_total
FROM
	category_sales
ORDER BY
	total_sales DESC;


/*
Data Segmentation Analysis
*/

-- Segment product into cost ranges and count how much in each range
WITH product_segmentation AS(
SELECT
	product_key,
	product_name,
	cost,
	CASE
		WHEN cost < 100 THEN 'Below 100'
		WHEN cost BETWEEN 100 AND 500 THEN '100-500'
		WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'Above 1000' END AS cost_range
FROM
	gold.dim_products)

SELECT cost_range, COUNT(product_key) AS total_products
FROM product_segmentation
GROUP BY cost_range
ORDER BY total_products DESC;

-- Group customers by spending behavior:
-- - VIP, at least 12 months of history and spending more than 5000
-- - Regular, at least 12 months of history and spending 5000 or less
-- - New, customers with less than 12 months 
-- And find total count of each category

WITH customer_spending AS(
SELECT
	c.customer_key,
	SUM(f.sales_amount) AS total_spent,
	MIN(f.order_date) AS first_order,
	MAX(f.order_date) AS last_order,
	DATE_PART('year', AGE(MAX(f.order_date), MIN(f.order_date))) * 12 +
    DATE_PART('month', AGE(MAX(f.order_date), MIN(f.order_date))) AS month_diff
FROM
	gold.fact_sales f
LEFT JOIN
	gold.dim_customers c ON
	f.customer_key = c.customer_key
GROUP BY
	c.customer_key
)

SELECT
customer_category,
COUNT(customer_key) as total_customers FROM
(SELECT 
	customer_key, 
	CASE
		WHEN month_diff >= 12 AND total_spent > 5000 THEN 'VIP'
		WHEN month_diff >= 12 AND total_spent <= 5000 THEN 'Regular'
	ELSE 'New' END AS customer_category
FROM customer_spending
) t
GROUP BY customer_category
ORDER BY total_customers DESC;

/*
Report
*/

-- For key customer metrics and behaviors

/*
Requirements:

Report has names, ages, and transaction details.
Segmentation into categories.
Aggregation of total orders, total sales, total quantity purchased, total products, lifespan
*/


CREATE VIEW gold.report_customers AS
WITH base_query AS(
SELECT
	f.order_number,
	f.product_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
	EXTRACT(YEAR FROM AGE(c.birthdate)) AS age
FROM
	gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL
)
, customer_aggregation AS(
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT product_key) AS total_products,
	MAX(order_date) AS last_order_date,
	DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12 +
    DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS lifespan
FROM base_query
GROUP BY
	customer_key,
	customer_number,
	customer_name,
	age
)

SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE
		WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN '20-29'
		WHEN age BETWEEN 30 AND 39 THEN '30-39'
		WHEN age BETWEEN 40 AND 49 THEN '40-49'
	ELSE '50 and above' END AS age_group,
	CASE
		WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
	ELSE 'New' END AS customer_category,
	total_orders,
	total_sales,
	total_products,
	last_order_date,
	lifespan
FROM
	customer_aggregation;