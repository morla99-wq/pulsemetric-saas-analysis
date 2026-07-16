----------------------------
-- 1. Acquisition & Signups
-------------------------------------------------------------------
-- Q1: How many users signed up each month? is there a growth trend?
-------------------------------------------------------------------
SELECT date_trunc('month', signup_date)::date AS signup_month,
		COUNT(*) AS new_users
FROM users
GROUP BY 1
ORDER BY 1;

-------------------------------------------------------------------------------------------------------------
-- Q2: Which acquisition channel brings in the most users overall, and has the channel mix shifted over time?
-------------------------------------------------------------------------------------------------------------
--Overall totals by channel
SELECT acquisition_channel, COUNT(*) AS users
FROM users
GROUP BY 1
ORDER BY 2 DESC;

-- Channel mix by quarter
SELECT date_trunc('quarter', signup_date)::date AS quarter,
	   acquisition_channel,
	   COUNT(*) AS users,
	   ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY
date_trunc('quarter', signup_date)), 1) AS pct_of_quarter
FROM users
GROUP BY 1, 2, signup_date
ORDER BY 1, 2;

----------------------------------------------------------------------
-- Q3: What's the distribution of signups by country and company size?
----------------------------------------------------------------------
SELECT country, company_name, COUNT(*) AS users
FROM users
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

----------------------------------------------------------------------
-- Q4: Do Certain industries skew toward certain acquisition channels?
----------------------------------------------------------------------
SELECT industry, acquisition_channel, COUNT(*) AS users
FROM users
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-----------------------------
-- 2. Activation & Engagement
--------------------------------------------------------------------------------------------------------------------
-- Q5: What % of users generated zero product events after signing up("ghost signups"). and does it vary by channel?
--------------------------------------------------------------------------------------------------------------------
WITH event_counts As (
	SELECT u.user_id, u.acquisition_channel, COUNT(pe.event_id) AS n_events
	FROM users u
	LEFT JOIN product_events pe ON pe.user_id = u.user_id
	GROUP BY 1, 2
)
SELECT acquisition_channel,
	   COUNT(*) FILTER (WHERE n_events = 0) AS ghost_users,
	   COUNT(*) AS total_users,
	   ROUND(100.0 * COUNT(*) FILTER (WHERE n_events = 0) / COUNT(*), 1) AS ghost_pct
FROM event_counts
GROUP BY 1
ORDER BY ghost_pct DESC;

------------------------------------------------------------------------------------------------------------------------
-- Q6: What % of users are "activated" (create_project AND invite_teammate within 14 days), by channel and company size?
------------------------------------------------------------------------------------------------------------------------
WITH first14 AS (
	SELECT pe.user_id,
		   BOOL_OR(pe.event_type ='create_project') AS did_create,
		   BOOL_OR(pe.event_type = 'invite_teammate') AS did_invite
	FROM product_events pe
	JOIN users u ON u.user_id = pe.user_id
	WHERE pe.event_timestamp <= u.signup_date + INTERVAL '14 days'
	GROUP BY pe.user_id
)
SELECT u.acquisition_channel, u.company_size,
	COUNT(*) AS total_users,
	COUNT(*) FILTER (WHERE f.did_create AND f.did_invite) AS activated_users,
	ROUND(100.0 * COUNT(*) FILTER (WHERE f.did_create AND f.did_invite) / COUNT(*), 1) AS activation_rate_pct
FROM users u
LEFT JOIN first14 f ON f.user_id = u.user_id
GROUP BY 1, 2
ORDER BY activation_rate_pct DESC;

--------------------------------------------------------------------------------------------------------
-- Q7: What are the most common event types, and does integration/export usage correlate with plan tier?
--------------------------------------------------------------------------------------------------------
-- Most common events overall
SELECT event_type, COUNT(*) AS events
FROM product_events
GROUP BY 1
ORDER BY 2 DESC;

-- Integration & export usage by current plan
WITH current_plan AS (
	SELECT DISTINCT ON (user_id) user_id, plan_id
	FROM subscriptions
	ORDER BY user_id, start_date DESC
)
SELECT p.plan_name,
		COUNT(*) FILTER (WHERE pe.event_type = 'use_integration') AS integration_events,
		COUNT(*) FILTER (WHERE pe.event_type = 'export_report')   AS export_events
FROM product_events pe
JOIN current_plan cp ON cp.user_id = pe.user_id
JOIN plans p ON p.plan_id = cp.plan_id
GROUP BY p.plan_name
ORDER BY integration_events DESC;

-----------------------------------------------------------------
-- Q8: Build a weekly (WAU) and monthly (MAU) active-users trend.
-----------------------------------------------------------------
-- Monthly active users (WAU)
SELECT date_trunc('month', event_timestamp)::date AS month,
		COUNT(DISTINCT user_id) AS mau
FROM product_events
GROUP BY 1
ORDER BY 1;

-- Weekly active users (MAU)
SELECT date_trunc('week', event_timestamp)::date AS week,
	  	COUNT(DISTINCT user_id) AS wau
FROM product_events
GROUP BY 1
ORDER BY 1;

------------------------
-- 3. Retention & Churn
-------------------------------------------------
-- Q9: What is the overal subcription churn rate?
-------------------------------------------------
WITH last_sub AS (
	SELECT DISTINCT ON (user_id) user_id, status
	FROM subscriptions
	ORDER BY user_id, start_date DESC
)
SELECT COUNT(*) FILTER (WHERE status = 'canceled') AS churned_users,
	   COUNT(*) AS total_users,
	   ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'canceled') / COUNT(*), 1) AS churn_rate_pct
	   FROM last_sub;

----------------------------------------------------------------------------------
-- Q10: What's the most common cancellation reason, and does it vary by plan tier?
----------------------------------------------------------------------------------
SELECT p.plan_name, s.cancellation_reason, COUNT(*) AS cnt
FROM subscriptions s
JOIN plans p ON p.plan_id = s.plan_id
WHERE s.status = 'canceled'
GROUP BY 1, 2
ORDER BY p.plan_name, cnt DESC;

----------------------------------------------------------------------------------------------------------------------------
-- Q11: Build a monthly cohort retention table: of users who signed up in month X, what % are still retained N months later?
----------------------------------------------------------------------------------------------------------------------------
WITH cohorts AS (
  SELECT user_id, date_trunc('month', signup_date)::date AS cohort_month
  FROM users
),
churn AS (
  SELECT user_id, MIN(end_date) AS churn_date
  FROM subscriptions
  WHERE status = 'canceled'
  GROUP BY user_id
),
months AS (
  SELECT generate_series(0, 18) AS month_number
),
cohort_totals AS (
  SELECT cohort_month, COUNT(*) AS cohort_size
  FROM cohorts
  GROUP BY 1
)
SELECT c.cohort_month,
       m.month_number,
       ct.cohort_size,
       COUNT(*) FILTER (
         WHERE ch.churn_date IS NULL
            OR ch.churn_date > c.cohort_month + (m.month_number * INTERVAL '1 month')
       ) AS retained_users,
       ROUND(100.0 * COUNT(*) FILTER (
         WHERE ch.churn_date IS NULL
            OR ch.churn_date > c.cohort_month + (m.month_number * INTERVAL '1 month')
       ) / ct.cohort_size, 1) AS retention_pct
FROM cohorts c
JOIN cohort_totals ct ON ct.cohort_month = c.cohort_month
CROSS JOIN months m
LEFT JOIN churn ch ON ch.user_id = c.user_id
GROUP BY 1, 2, 3
ORDER BY 1, 2;

--------------------------------------------------------------------------------------------------------------
-- Q12: Do users who file a support ticket churn at higher or lower rate than users who never contact support?
--------------------------------------------------------------------------------------------------------------
WITH last_sub As (
	SELECT DISTINCT ON (user_id) user_id, status
	FROM subscriptions
	ORDER BY user_id, start_date DESC
),
ticket_filers AS (
	SELECT DISTINCT user_id FROM support_tickets
)
SELECT CASE WHEN tf.user_id IS NOT NULL THEN  'Filed a ticket' ELSE 'Never contacted support' END AS segment,
	COUNT(*) as users,
	COUNT(*) FILTER (WHERE ls.status = 'canceled') AS churned,
	ROUND(100.0 * COUNT(*) FILTER (WHERE ls.status = 'canceled') / COUNT(*), 1) AS chun_rate_pct
FROM last_sub ls
LEFT JOIN ticket_filers tf ON tf.user_id = ls.user_id
GROUP BY 1;

----------------------------------------------------------------------------------------
-- Q13: Is there a relationship between first-30-day engagement and long-term retention?
----------------------------------------------------------------------------------------
WITH engagement AS (
	SELECT pe.user_id, COUNT(*) AS events_30d
	FROM product_events pe
	JOIN users u ON u.user_id = pe.user_id
	WHERE pe.event_timestamp <= u.signup_date + INTERVAL '30 days'
	GROUP BY pe.user_id
),
tiers AS (
	SELECT user_id,
		CASE WHEN events_30d = 0 THEN '0 events'
			 WHEN events_30d <= 5 THEN '1-5 events'
			 WHEN events_30d <= 20 THEN '6-20 events'
			 ELSE '21+ events'
		END AS engagement_tier
	FROM engagement
),
last_sub AS (
	SELECT DISTINCT ON (user_id) user_id, status
	FROM subscriptions
	ORDER BY user_id, start_date DESC
)
SELECT t.engagement_tier,
		COUNT(*) AS users,
		ROUND(100.0 * COUNT(*) FILTER (WHERE ls.status = 'canceled') / COUNT(*), 1) AS churn_rate_pct
FROM tiers t
JOIN last_sub ls ON ls.user_id = t.user_id
GROUP BY 1
ORDER BY 1;

----------------------------
-- 4. Revenue & Monetization
--------------------------------------------------------------------------------------------------------------------------------
-- Q14: What is current total MRR, how has it trended monthly, and how does it break into New/Expansion/Contraction/Churned MRR?
--------------------------------------------------------------------------------------------------------------------------------
-- Current total MRR
WITH current_sub AS (
	SELECT DISTINCT ON (user_id) user_id, mrr, status
	FROM subscriptions
	ORDER BY user_id, start_date DESC
)
SELECT SUM(mrr) AS total_mrr
FROM current_sub
WHERE status <> 'canceled';

-- MRR trend: snapshot at each month using active date ranges
SELECT date_trunc('month', m)::date AS month,
	   SUM(s.mrr) AS mrr
FROM generate_series (
	(SELECT MIN(start_date) FROM subscriptions),
	(SELECT MAX(start_date) FROM subscriptions),
	INTERVAL '1 month') AS m
JOIN subscriptions s
	ON s.start_date <= m
	AND (s.end_date IS NULL OR s.end_date > m)
GROUP BY 1
ORDER BY 1;

-- New MRR: each user's first subscription, grouped by its start month
WITH first_sub AS (
	SELECT DISTINCT ON (user_id) user_id, start_date, mrr
	FROM subscriptions
	ORDER by user_id, start_date ASC
)
SELECT date_trunc('month', start_date)::date AS month, SUM(mrr) AS new_mrr
FROM first_sub
GROUP BY 1
ORDER BY 1;

-- Expansion / Contraction MRR: compare each user's consecutive subscription segments
WITH ordered AS (
	SELECT user_id, start_date, mrr,
				LAG(mrr) OVER (PARTITION BY user_id ORDER BY start_date) AS prev_mrr
	FROM subscriptions
)
SELECT date_trunc('month', start_date)::date AS month,
	   SUM(mrr - prev_mrr) FILTER (WHERE mrr > prev_mrr) AS expansion_mrr,
	   SUM(mrr - prev_mrr) FILTER (WHERE mrr < prev_mrr) AS contraction_mrr
FROM ordered
WHERE prev_mrr IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Churned MRR: MRR lost at cancellation
SELECT date_trunc('month', start_date)::date AS month, SUM(mrr) AS churned_mrr
FROM subscriptions
WHERE status = 'canceled'
GROUP BY 1
ORDER BY 1;

----------------------------------------------------------------------------------------------------------
-- Q15: What's the ARPU by plan tier and by acquisition channel? Which channel brings highest-value users?
----------------------------------------------------------------------------------------------------------
-- ARPU by plan tier
WITH current_sub AS (
	SELECT DISTINCT ON (user_id) user_id, plan_id, mrr,status
	FROM subscriptions
	ORDER BY user_id, start_date DESC
)
SELECT p.plan_name, ROUND(AVG(cs.mrr), 2) AS arpu
FROM current_sub cs
JOIN plans p ON p.plan_id = cs.plan_id
WHERE cs.status <> 'canceled'
GROUP BY 1
ORDER BY arpu DESC;

--ARPU by acquisition channel
WITH current_sub AS (
	SELECT DISTINCT ON (user_id) user_id, mrr, status
	FROM subscriptions
	ORDER BY user_id, start_date DESC
)
SELECT u.acquisition_channel, ROUND(AVG(cs.mrr), 2) AS arpu, COUNT(*) AS users
FROM current_sub cs
JOIN users u ON u.user_id = cs.user_id
WHERE cs.status <> 'canceled'
GROUP BY 1
ORDER BY arpu DESC;

-------------------------------------------------------------------------------------------------
-- Q16: What share of revenue comes from annual vs. monthly billing, and do customers churn less?
-------------------------------------------------------------------------------------------------
WITH current_sub AS (
  SELECT DISTINCT ON (s.user_id) s.user_id, s.mrr, s.status, p.billing_cycle
  FROM subscriptions s
  JOIN plans p ON p.plan_id = s.plan_id
  ORDER BY s.user_id, s.start_date DESC
)
SELECT billing_cycle,
       SUM(mrr) FILTER (WHERE status <> 'canceled') AS active_mrr,
       ROUND(100.0 * SUM(mrr) FILTER (WHERE status <> 'canceled')
             / SUM(SUM(mrr) FILTER (WHERE status <> 'canceled')) OVER (), 1) AS pct_of_revenue,
       COUNT(*) AS users,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'canceled') / COUNT(*), 1) AS churn_rate_pct
FROM current_sub
GROUP BY 1;

----------------------------------------------------------------------------------------------------------------------------------
-- Q17: If leadership wants 20% MRR growth next quater, which lever looks most promising: signups, activation, churn, or upgrades?
----------------------------------------------------------------------------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM users WHERE signup_date >= CURRENT_DATE - INTERVAL '90 days') AS signups_last_90d,
  (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'canceled') / COUNT(*), 1)
     FROM (SELECT DISTINCT ON (user_id) status FROM subscriptions ORDER BY user_id, start_date DESC) t
  ) AS overall_churn_pct,
  (SELECT ROUND(AVG(mrr), 2)
     FROM (SELECT DISTINCT ON (user_id) mrr, status FROM subscriptions ORDER BY user_id, start_date DESC) t
    WHERE status <> 'canceled'
  ) AS arpu;

----------------------
-- 5. Customer Support
-----------------------------------------------------------------------------------
-- Q18: What's the average resolution time (hours) by ticket priority and category?
-----------------------------------------------------------------------------------
SELECT priority, category,
		ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600), 1) AS
avg_resolution_hours,
		COUNT(*) AS tickets
FROM support_tickets
WHERE resolved_at IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2;

----------------------------------------------------------------------------------------------------
-- Q19: What's the average satisfaction rating by category, and which category most needs attention?
----------------------------------------------------------------------------------------------------
SELECT category,
		ROUND(AVG(satisfaction_rating), 2) AS avg_satisfaction,
		COUNT(satisfaction_rating) AS rated_tickets
FROM support_tickets
WHERE satisfaction_rating IS NOT NULL
GROUP BY 1
ORDER BY avg_satisfaction ASC;

----------------------------------------------------------------------------------
-- Q20: Do "Urgent" tickets actually get resolved faster than "Low" priority ones?
----------------------------------------------------------------------------------
SELECT priority,
		ROUND(AVG(EXTRACT(EPOCH FROM(resolved_at - created_at)) / 3600), 1) AS
avg_resolution_hours
FROM support_tickets
WHERE resolved_at IS NOT NULL
GROUP BY 1
ORDER BY CASE priority WHEN 'Urgent' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3
WHEN 'Low' THEN 4 END;

------------------------
-- 6. Stretch / Advanced
--------------------------------------------------------------------------------------------------------------------------
-- Q21: Segment users into engagement tiers (Ghost/Light/Medium/Power) and profile each tier's average MRR and churn rate.
--------------------------------------------------------------------------------------------------------------------------
WITH events_per_user AS (
  SELECT user_id, COUNT(*) AS total_events
  FROM product_events
  GROUP BY 1
),
tiers AS (
  SELECT u.user_id,
    CASE WHEN COALESCE(e.total_events, 0) = 0 THEN 'Ghost'
         WHEN e.total_events <= 20 THEN 'Light'
         WHEN e.total_events <= 80 THEN 'Medium'
         ELSE 'Power'
    END AS engagement_tier
  FROM users u
  LEFT JOIN events_per_user e ON e.user_id = u.user_id
),
current_sub AS (
  SELECT DISTINCT ON (user_id) user_id, mrr, status
  FROM subscriptions
  ORDER BY user_id, start_date DESC
)
SELECT t.engagement_tier,
       COUNT(*) AS users,
       ROUND(AVG(cs.mrr), 2) AS avg_mrr,
       ROUND(100.0 * COUNT(*) FILTER (WHERE cs.status = 'canceled') / COUNT(*), 1) AS churn_rate_pct
FROM tiers t
JOIN current_sub cs ON cs.user_id = t.user_id
GROUP BY 1
ORDER BY avg_mrr DESC;

-----------------------------------------------------------------------------------------------------------
-- Q22: Build a churn-prediction feature table (days since last login, ticket count, plan, current status).
-----------------------------------------------------------------------------------------------------------
WITH last_event AS (
  SELECT user_id, MAX(event_timestamp) AS last_event_at
  FROM product_events
  GROUP BY 1
),
tickets AS (
  SELECT user_id, COUNT(*) AS ticket_count
  FROM support_tickets
  GROUP BY 1
),
current_sub AS (
  SELECT DISTINCT ON (user_id) user_id, plan_id, status
  FROM subscriptions
  ORDER BY user_id, start_date DESC
)
SELECT u.user_id,
       p.plan_name,
       cs.status,
       COALESCE(EXTRACT(DAY FROM (CURRENT_DATE - le.last_event_at)), 999) AS days_since_last_login,
       COALESCE(t.ticket_count, 0) AS ticket_count
FROM users u
JOIN current_sub cs ON cs.user_id = u.user_id
JOIN plans p ON p.plan_id = cs.plan_id
LEFT JOIN last_event le ON le.user_id = u.user_id
LEFT JOIN tickets t ON t.user_id = u.user_id;

