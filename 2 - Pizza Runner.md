<h1 align="center">Case Study #2 – Pizza Runner</h1>

<p align="center">
  <img src="https://images.pexels.com/photos/1566837/pexels-photo-1566837.jpeg" 
       alt="Pizza Runner" 
       width="100%" 
       height="390px" />
</p>


Solutions for this challenge are written in *PostGreSQL**.

## PIZZA METRICS

### 1. How many pizzas were ordered?
```sql
-- count(*) gets the total count of all the rows, which corresponds to pizza ordered

SELECT COUNT(*) 
	AS total_pizzas_ordered
FROM customer_orders;
```

### 2. How many unique customer orders were made?
```sql
/*
	To handle this, we first do a distinct combination of order_id and customer_id,
	this drops duplicate, and only gives us a unique order per customer.
*/

SELECT COUNT(DISTINCT(order_id, customer_id)) 
	AS unique_customer_orders
FROM customer_orders;
```

### 3. How many successful orders were delivered by each runner?
```sql
/*
	From the runner_orders table, a successful order is made, when the pickup_time,
	doesn't have a null value, or there was no cancellation either from restaurant,
	or customer in the cancellation column.
*/

SELECT runner_id, COUNT(runner_id) AS successful_orders 
FROM runner_orders 
WHERE pickup_time <> 'null' 
GROUP BY runner_id
ORDER BY runner_id;
```

### 4. How many of each type of pizza was delivered?
```sql
/*
	We combined three table, i.e. the customer_orders, runner_orders and pizza_names,
	the first two tables were to get the successful deliveries, and the pizza_ids
	associated with it. The last table was to get the name of each pizza id.
*/

SELECT pi.pizza_name, 
	COUNT(pi.pizza_name) AS no_delivered
FROM customer_orders c
JOIN runner_orders p ON c.order_id = p.order_id
JOIN pizza_names pi ON c.pizza_id = pi.pizza_id
WHERE p.pickup_time <> 'null'
GROUP BY pi.pizza_name
ORDER BY pi.pizza_name;
```

### 5. How many Vegetarian and Meatlovers were ordered by each customer?
```sql
-- We used a sum(case ...) to create new columns and count for each pizza type.

SELECT customer_id,
	SUM(CASE WHEN pizza_id = 1 THEN 1 END) AS Meatlovers,
	SUM(CASE WHEN pizza_id = 2 THEN 1 END) AS Vegetarian
FROM customer_orders
GROUP BY customer_id
ORDER BY customer_id;
```

### 6. What was the maximum number of pizzas delivered in a single order?
```sql
/* 
	The max pizza delivered in a single order is the count of each order_ids, sorted in
	a descending manner, and first entry (limit 1) gives the max.
*/

SELECT order_id, COUNT(order_id) AS max_order
FROM customer_orders
GROUP BY order_id
ORDER BY COUNT(order_id) DESC
LIMIT 1;
```

### 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
```sql
/*
	A pizza is considered changed if it has any valid exclusions or extras 
	— meaning the customer removed or added ingredients. 
	If both exclusions and extras are empty, null, or just 'null' as text, 
	then the pizza was ordered as-is with no changes.
*/

WITH first_cte AS (
SELECT c.*
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE pickup_time <> 'null')
SELECT customer_id,
	SUM(CASE WHEN exclusions ~ '[0-9]+' OR extras ~ '[0-9]+' THEN 1 END) AS change,
	SUM(CASE WHEN exclusions !~ '[0-9]+' AND extras !~ '[0-9]+' THEN 1 END) no_change
FROM first_cte
GROUP BY customer_id
ORDER BY customer_id;
```

### 8. How many pizzas were delivered that had both exclusions and extras?
```sql
/*
	Build from the delivered pizzas table, and then use regular expressions to match
	digit characters for the exclusions and extras columns.
*/

WITH first_cte AS (
SELECT c.*
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE pickup_time <> 'null')
SELECT COUNT(*) AS delivered_pizzas
FROM first_cte
WHERE exclusions ~ '[0-9]+' AND extras ~ '[0-9]+';
```

### 9. What was the total volume of pizzas ordered for each hour of the day?
```sql
/*
	We will use the extract function to get the hour from the order_time and
	make a group by out of that.
*/

WITH first_cte AS (
	SELECT EXTRACT(HOUR FROM order_time) AS order_hour 
	FROM customer_orders
)
SELECT order_hour, COUNT(order_hour) AS pizza_volume
FROM first_cte
GROUP BY order_hour
ORDER BY order_hour;
```

### 10. What was the volume of orders for each day of the week?
```sql
/*
	We will use the to_char function to get the Day of week from the order_time and
	make a group by out of that. To get the correct ordering, we will get a little
	help from the weekday_num and then order by that.
*/

WITH first_cte AS (
	SELECT TRIM(TO_CHAR(order_time, 'Day')) AS day_of_week,
	EXTRACT(DOW FROM order_time) AS weekday_num
	FROM customer_orders
)
SELECT day_of_week, COUNT(day_of_week) AS pizza_volume
FROM first_cte
GROUP BY day_of_week, weekday_num
ORDER BY weekday_num;
```
