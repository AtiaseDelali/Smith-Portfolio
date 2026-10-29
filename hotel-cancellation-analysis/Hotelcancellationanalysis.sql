-- =============================================================
-- HOTEL BOOKING CANCELLATIONS: WHAT ARE THEY COSTING US?
-- A business analysis of two hotels in Portugal (Jul 2015 - Aug 2017)
-- Table: hotels (119,390 bookings, imported from hotels.csv)
-- Tool: SQLite (DBeaver)
--
-- Business problem:
--   Too many bookings are cancelled. Rooms are held for guests who
--   never arrive, and the hotel loses revenue it planned on.
--   Management wants to know WHERE the cancellations come from and
--   WHAT policy change would protect the most revenue.
--
-- Results are shown under each query.
-- Analysis by Smith Cudjoe.
-- =============================================================


-- Step 1: Prepare a clean bookings table
-- Converts columns to numbers, adds the number of nights and the
-- value of each booking (nightly rate x nights), and removes
-- bookings with no nights or an impossible nightly rate.
CREATE TABLE bookings AS
SELECT hotel,
       CAST(is_canceled AS INTEGER)                    AS is_canceled,
       CAST(lead_time AS INTEGER)                      AS lead_time,
       CAST(arrival_date_year AS INTEGER)              AS arrival_year,
       arrival_date_month                              AS arrival_month,
       market_segment,
       country,
       deposit_type,
       customer_type,
       CAST(is_repeated_guest AS INTEGER)              AS is_repeated_guest,
       CAST(total_of_special_requests AS INTEGER)      AS special_requests,
       CAST(stays_in_weekend_nights AS INTEGER)
         + CAST(stays_in_week_nights AS INTEGER)       AS nights,
       CAST(adr AS REAL)                               AS nightly_rate,
       ROUND(CAST(adr AS REAL) * (CAST(stays_in_weekend_nights AS INTEGER)
         + CAST(stays_in_week_nights AS INTEGER)), 2)  AS booking_value
FROM hotels
WHERE CAST(stays_in_weekend_nights AS INTEGER) + CAST(stays_in_week_nights AS INTEGER) > 0
  AND CAST(adr AS REAL) > 0
  AND CAST(adr AS REAL) < 1000;


-- Q1: How big is the problem? (the baseline KPIs)
SELECT COUNT(*)                                              AS total_bookings,
       SUM(is_canceled)                                      AS cancelled_bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct,
       ROUND(SUM(CASE WHEN is_canceled = 0 THEN booking_value END), 0) AS revenue_earned,
       ROUND(SUM(CASE WHEN is_canceled = 1 THEN booking_value END), 0) AS revenue_lost
FROM bookings;
-- Why it matters: this is the "size of the prize" for management.
-- Result: 
-- |total_bookings|cancelled_bookings|cancellation_rate_pct|revenue_earned|revenue_lost|
-- |--------------|------------------|---------------------|--------------|------------|
-- |117,429       |44,010            |37.5                 |25,996,324    |16,721,837  |


-- Q2: Which hotel has the bigger problem?
SELECT hotel,
       COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct,
       ROUND(SUM(CASE WHEN is_canceled = 1 THEN booking_value END), 0) AS revenue_lost
FROM bookings
GROUP BY hotel;
-- Why it matters: tells us where to focus first.
-- Result: 
-- |hotel       |bookings|cancellation_rate_pct|revenue_lost|
-- |------------|--------|---------------------|------------|
-- |City Hotel  |78,121  |42.2                 |10,879,660  |
-- |Resort Hotel|39,308  |28.1                 |5,842,177   |


-- Q3: Do guests who book far ahead cancel more?
SELECT CASE WHEN lead_time <= 7   THEN '1. Within a week'
            WHEN lead_time <= 30  THEN '2. 1-4 weeks'
            WHEN lead_time <= 90  THEN '3. 1-3 months'
            WHEN lead_time <= 180 THEN '4. 3-6 months'
            ELSE                       '5. Over 6 months' END AS booked_ahead,
       COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct
FROM bookings
GROUP BY booked_ahead
ORDER BY booked_ahead;
-- Why it matters: early bookings may need a different policy.
-- Result:
-- |booked_ahead    |bookings|cancellation_rate_pct|
-- |----------------|--------|---------------------|
-- |1. Within a week|18,608  |9.7                  |
-- |2. 1-4 weeks    |18,651  |28.1                 |
-- |3. 1-3 months   |29,306  |37.9                 |
-- |4. 3-6 months   |26,311  |44.9                 |
-- |5. Over 6 months|24,553  |57.2                 |


-- Q4: Which sales channel cancels the most?
SELECT market_segment,
       COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct,
       ROUND(SUM(CASE WHEN is_canceled = 1 THEN booking_value END), 0) AS revenue_lost
FROM bookings
GROUP BY market_segment
ORDER BY revenue_lost DESC;
-- Why it matters: shows which partners (travel agents, groups,
-- direct) cost the most when bookings fall through.
-- Result:
-- |market_segment|bookings|cancellation_rate_pct|revenue_lost|
-- |--------------|--------|---------------------|------------|
-- |Online TA     |56,110  |36.9                 |10,227,646  |
-- |Groups        |19,558  |61.7                 |2,800,544   |
-- |Offline TA/TO |23,886  |34.6                 |2,486,958   |
-- |Direct        |12,366  |15.4                 |993,410     |
-- |Corporate     |5,213   |18.9                 |196,383     |
-- |Aviation      |231     |22.1                 |16,578      |
-- |Complementary |63      |7.9                  |270         |
-- |Undefined     |2       |100                  |48          |


-- Q5: Does asking for a deposit reduce cancellations?
SELECT deposit_type,
       COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct
FROM bookings
GROUP BY deposit_type;
-- Why it matters: tests whether the current deposit policy works.
-- Look closely at the result: is it what you expected?
-- Result:
-- |deposit_type|bookings|cancellation_rate_pct|
-- |------------|--------|---------------------|
-- |No Deposit  |102,681 |28.7                 |
-- |Non Refund  |14,586  |99.4                 |
-- |Refundable  |162     |22.2                 |


-- Q5b: Who makes the non-refundable bookings?
SELECT COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct,
       ROUND(100.0 * SUM(CASE WHEN country = 'PRT' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_from_portugal,
       ROUND(100.0 * SUM(CASE WHEN market_segment IN ('Groups', 'Offline TA/TO') THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_groups_or_agents,
       ROUND(AVG(lead_time), 0)                              AS avg_days_booked_ahead,
       ROUND(SUM(CASE WHEN is_canceled = 1 THEN booking_value END), 0) AS cancelled_value
FROM bookings
WHERE deposit_type = 'Non Refund';
-- Why it matters: before changing the deposit policy, we need to
-- understand why the current one seems to fail.
-- Result:
-- |bookings|cancellation_rate_pct|pct_from_portugal|pct_groups_or_agents|avg_days_booked_ahead|cancelled_value|
-- |--------|---------------------|-----------------|--------------------|---------------------|---------------|
-- |14,586  |99.4                 |97.2             |97.2                |213                  |3,598,937      |
-- These look like rooms blocked in advance by groups and travel agents
-- and released later, not ordinary guests (no-deposit bookings are
-- made 90 days ahead on average). If the hotel kept these deposits,
-- about 3.6M euros of the "lost" revenue was actually collected, so
-- the real loss is nearer 13.1M euros. Next step: confirm with
-- Reservations and Finance how these bookings are recorded.


-- Q6: Do loyal (repeat) guests cancel less?
SELECT CASE WHEN is_repeated_guest = 1 THEN 'Repeat guest' ELSE 'New guest' END AS guest_type,
       COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct
FROM bookings
GROUP BY guest_type;
-- Why it matters: shows the value of a loyalty programme.
-- Result:
-- |guest_type  |bookings|cancellation_rate_pct|
-- |------------|--------|---------------------|
-- |New guest   |114,156 |38.1                 |
-- |Repeat guest|3,273   |16.2                 |


-- Q7: Do guests who make special requests cancel less?
SELECT CASE WHEN special_requests = 0 THEN 'No requests' ELSE '1 or more requests' END AS requests,
       COUNT(*)                                              AS bookings,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct
FROM bookings
GROUP BY requests;
-- Why it matters: guests who ask for something (a cot, a view,
-- a late check-in) are more committed. A pre-arrival email asking
-- about their stay could be a cheap way to reduce cancellations.
-- Result:
-- |requests          |bookings|cancellation_rate_pct|
-- |------------------|--------|---------------------|
-- |1 or more requests|48,290  |22                   |
-- |No requests       |69,139  |48.3                 |


-- Q8: Which months are busiest? (stays that actually happened)
SELECT arrival_month,
       COUNT(*)                                              AS stays,
       ROUND(AVG(nightly_rate), 2)                           AS avg_nightly_rate
FROM bookings
WHERE is_canceled = 0
GROUP BY arrival_month
ORDER BY stays DESC;
-- Why it matters: helps plan staffing and pricing.
-- Result:
-- |arrival_month|stays|avg_nightly_rate|
-- |-------------|-----|----------------|
-- |August       |8,483|144.69          |
-- |July         |7,768|131.77          |
-- |May          |6,952|107.29          |
-- |October      |6,720|89.34           |
-- |March        |6,504|79.01           |
-- |April        |6,449|99.64           |
-- |June         |6,296|116.56          |
-- |September    |6,259|109.56          |
-- |February     |5,245|74.17           |
-- |November     |4,531|72.7            |
-- |December     |4,206|82.73           |
-- |January      |4,006|68.94           |


-- Q9: Which months lose the most revenue to cancellations?
SELECT arrival_month,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct,
       ROUND(SUM(CASE WHEN is_canceled = 1 THEN booking_value END), 0) AS revenue_lost
FROM bookings
GROUP BY arrival_month
ORDER BY revenue_lost DESC;
-- Why it matters: shows when a stricter policy would matter most.
-- Result:
-- |arrival_month|cancellation_rate_pct|revenue_lost|
-- |-------------|---------------------|------------|
-- |August       |38.1                 |3,027,558   |
-- |July         |37.8                 |2,487,317   |
-- |June         |41.8                 |1,916,096   |
-- |May          |40.1                 |1,712,912   |
-- |April        |41.1                 |1,610,609   |
-- |September    |39.5                 |1,387,654   |
-- |October      |38.5                 |1,152,733   |
-- |March        |32.5                 |981,723     |
-- |December     |35.9                 |712,800     |
-- |February     |33.8                 |671,431     |
-- |November     |31.8                 |564,604     |
-- |January      |30.9                 |496,401     |


-- Q10: The business case
-- If the hotel asked for a deposit on bookings made more than
-- 90 days ahead that currently pay no deposit, how much revenue
-- is at stake?
SELECT COUNT(*)                                              AS bookings_affected,
       SUM(is_canceled)                                      AS cancelled,
       ROUND(100.0 * SUM(is_canceled) / COUNT(*), 1)         AS cancellation_rate_pct,
       ROUND(SUM(CASE WHEN is_canceled = 1 THEN booking_value END), 0) AS revenue_lost
FROM bookings
WHERE lead_time > 90
  AND deposit_type = 'No Deposit';
-- Why it matters: if even a quarter of these cancellations were
-- prevented (or paid for by a deposit), the hotel would recover
-- about 25% of this lost revenue.
-- Result:
-- |bookings_affected|cancelled|cancellation_rate_pct|revenue_lost|
-- |-----------------|---------|---------------------|------------|
-- |39,178           |14,307   |36.5                 |7,030,422   |


-- =============================================================
-- SUMMARY
-- Problem: 37.5% of bookings are cancelled, losing up to 16.7M euros.
-- Main causes: bookings made far in advance, group bookings and
--   online travel agents. The City Hotel is hit hardest (42.2%).
-- Recommendations:
--   1. Ask for a deposit on bookings made more than 90 days ahead.
--   2. Review group and agent contracts: release unsold blocked rooms
--      earlier and limit rooms held without payment.
--   3. Investigate the non-refundable bookings with Reservations and Finance.
--   4. Encourage engagement: pre-arrival emails inviting special requests,
--      and a loyalty offer for repeat guests.
-- Expected benefit: about 1.76M euros protected over the 26 months of
--   data (roughly 0.8M euros a year) if a quarter of long-lead
--   cancellations are prevented (Q10).
-- =============================================================