<h1 align="center">Case Study #2 – Pizza Runner</h1>

Solutions for this challenge are written in *PostgreSQL*.

## A. PIZZA METRICS

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

## B. RUNNER AND CUSTOMER EXPERIENCE

### 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
```sql
/*
	To handle this, we take the difference of the registration date of each runner,
	and the base date (i.e. 2021-01-01). This difference divided by 7 and floored + 1,
	will give the week number of registration, which we can then group the runners by.
*/

WITH first_cte AS (
SELECT runner_id,
	registration_date - CAST('2021-01-01' AS DATE) AS days_diff
FROM runners),
second_cte AS (
SELECT *, FLOOR(days_diff/7) + 1 AS week_no
FROM first_cte)
SELECT week_no, 
	count(week_no) AS no_runners
FROM second_cte
GROUP BY week_no
ORDER BY week_no;
```

### 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
```sql
/*
	Let arrival time = pickup_time - order_time.
	We then take the average of this time for each runner.
*/

WITH first_cte AS (
SELECT r.runner_id, 
	r.pickup_time::timestamp - c.order_time::timestamp AS arrival_time
FROM runner_orders r
JOIN customer_orders c
ON r.order_id = c.order_id
WHERE pickup_time <> 'null'
)
SELECT runner_id, AVG(arrival_time) AS avg_arrival_time
FROM first_cte
GROUP BY runner_id
ORDER BY runner_id;
```

### 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
```sql
/*
	We combine the runner_orders table and customer_orders table, and take the diff
	between the pickup and order time. (assuming prep_time = pickup_time - order_time)
	From the results shown in the query, there is indeed a relationship between
	the no_of_pizzas ordered and the time it takes to prepare.
*/

WITH first_cte AS (
SELECT order_id, COUNT(order_id) AS no_of_pizzas, order_time
FROM customer_orders
GROUP BY order_id, order_time
ORDER BY order_id ASC
)
SELECT f.no_of_pizzas, 
	AVG(r.pickup_time::timestamp - f.order_time::timestamp) AS avg_prep_time
FROM first_cte f
JOIN runner_orders r
ON f.order_id = r.order_id
WHERE pickup_time <> 'null'
GROUP BY f.no_of_pizzas
ORDER BY no_of_pizzas;
```

### 4. What was the average distance travelled for each customer?
```sql
/*
	We get the customer_id and distance from customer_orders and runner_orders 
	respectively. Get the number component from the distance, cast as an integer.
	Finally, we take the average of the distances for each customer_id.
*/

WITH first_cte AS (
SELECT c.customer_id, 
	CAST(SUBSTRING(r.distance FROM '[0-9]+') AS INTEGER) AS dist_km
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
)
SELECT customer_id, ROUND(AVG(dist_km), 2) AS avg_dist_trav_km
FROM first_cte
GROUP BY customer_id
ORDER BY customer_id;
```

### 5. What was the difference between the longest and shortest delivery times for all orders?
```sql
/*
	Create a first cte to clean up the duration column to show only numbers.
	The second query gets the difference using max and min functions.
*/

WITH first_cte AS (
SELECT CAST(SUBSTRING(duration FROM '[0-9]+') AS INTEGER) AS del_time
FROM runner_orders
)
SELECT MAX(del_time) - MIN(del_time) AS diff_del_time
FROM first_cte;
```

### 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
```sql
/*
	The formula for speed = distance/time. These parameters are given in the
	runner_orders table, where distance = distance, time = duration.
	We will convert duration to hours, so that speed is in km/hr.
*/

WITH first_cte AS (
SELECT runner_id, order_id, 
	CAST(SUBSTRING(distance FROM '[0-9]+') AS INTEGER) AS distance,
	CAST(SUBSTRING(duration FROM '[0-9]+') AS INTEGER)/60.0 AS time
FROM runner_orders
WHERE distance <> 'null' or duration <> 'null'
)
SELECT runner_id, order_id, ROUND((distance/time), 2) AS speed_km_h
FROM first_cte
ORDER BY runner_id ASC, order_id ASC;
```

### 7. What is the successful delivery percentage for each runner?
```sql
/*
	We will use sum(case...) to satisfy orders in which there was no null.
	successful delivery percentage = (completed orders/total assigned orders)*100
*/

WITH first_cte AS (
SELECT runner_id, 
	SUM(CASE WHEN pickup_time <> 'null' THEN 1 END) AS completed_orders, 
	COUNT(*) AS total_ass_orders
FROM runner_orders 
GROUP BY runner_id
)
SELECT runner_id, 
	(completed_orders/CAST(total_ass_orders AS FLOAT))*100 AS delivery_percentage
FROM first_cte
ORDER BY delivery_percentage DESC;
```

## C. INGREDIENT OPTIMISATION

### 1. What are the standard ingredients for each pizza?
```sql
WITH first_cte AS (
SELECT pizza_id, 
	CAST(TRIM(UNNEST(STRING_TO_ARRAY(toppings, ','))) AS INTEGER) AS topping_id
FROM pizza_recipes
),
second_cte AS (
SELECT f.pizza_id, p.pizza_name, f.topping_id, t.topping_name
FROM first_cte f
JOIN pizza_toppings t
ON f.topping_id = t.topping_id
JOIN pizza_names p
ON f.pizza_id = p.pizza_id
ORDER BY f.pizza_id ASC, f.topping_id ASC)
SELECT pizza_name, 
	STRING_AGG(topping_name, ', ' ORDER BY topping_id) AS ingredients
FROM second_cte
GROUP BY pizza_name;
```

### 2. What was the most commonly added extra?
```sql
/*
	We made use of the unnest and string_to array just like the question before.
	Aggregation by count, and then sorting in a descending manner is the key.
*/

WITH first_cte AS (
SELECT 
	CAST(TRIM(UNNEST(STRING_TO_ARRAY(extras, ','))) AS INTEGER) AS extra_id 
FROM customer_orders 
WHERE extras <> 'null'
)
SELECT p.topping_name, COUNT(f.extra_id) AS extra_count
FROM first_cte f
JOIN pizza_toppings p
ON f.extra_id = p.topping_id
GROUP BY f.extra_id, p.topping_name
ORDER BY extra_count DESC
LIMIT 1;
```

### 3. What was the most common exclusion?
```sql
/*
	Similar to Q2, except we are dealing with exclusions and not extra.
*/

WITH first_cte AS (
SELECT 
	CAST(TRIM(UNNEST(STRING_TO_ARRAY(exclusions, ','))) AS INTEGER) AS exclusion_id 
FROM customer_orders 
WHERE exclusions <> 'null'
)
SELECT p.topping_name, COUNT(f.exclusion_id) AS exclusion_count
FROM first_cte f
JOIN pizza_toppings p
ON f.exclusion_id = p.topping_id
GROUP BY f.exclusion_id, p.topping_name
ORDER BY exclusion_count DESC
LIMIT 1;
```
