--1. Orders Volume
SELECT COUNT(*) AS total_orders
FROM orders ;

--2. Unique Customers
SELECT COUNT(DISTINCT customer_unique_id) AS total_unique_customers
FROM customers ;

--3. Orders by Status
WITH percentage AS(
SELECT order_status, COUNT(*) AS total_orders,
SUM(COUNT(*)) OVER() AS total_count
FROM orders
GROUP BY order_status
) 
SELECT order_status,total_orders,
ROUND(((total_orders*100.0)/total_count),2) AS percentage_distribution
FROM percentage 
ORDER BY percentage_distribution DESC;

--4. Monthly Order Trend
SELECT 
DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
COUNT(*) AS total_orders
FROM orders
GROUP BY order_month 
ORDER BY order_month;

--5.Top Customer Cities
SELECT c.customer_city AS city,COUNT(*) AS total_customers
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id 
GROUP BY c.customer_city
ORDER BY total_customers DESC
LIMIT 10 ;

--6.Revenue Calculation
SELECT SUM(payment_value) AS Total_revenue
FROM order_payments ;

--7. Revenue Per Month
SELECT DATE_TRUNC('month',o.order_purchase_timestamp) AS months,
CONCAT('$',SUM(op.payment_value)) AS Total_revenue
FROM order_payments op
JOIN orders o
ON op.order_id = o.order_id
GROUP BY months 
ORDER BY months ASC;

--8. Revenue by Payment Type
SELECT payment_type,SUM(payment_value) AS Total_revenue
FROM order_payments 
GROUP BY payment_type
ORDER BY Total_revenue DESC;

--9. Average Order Value
SELECT 
ROUND(AVG(total_value),2) AS Avg_Value_Per_Order
FROM (
  SELECT SUM(payment_value) AS total_value
  FROM order_payments
  GROUP BY order_id
);

--10. Orders per State
SELECT c.customer_state AS state,
COUNT(*) AS total_orders
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
GROUP BY state 
ORDER BY total_orders DESC ;

--11. Orders per Customer by State
SELECT c.customer_state AS state,
ROUND(COUNT(o.order_id)::numeric /COUNT(DISTINCT c.customer_id),2) AS order_per_customer
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
GROUP BY state 
ORDER BY order_per_customer DESC ;

--12. Top 10 product categories by number of items sold.
SELECT p.product_category_name AS product_category,
COUNT(*) AS sold_items
FROM order_items ot
JOIN products p
ON ot.product_id = p.product_id
WHERE p.product_category_name IS NOT NULL
GROUP BY product_category
ORDER BY sold_items DESC
LIMIT 10 ;

--13. Which sellers have fulfilled the most orders?
SELECT s.seller_id AS seller,
COUNT(DISTINCT ot.order_id) AS total_orders
FROM sellers s
JOIN order_items ot 
ON s.seller_id = ot.seller_id
GROUP BY seller
ORDER BY total_orders DESC;

--14. Average delivery time (in days).
WITH delivery AS(
   SELECT DATE_PART('day',delivery_time) AS days
   FROM (SELECT (order_delivered_customer_date - order_purchase_timestamp ) AS delivery_time
FROM orders 
WHERE order_delivered_customer_date IS NOT NULL)
)
SELECT ROUND(AVG(days::numeric),2) AS Avg_delivery_days
FROM delivery ;
---------------------------------------------------------------------------------------------------------
SELECT 
ROUND(AVG( EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400),2) AS avg_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

--15. What percentage of orders were delivered AFTER the estimated delivery date?
WITH late_delivery AS(
SELECT 
SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date  THEN 1 ELSE 0 END) AS late_orders_count,
SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END) AS total_deliveries
FROM orders
)
SELECT ROUND((late_orders_count*100.0)/total_deliveries,2) AS delivery_percentage_after_estimated_delivery_date
FROM late_delivery ;

--16. How many customers placed more than one order?
SELECT c.customer_unique_id AS customers
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(c.customer_id)>1 ;

--17. Top 10 customers by total spend.
SELECT c.customer_unique_id AS customer,
SUM(op.payment_value) AS total_spent
FROM orders o
JOIN order_payments op
ON op.order_id = o.order_id
JOIN customers c
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
ORDER BY total_spent DESC
LIMIT 10 ;

--18. Number of Orders Per Customer
SELECT c.customer_unique_id AS customer_id,
COUNT(o.order_id) AS total_orders
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.order_id IS NOT NULL
GROUP BY c.customer_unique_id 
ORDER BY total_orders DESC;

--19. Average Order Value Per Customer
SELECT customer,
ROUND(AVG(total_value),2) AS Avg_Order_Value_Per_Customer
FROM (
  SELECT c.customer_unique_id AS customer,
  SUM(op.payment_value) AS total_value
  FROM order_payments op
  JOIN orders o
  ON op.order_id = o.order_id
  JOIN customers c
  ON o.customer_id = c.customer_id
  GROUP BY op.order_id, c.customer_unique_id 
) t
GROUP BY customer 
ORDER BY Avg_Order_Value_Per_Customer DESC;

--20. Customer Lifetime Value (CLV)
WITH total_orders AS(
   SELECT SUM(op.payment_value) AS total_value,
   o.order_id,c.customer_unique_id AS customer_id
   FROM order_payments op
   JOIN orders o
   ON op.order_id = o.order_id
   JOIN customers c
   ON o.customer_id = c.customer_id
   GROUP BY o.order_id,c.customer_unique_id
)
SELECT customer_id,
SUM(total_value) AS lifetime_value,
COUNT(order_id) AS total_orders,
ROUND(AVG(total_value),2) AS avg_order_value
FROM total_orders
GROUP BY customer_id
ORDER BY lifetime_value DESC ;

--21. Revenue per month.
SELECT DATE_TRUNC('month',o.order_purchase_timestamp) AS month,
SUM(op.payment_value) AS total_revenue
FROM orders o
JOIN order_payments op
ON o.order_id = op.order_id
GROUP BY month 
ORDER BY month;

--22. Month-over-Month (MoM) Growth %
WITH monthly_revenue AS(
	SELECT DATE_TRUNC('month',o.order_purchase_timestamp) AS month,
	SUM(op.payment_value) AS total_revenue
	FROM orders o
	JOIN order_payments op
	ON o.order_id = op.order_id
	GROUP BY month 
	ORDER BY month
),
revenue_lag AS(
	SELECT month,total_revenue,
	LAG(total_revenue) OVER(ORDER BY month) AS previous_revenue
	FROM monthly_revenue
)
SELECT month,total_revenue,previous_revenue,
	ROUND((total_revenue-previous_revenue)/NULLIF(previous_revenue,0)*100,2) AS mom_growth_percent
	FROM revenue_lag
	ORDER BY month ;

--23. Cohort Analysis
WITH cohort AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),
cohort_activity AS (
    SELECT
        o.customer_id,
        c.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS purchase_month,
        (
            EXTRACT(YEAR FROM DATE_TRUNC('month', o.order_purchase_timestamp)) * 12
          + EXTRACT(MONTH FROM DATE_TRUNC('month', o.order_purchase_timestamp))
          - EXTRACT(YEAR FROM c.cohort_month) * 12
          - EXTRACT(MONTH FROM c.cohort_month)
        ) AS month_number
    FROM orders o
    JOIN cohort c USING (customer_id)
    WHERE o.order_status = 'delivered'
)

SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT customer_id) AS active_customers,
    ROUND(
        COUNT(DISTINCT customer_id) * 100.0
        / FIRST_VALUE(COUNT(DISTINCT customer_id))
          OVER (PARTITION BY cohort_month ORDER BY month_number),
        2
    ) AS retention_percentage
FROM cohort_activity
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

--24. Top 5 Sellers by Revenue Per Month
WITH seller_monthly_revenue AS(
SELECT ot.seller_id AS seller_id,
DATE_TRUNC('month',o.order_purchase_timestamp) AS month,
SUM(ot.price) AS total_revenue
FROM order_items ot
JOIN orders o
ON ot.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY seller_id,month
)
SELECT * 
FROM (
	SELECT seller_id,month,total_revenue,
	ROW_NUMBER() OVER(PARTITION BY month ORDER BY total_revenue DESC) AS rnk
	FROM seller_monthly_revenue
)t
	WHERE rnk <= 5
	ORDER BY month,rnk ;

--25. Most Frequently Bought Together Products (Identifying product pairs commonly purchased in the same order.)
SELECT 
    p1.product_category_name AS product_1,
    p2.product_category_name AS product_2,
    COUNT(*) AS times_bought_together
FROM order_items oi1
JOIN order_items oi2
    ON oi1.order_id = oi2.order_id
   AND oi1.product_id < oi2.product_id
JOIN products p1 
ON oi1.product_id = p1.product_id
JOIN products p2 
ON oi2.product_id = p2.product_id
GROUP BY product_1, product_2
ORDER BY times_bought_together DESC
LIMIT 10;

--26. Revenue Concentration (Pareto Analysis On Product) 
WITH product_sales AS(
	SELECT product_id,
	SUM(price) AS total_sales
	FROM order_items
	GROUP BY product_id
),
cumulative_sales AS(
	SELECT product_id,total_sales,
	SUM(total_sales) OVER(ORDER BY total_sales DESC) AS running_total,
	SUM(total_sales) OVER(ORDER BY total_sales DESC) *100.0/SUM(total_sales) OVER() AS cumulative_percentage
	FROM product_sales
)
SELECT product_id,total_sales,ROUND(cumulative_percentage,2) AS cumulative_percentage
FROM cumulative_sales
WHERE cumulative_percentage <= 80
ORDER BY total_sales DESC ;

-- Revenue Concentration (Pareto Analysis On Customers)
WITH customer_revenue AS(
	SELECT c.customer_unique_id AS customer_id,
	SUM(op.payment_value) AS total_revenue
	FROM orders o
	JOIN order_payments op ON o.order_id = op.order_id
	JOIN customers c ON o.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
),
ranked_revenue AS(
	SELECT customer_id,total_revenue,
	SUM(total_revenue) OVER(ORDER BY total_revenue DESC) AS running_revenue,
	SUM(total_revenue) OVER() AS cum_revenue
	FROM customer_revenue
)
SELECT customer_id,total_revenue,
ROUND((running_revenue*100.0)/cum_revenue,2) AS cumulative_percentage
FROM ranked_revenue
WHERE (running_revenue*100.0)/cum_revenue <= 80
ORDER BY total_revenue DESC ;

--27. Rolling 3-Month Revenue (Trend Smoothing)
WITH rolling_revenue AS(
SELECT DATE_TRUNC('month',o.order_purchase_timestamp) AS month,
SUM(op.payment_value) AS total_revenue
FROM orders o
JOIN order_payments op
ON o.order_id = op.order_id
GROUP BY month 
)
SELECT month,total_revenue,
ROUND(SUM(total_revenue) OVER(ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS rolling_3_month_revenue
FROM rolling_revenue
ORDER BY month ;

--28. Delivery Performance by State
WITH delivery AS(
SELECT c.customer_state AS state,
(o.order_delivered_customer_date - o.order_purchase_timestamp ) AS delivery_time
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL
)
SELECT state,ROUND(AVG(days::numeric),2) AS Avg_delivery_days
FROM( SELECT state,DATE_PART('day',delivery_time) AS days
FROM delivery)
GROUP BY state
ORDER BY Avg_delivery_days DESC ;

----------------------------------------------------------------------------------------------------------------------------------
SELECT c.customer_state AS state,
ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400), 2) AS avg_delivery_days
FROM orders o
JOIN customers c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
GROUP BY state
ORDER BY avg_delivery_days DESC;

-----------------------------------------------------------------------------------------------------------------------------------
--29. Late Delivery % State Wise
WITH delivery AS(
SELECT c.customer_state AS state,
SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date  THEN 1 ELSE 0 END) AS late_orders_count,
SUM(CASE WHEN o.order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END) AS total_deliveries
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL
GROUP BY state
)
SELECT state, ROUND((late_orders_count * 100.0)/ total_deliveries,2) AS delivery_percentage
FROM delivery
ORDER BY delivery_percentage DESC ;

--30. Customer Acquisition Trend
WITH first_purchase AS(
	SELECT c.customer_unique_id AS customer_id,
	MIN(o.order_purchase_timestamp) AS first_purchase_date
	FROM orders o
	JOIN customers c
	ON o.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
)
SELECT
DATE_TRUNC('month',first_purchase_date) AS month,
COUNT(customer_id) AS new_customers
FROM first_purchase
GROUP BY month
ORDER BY month ;

--31. RFM Segmentation
WITH rfm_base AS (
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(op.payment_value) AS monetary
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    JOIN order_payments op
        ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT 
        customer_unique_id,
        CURRENT_DATE - last_purchase_date::date AS recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY CURRENT_DATE - last_purchase_date::date DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
)
SELECT *,
CASE 
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN f_score >= 4 AND m_score >= 3 THEN 'Loyal Customers'
    WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
    WHEN r_score = 1 THEN 'Lost Customers'
    ELSE 'Regular'
END AS customer_segment
FROM rfm_scores;

--32. Revenue Retention vs New Revenue
WITH first_purchase AS (
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
orders_labeled AS (
    SELECT 
        o.order_id,
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        o.order_purchase_timestamp,
        fp.first_purchase_date
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    JOIN first_purchase fp 
        ON c.customer_unique_id = fp.customer_unique_id
    WHERE o.order_status = 'delivered'
)
SELECT 
    order_month,
    CASE 
        WHEN order_purchase_timestamp = first_purchase_date THEN 'New'
        ELSE 'Returning'
    END AS customer_type,
    SUM(op.payment_value) AS revenue
FROM orders_labeled ol
JOIN order_payments op
    ON ol.order_id = op.order_id
GROUP BY order_month, customer_type
ORDER BY order_month, customer_type;

