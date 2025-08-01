-- Case Study #1 – Danny's Diner
--Solutions for this challenge are written in **MySQL**.


-- 1. What is the total amount each customer spent at the restaurant?
-- in order to calculate this, we have to join the sales table with the menu table 

SELECT s.customer_id,
       SUM(m.price) AS total_amount
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;


-- 2. How many days has each customer visited the restaurant?
-- In order to solve this, we will group each customer_id by the distinct order date

SELECT customer_id,
       COUNT(DISTINCT order_date) AS days_visited
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
/* We will use a ROW_NUMBER, to assign integer values to each rows in an ascending manner. however, we also need to partition by the 
 customer id, since we want to start FROM 1 for each customer, and then finally order by product_id and order_date to get the earliest date
 and smallest product_id (assuming smallest product_id is also a criteria). 
 Note: Some customer_id make two different purchases ON the same day.., so we assume the smallest product_id is the first purchase */

WITH ranked_table AS
  (SELECT *,
          ROW_NUMBER() OVER (PARTITION BY customer_id
                             ORDER BY order_date ASC, product_id ASC) AS rn
   FROM sales)
SELECT r.customer_id,
       m.product_name
FROM ranked_table r
JOIN menu m ON r.product_id = m.product_id
WHERE r.rn = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
/* In order to handle this, we will group the product_id by the count of this product_id, we then proceed to join it to the menu table
 to get the product name */

WITH purchase_freq AS
  (SELECT product_id,
          COUNT(product_id) AS count_purchased
   FROM sales
   GROUP BY product_id)
SELECT m.product_name,
       p.count_purchased
FROM menu m
JOIN purchase_freq p ON m.product_id = p.product_id
ORDER BY count_purchased DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
/* In order to handle this question, we did a combination of two common table expressiONs (CTE) i.e. first_cte and second_cte
 to get the product_id with the most frquency for each customer, window function row_number() over(... came in handy */

WITH first_cte AS
  (SELECT customer_id,
          product_id,
          COUNT(product_id) AS freq_product_id
   FROM sales
   GROUP BY customer_id,
            product_id),
     second_cte AS
  (SELECT customer_id,
          product_id,
          freq_product_id,
          ROW_NUMBER() over(PARTITION BY customer_id
                            ORDER BY freq_product_id DESC, product_id ASC) AS ranking
   FROM first_cte)
SELECT s.customer_id,
       m.product_name
FROM second_cte s
JOIN menu m ON s.product_id = m.product_id
WHERE ranking = 1
ORDER BY customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
-- In order to tackle this problem, we use the same analogy as with the previous example. Using two cte, and a row_number window function.

WITH first_cte AS
  (SELECT s.*
   FROM sales s
   JOIN members m ON s.customer_id = m.customer_id
   WHERE m.join_date < s.order_date),
     second_cte AS
  (SELECT *,
          ROW_NUMBER() OVER(PARTITION BY customer_id
                            ORDER BY order_date ASC, product_id ASC) AS ranking
   FROM first_cte)
SELECT s.customer_id,
       m.product_name
FROM second_cte s
JOIN menu m ON s.product_id = m.product_id
WHERE ranking = 1
ORDER BY customer_id;

-- 7. Which item was purchased just before the customer became a member?
/* In order to tackle this problem, we have to follow similar methodology like question 6, however the expression
 WHERE m.join_date < s.order_date) now becomes m.join_date > s.order_date
 then instead of ranking by order date asc, we then rank by order date desc, to get the closest date to the join date */

WITH first_cte AS
  (SELECT s.*
   FROM sales s
   JOIN members m ON s.customer_id = m.customer_id
   WHERE m.join_date > s.order_date),
     second_cte AS
  (SELECT *,
          ROW_NUMBER() OVER(PARTITION BY customer_id
                            ORDER BY order_date DESC, product_id ASC) AS ranking
   FROM first_cte)
SELECT s.customer_id,
       m.product_name
FROM second_cte s
JOIN menu m ON s.product_id = m.product_id
WHERE ranking = 1
ORDER BY customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
/* In order to approach this, we have to combine all three tables to get key elements like before membership rows and price of items
 using a group by, we can aggregate the product_id by count to give total items, and the price column by sum to give total amount */

WITH first_cte AS
  (SELECT s.customer_id,
          s.product_id,
          mn.price
   FROM sales s
   JOIN members m ON s.customer_id = m.customer_id
   JOIN menu mn ON s.product_id = mn.product_id
   WHERE m.join_date > s.order_date)
SELECT customer_id,
       COUNT(product_id) AS total_items,
       SUM(price) AS amount_spent
FROM first_cte
GROUP BY customer_id
ORDER BY customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
/* In order to handle this, we have to employ two CTEs, one to handle the inclusion of the price table, the order to do the CASE evaluation
 to satisfy the condition that each food item is 10 points per dollar, and sushi is 2x (10 points per dollar), i.e. 20 points per dollar */

WITH first_cte AS
  (SELECT s.customer_id,
          me.product_name,
          me.price
   FROM sales s
   JOIN menu me ON s.product_id = me.product_id),
     second_cte AS
  (SELECT customer_id,
          product_name,
          price,
          CASE WHEN product_name = 'sushi' THEN price*20 ELSE price*10 END AS points
   FROM first_cte)
SELECT customer_id,
       SUM(points) AS total_points
FROM second_cte
GROUP BY customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items,  not just sushi - how many points do customer A and B have at the end of January?
/* In order to address this problem, we need to get a column containing the one week duration. Then, we filter rows, depending on whether
 they fall under the range of join_date and one_week_duration, or not.
 Multiple ctes are introduced to address the problem, every step of the way. */

WITH cte1 AS
  (SELECT customer_id AS cus_id,
          join_date,
          DATE_ADD(join_date, INTERVAL 6 DAY) AS one_week_interval
   FROM members),
     cte2 AS
  (SELECT s.customer_id,
          s.order_date,
          c.join_date,
          c.one_week_interval,
          me.product_name,
          me.price
   FROM sales s
   JOIN cte1 c ON s.customer_id = c.cus_id
   JOIN menu me ON s.product_id = me.product_id),
     cte3 AS
  (SELECT *,
          CASE WHEN order_date BETWEEN join_date AND one_week_interval THEN price * 20 WHEN order_date NOT BETWEEN join_date AND one_week_interval
                   AND product_name = 'sushi' THEN price * 20 ELSE price * 10 END AS points
   FROM cte2
   WHERE MONTH(order_date) = 1)
SELECT customer_id,
       SUM(points) AS total_points
FROM cte3
GROUP BY customer_id
ORDER BY customer_id ASC;

-- Bonus Question 1. Join All The Things.
/* The idea is to join all three tables together, i.e. sales, menu and members. 
 use a left join, when joining members, so the customer_id c gets included.
 finally, create a condition where, if order date is on the join date or after, it's a Y, else an N */

WITH cte AS
  (SELECT s.customer_id,
          s.order_date,
          me.product_name,
          me.price,
          m.join_date
   FROM sales s
   JOIN menu me ON s.product_id = me.product_id
   LEFT JOIN members m ON s.customer_id = m.customer_id)
SELECT c.customer_id,
       c.order_date,
       c.product_name,
       c.price,
       CASE WHEN `order_date` >= `join_date` THEN 'Y' ELSE 'N' END AS 'member'
FROM cte c
ORDER BY customer_id ASC,
         order_date ASC,
         product_name ASC;

-- Bonus Question 2. Rank All The Things.
-- Same approach as bonus question 1, but case and window function is introduced to correctly assign the ranks.

WITH cte AS
  (SELECT s.customer_id,
          s.order_date,
          me.product_name,
          me.price,
          m.join_date
   FROM sales s
   JOIN menu me ON s.product_id = me.product_id
   LEFT JOIN members m ON s.customer_id = m.customer_id),
     cte2 AS
  (SELECT c.customer_id,
          c.order_date,
          c.product_name,
          c.price,
          CASE WHEN `order_date` >= `join_date` THEN 'Y' ELSE 'N' END AS 'member'
   FROM cte c
   ORDER BY customer_id ASC,
            order_date ASC,
            product_name ASC)
SELECT *,
       CASE WHEN member = 'Y' THEN RANK() OVER(PARTITION BY customer_id
                                               ORDER BY member DESC, order_date ASC) ELSE 'null' END AS ranking
FROM cte2;
