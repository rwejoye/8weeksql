-- ================================
-- 🍕 Case Study #2 – Pizza Runner
-- ================================

------------[view 1. : Runner Orders]--------------------
DROP VIEW IF EXISTS clean_runner_orders;
CREATE VIEW clean_runner_orders AS 
SELECT
	-- select the integer columns as is, no chance of problematic nulls
	order_id, 
	runner_id,
	-- use a case statement to handle the varchar columns to handle all the null cases: null, 'null' and ''
	(CASE 
		WHEN pickup_time = 'null' 
			OR pickup_time = '' 
				THEN NULL ELSE pickup_time END)::timestamp AS pickup_time,
	COALESCE(CASE 
				WHEN distance IS NULL OR distance = 'null' OR distance = '' THEN NULL
				ELSE CAST(REGEXP_SUBSTR(distance, '^[0-9]+.?[0-9]+') AS FLOAT)
			END, NULL) AS distance,	
	COALESCE(CASE 
				WHEN duration IS NULL OR duration = 'null' OR duration = '' THEN NULL
				ELSE CAST(REGEXP_SUBSTR(duration, '^[0-9]+.?[0-9]+') AS FLOAT)
			END, NULL) AS duration,	
	CASE 
		WHEN cancellation = 'null' OR cancellation = '' 
				THEN NULL ELSE cancellation END AS cancellation	
	FROM pizza_runner.runner_orders;


------------------[view 2: Customer Orders]----------------------
DROP VIEW IF EXISTS clean_customer_orders;
CREATE VIEW clean_customer_orders AS
WITH duped_table AS (
	SELECT 
		order_id, 
		customer_id, 
		pizza_id,
		-- only exclusions and extras have problematic nulls, so we handle them
		CASE 
			WHEN exclusions IS NULL OR exclusions = 'null' OR exclusions = '' THEN NULL
			ELSE exclusions END AS exclusions,
		CASE 
			WHEN extras IS NULL OR extras = 'null' OR extras = '' THEN NULL
			ELSE extras END AS extras,
		order_time,
		-- Identify duplicate rows. Note this table has a composite primary key, based on order_id, customer_id, extras and exclusions
		ROW_NUMBER() OVER(
						PARTITION BY order_id, customer_id, exclusions, extras
						ORDER BY order_time) AS rn
	FROM pizza_runner.customer_orders
	)
	SELECT
		order_id,
		customer_id,
		pizza_id,
		exclusions,
		extras,
		order_time
	FROM duped_table
	-- drop the rows containing duplicates
	WHERE rn = 1;

-- ---------- A. PIZZA METRICS ----------

-- [1] How many pizzas were ordered?
-- count(*) gets the total count of all the rows, which corresponds to pizza ordered

SELECT COUNT(*) 
	AS total_pizzas_ordered
FROM 
	clean_customer_orders;

-- [2] How many unique customer orders were made?
/*
	To handle this, we first do a distinct combination of order_id and customer_id,
	this drops duplicate, and only gives us a unique order per customer.
*/

SELECT COUNT(DISTINCT(order_id, customer_id)) 
	AS unique_customer_orders
FROM 
	clean_customer_orders;

-- [3] How many successful orders were delivered by each runner?
/*
	From the clean_runner_orders view, a successful order is made, when there was no 
	cancellation either from restaurant or customer in the cancellation column.
*/

SELECT 
	runner_id, COUNT(runner_id) AS successful_orders 
FROM 
	clean_runner_orders 
WHERE 
	cancellation IS NULL OR cancellation !~* 'cancel'
GROUP BY 
	runner_id
ORDER BY 
	runner_id;

-- [4] How many of each type of pizza was delivered?
/*
	We combined two views and one table, i.e. the clean_customer_orders,  clean_runner_orders and pizza_names. The views were to get the 
	successful deliveries, and the pizza_ids associated with it. The last table was to get the name of each pizza id.
*/

SELECT pi.pizza_name, 
	COUNT(pi.pizza_name) AS no_delivered
FROM 
	clean_customer_orders c
JOIN 
	clean_runner_orders p ON c.order_id = p.order_id
JOIN 
	pizza_names pi ON c.pizza_id = pi.pizza_id
WHERE 
	p.cancellation IS NULL OR cancellation !~* 'cancel'
GROUP BY 
	pi.pizza_name
ORDER BY 
	pi.pizza_name;

-- [5] How many Vegetarian and Meatlovers were ordered by each customer?
-- We used a sum(case ...) to create new columns and count for each pizza type.

SELECT
	c.customer_id,
	SUM(CASE WHEN p.pizza_name = 'Meatlovers' THEN 1 ELSE 0 END) AS Meatlovers,
	SUM(CASE WHEN p.pizza_name = 'Vegetarian' THEN 1 ELSE 0 END) AS Vegetarian
FROM 
	clean_customer_orders c
JOIN 
	pizza_names p
	ON 
		c.pizza_id = p.pizza_id
GROUP BY
	c.customer_id
ORDER BY
	c.customer_id;

-- [6] What was the maximum number of pizzas delivered in a single order?
/* 
	The max pizza delivered in a single order is the count of each order_ids, sorted in
	a descending manner, and first entry (limit 1) gives the max.
*/

SELECT 
	COUNT(order_id) AS count_of_order
FROM 
	clean_customer_orders
GROUP BY 
	order_id
ORDER BY 
	COUNT(order_id) DESC
LIMIT 1;

-- [7] For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
/*
	1. Combine the clean_customer_orders and clean_runner_orders views to filter for delivered orders.
	2. To get a pizza with a change, either or both the exclusions or extras columns,
	have at least a value. If both columns for a customer is N/A, then there's no change.
*/

SELECT
	cc.customer_id,
	SUM(CASE 
			WHEN exclusions IS NOT NULL OR extras IS NOT NULL
				THEN 1 ELSE 0 
		END) AS had_change,
	SUM(CASE
			WHEN exclusions IS NULL AND extras IS NULL
				THEN 1 ELSE 0
		END) AS had_no_change
FROM
	clean_runner_orders cr
JOIN 
	clean_customer_orders cc
ON
	cr.order_id = cc.order_id
WHERE
	cancellation IS NULL OR cancellation !~* 'cancel'
GROUP BY
	cc.customer_id;

-- [8] How many pizzas were delivered that had both exclusions and extras?
/*
	1. Filter the customer_orders table by joining with the runner_orders table
	to get the pizzas that were delivered. i.e. no cancellation.
	2. Do a count all on this table. i.e. COUNT(*)
*/

SELECT
	COUNT(cc.pizza_id) AS delivered_pizzas_all_toppings
FROM
	clean_runner_orders cr
JOIN 
	clean_customer_orders cc
ON
	cr.order_id = cc.order_id
WHERE
	(cr.cancellation IS NULL OR cr.cancellation !~* 'cancel')
	AND cc.exclusions IS NOT NULL AND cc.extras IS NOT NULL;

-- [9] What was the total volume of pizzas ordered for each hour of the day?
/*
	We will use the extract function to get the hour from the order_time and make a group by out of that.
*/

SELECT
	EXTRACT(HOUR FROM order_time) AS order_hour,
	COUNT(*) AS volume_ordered
FROM
	clean_customer_orders
GROUP BY
	EXTRACT(HOUR FROM order_time);

-- [10] What was the volume of orders for each day of the week?
/*
	1. To get the day of the week, i.e. Monday, etc, we use the TO_CHAR function applied to the order time.
	2. For ordering our result, by the correct order of the week, we use the EXTRACT function to extract by the DOW.
*/

SELECT
	TO_CHAR(order_time, 'Day') AS day_of_week,
	COUNT(*) AS volume_pizzas_ordered
FROM
	clean_customer_orders
GROUP BY
	TO_CHAR(order_time, 'Day'), EXTRACT(DOW FROM order_time)
ORDER BY
	EXTRACT(DOW FROM order_time);

-- ---------- B. RUNNER AND CUSTOMER EXPERIENCE ----------

-- [1] How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
/*
	1. We will get the one week period for each row.
	2. Runners will be grouped according to their occurence in the one week period.
*/

SELECT
	week_starts,
	week_ends,
	COUNT(runner_id) AS no_of_runners
FROM (
	SELECT
		'2021-01-01'::DATE + 
			((registration_date - '2021-01-01'::DATE)/7) * 7 AS week_starts,
		'2021-01-01'::DATE + 
			((registration_date - '2021-01-01'::DATE)/7) * 7 + 6 AS week_ends,
			runner_id
	FROM
		runners) runners_week_table
GROUP BY
	week_starts, 
	week_ends
ORDER BY
	week_starts;

-- [2] What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
/*
	1. The feature for pickup_time is a timestamp.
	2. We will extract the minutes component from it and find the average for each runner.
*/

SELECT
	runner_id,
	ROUND(AVG(EXTRACT(MINUTES FROM pickup_time)), 2) AS avg_min_picku_time
FROM 
	clean_runner_orders
GROUP BY
	runner_id
ORDER BY
	runner_id;

-- [3] Is there any relationship between the number of pizzas and how long the order takes to prepare?
/*
	1. Let preparaton time = pickup_time - order_time
	2. To establish this relationship, we need to combine the clean_customer_orders and the clean_runner_orders views.
*/

SELECT
	no_of_orders,
	AVG(prep_time) AS avg_prep_time
FROM
	(SELECT
		cc.order_id,
		COUNT(cc.order_id) AS no_of_orders,
		-- average preparation time for each order_id group
		AVG(DATE_TRUNC('minute',cr.pickup_time - cc.order_time)) AS prep_time
	FROM
		clean_customer_orders cc
	JOIN
		clean_runner_orders cr
	ON
		cc.order_id = cr.order_id
	WHERE
		-- removes the rows where an order was cancelled
		cr.cancellation IS NULL
		OR cr.cancellation !~* 'cancel'
	GROUP BY
		cc.order_id) preptime_table
GROUP BY
	no_of_orders
ORDER BY
	no_of_orders DESC;

-- [4] What was the average distance travelled for each customer?
/*
	1.We need to combine the clean_customer_orders and clean_runner_orders views.
	2. For each customer, we take the average of distance.
*/

SELECT
	cc.customer_id,
	ROUND(AVG(cr.distance)) AS avg_dist_travelled
FROM
	clean_customer_orders cc
JOIN
	clean_runner_orders cr
ON
	cc.order_id = cr.order_id
WHERE
	cr.cancellation IS NULL
	OR cr.cancellation !~* 'cancel'
GROUP BY
	cc.customer_id
ORDER BY
	cc.customer_id;

-- [5] What was the difference between the longest and shortest delivery times for all orders?
/*
	1. The difference between the maximum and minimum duration from the clean_runner_orders view.
*/

SELECT
	MAX(duration) - MIN(duration) AS diff_delivery_time
FROM
	clean_runner_orders
WHERE
	cancellation IS NULL
	OR cancellation !~* 'cancel';

-- [6] What was the average speed for each runner for each delivery and do you notice any trend for these values?
/*
	1. Speed = distance/time. For the clean_runner_orders view,  distance = distance, time = duration.
	2. To achieve speed in km/hr, we convert the duration to hours (i.e. duration/60). Distance is good, as it is already in km.
*/

SELECT
	runner_id,
	order_id,
	/* conversion to speed takes place next: multiplied by 1.0 to force floating-point
	division */
	ROUND((distance*1.0/(NULLIF(duration, 0)/60))::NUMERIC, 1) AS speed
FROM
	clean_runner_orders
WHERE
	cancellation IS NULL
	OR cancellation !~* 'cancel';

-- [7] What is the successful delivery percentage for each runner?
/*
	1. Let successful delivery percentage = (successful orders delivered/total assigned orders) * 100.
	2. We will get these parameters for each runner and calculate the percentages.
*/

WITH orders_status_table AS (
	SELECT
		runner_id,
		COUNT(*) FILTER(WHERE cancellation IS NULL) AS successful_orders,
		COUNT(*) AS assigned_orders
	FROM
		clean_runner_orders
	GROUP BY
		runner_id
)
SELECT
	runner_id,
	ROUND((successful_orders*1.0/NULLIF(assigned_orders, 0))*100, 2)
		AS successful_delivery_percentage
FROM
	orders_status_table
ORDER BY
	runner_id;

-- ---------- C. INGREDIENT OPTIMISATION ----------

--[1] What are the standard ingredients for each pizza?
/*
	1. To analyse this problem, we make use of the pizza_recipes and pizza_toppings tables.
	2. Unnest the entries of the toppings in the pizza_recipes; get what they stand for from the pizza_toppings table, and then aggregate.
*/

SELECT
	sp.pizza_id,
	STRING_AGG(pt.topping_name, ', ') AS toppings
FROM(
	SELECT
		pizza_id,
		/* this step: separate the toppings by the delimiter ',', convert each separation
		 to an array, and trim any trailing or leading spaces, then cast to INT */
		TRIM(UNNEST(STRING_TO_ARRAY(toppings, ',')))::INT AS topping_id
	FROM
		pizza_recipes) sp
JOIN
	pizza_toppings pt
ON
	sp.topping_id = pt.topping_id
GROUP BY
	sp.pizza_id
ORDER BY
	sp.pizza_id;

-- [2] What was the most commonly added extra?
/*
	1. Made use of the functions to unnest the extras, like we did in the previous question.
	2. Finally, we used a rank window function, to get the most ordered extra. This was used instead of desc limit 1, 
	because of situations where the most ordered extra is more than one.
*/

WITH extras_table AS (
	SELECT 
		CAST(TRIM(UNNEST(STRING_TO_ARRAY(extras, ','))) AS INTEGER) AS extras_id
	FROM 
		clean_customer_orders
),
extras_rank_table AS (
	SELECT
		pt.topping_name,
		COUNT(pt.topping_name) AS no_extras,
		RANK() OVER(ORDER BY COUNT(pt.topping_name) DESC)
			AS rn
	FROM
		extras_table e
	JOIN
		pizza_toppings pt
	ON
		e.extras_id = pt.topping_id
	GROUP BY
		e.extras_id, pt.topping_name
)
SELECT
	topping_name,
	no_extras
FROM
	extras_rank_table
WHERE
	rn = 1;

-- [3] What was the most common exclusion?
/*
	Similar to Q2, except we are dealing with exclusions and not extra.
*/

WITH exclusions_table AS (
	SELECT 
		CAST(TRIM(UNNEST(STRING_TO_ARRAY(exclusions, ','))) AS INTEGER) AS exclusions_id
	FROM 
		clean_customer_orders
),
exclusions_rank_table AS (
	SELECT
		pt.topping_name,
		COUNT(pt.topping_name) AS no_exclusions,
		RANK() OVER(ORDER BY COUNT(pt.topping_name) DESC)
			AS rn
	FROM
		exclusions_table e
	JOIN
		pizza_toppings pt
	ON
		e.exclusions_id = pt.topping_id
	GROUP BY
		e.exclusions_id, pt.topping_name
)
SELECT
	topping_name,
	no_exclusions
FROM
	exclusions_rank_table
WHERE
	rn = 1;

/* 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
		* Meat Lovers
		* Meat Lovers - Exclude Beef
		* Meat Lovers - Extra Bacon
		* Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
*/

/*
	1. We need to replace the ids with their actual names across the pizza_id,
	exclusions and extras columns in the clean_customer_orders view.
	2. We used cross lateral joins and regexp_split_to_table for some advanced
	functionalities, getting the names of the exclusions and extras.
	3. Multiple CTEs came in handy for combining different tables to give a total result.
	4. Finally, with CASE and nested concatenations, we were able to get the final result the question demanded.
*/

WITH exclusions_cte AS (
	SELECT
		cc.order_id,
		cc.customer_id,
		cc.pizza_id,
		STRING_AGG(pt.topping_name, ', ') AS exclusions_name,
		ROW_NUMBER() OVER(ORDER BY cc.order_id) AS rn_exclusions
	FROM
		clean_customer_orders cc
	CROSS JOIN LATERAL(                                                                  
		SELECT
			TRIM(x)::INT AS exclusions_id
		FROM
			REGEXP_SPLIT_TO_TABLE(coalesce(cc.exclusions, '0'), ',') AS x
	) exclusions_part
	LEFT JOIN
		pizza_toppings pt
	ON
		exclusions_part.exclusions_id = pt.topping_id
	GROUP BY
		cc.order_id, cc.customer_id, cc.pizza_id, cc.exclusions, cc.extras
	ORDER BY
		cc.order_id
),
extras_cte AS (
	SELECT
		cc.order_id,
		cc.customer_id,
		cc.pizza_id,
		STRING_AGG(pt.topping_name, ', ') AS extras_name,
		ROW_NUMBER() OVER(ORDER BY cc.order_id) AS rn_extras
	FROM
		clean_customer_orders cc
	CROSS JOIN LATERAL(                                                                  
		SELECT
			TRIM(x)::INT AS extras_id
		FROM
			REGEXP_SPLIT_TO_TABLE(coalesce(cc.extras, '0'), ',') AS x
	) extras_part
	LEFT JOIN
		pizza_toppings pt
	ON
		extras_part.extras_id = pt.topping_id
	GROUP BY
		cc.order_id, cc.customer_id, cc.pizza_id, cc.exclusions, cc.extras
	ORDER BY
		cc.order_id	
),
third_cte AS (
	SELECT
		exc.order_id,
		pn.pizza_name,
		exc.exclusions_name,
		ext.extras_name
	FROM
		exclusions_cte exc
	JOIN 
		extras_cte ext
	ON
		exc.rn_exclusions = ext.rn_extras
	JOIN
		pizza_names pn
	ON
		exc.pizza_id = pn.pizza_id
)
SELECT
	order_id,
	CONCAT(
		pizza_name,
		CASE
			WHEN exclusions_name IS NOT NULL THEN ' - Exclude ' || exclusions_name
			ELSE ''
		END,
		CASE
			WHEN extras_name IS NOT NULL THEN ' - Extra ' || extras_name
			ELSE ''
		END
	) AS order_item
FROM 
	third_cte
ORDER BY
	order_id;
