-- =============================================================
-- FINANCIAL CRIME ANALYTICS: WHICH MONITORING RULES CATCH THE
-- MOST LAUNDERING FOR THE FEWEST ALERTS?
-- IBM Transactions for Anti-Money Laundering (AMLworld), HI-Large
-- laundering patterns file. SYNTHETIC DATA: IBM simulated a whole
-- financial system because real labelled laundering data cannot be
-- published. No real people, banks or accounts.
-- Table: patterns (137,936 rows, imported from laundering_patterns.csv)
-- Tool: SQLite (DBeaver)
-- Import tip: set from_account and to_account to TEXT (see Step 0b)
-- Analysis by Smith Cudjoe
--
-- Business problem:
--   Monitoring rules raise alerts that analysts must review. A
--   financial crime operations lead wants to know which simple rules
--   catch the most laundering for the fewest alerts, and which rules
--   could be tightened or retired to reduce analyst workload.
--
-- What this file contains:
--   Only LAUNDERING transfers, grouped into schemes (fan-in, fan-out,
--   cycle and so on). So it shows how much laundering each rule
--   catches, but not how many false alerts a rule raises on normal
--   payments: that needs the full transactions file.
--
-- The six rules tested:
--   R1 Large transfer       $10,000 or more
--   R2 Just below $10,000   $9,000 to $9,999.99 (possible structuring)
--   R3 Many senders         receiving account paid by 5+ different accounts
--   R4 Many receivers       sending account pays 5+ different accounts
--   R5 Night-time           sent between midnight and 6am
--   R6 Foreign currency     not paid in US dollars
--
-- KPIs:
--   Alerts                 = transfers flagged by a rule
--   Scheme detection rate  = schemes with at least one alert / all schemes
--   Alerts per scheme      = alerts / schemes detected (analyst workload)
--   Unique schemes         = schemes that ONLY this rule detects
-- =============================================================


-- Step 0: Check the import
SELECT COUNT(*)                     AS row_count,
       COUNT(DISTINCT attempt_id)   AS schemes,
       MIN(timestamp)               AS first_transfer,
       MAX(timestamp)               AS last_transfer
FROM patterns;
-- Result:
-- |row_count|schemes|first_transfer  |last_transfer   |
-- |---------|-------|----------------|----------------|
-- |137,936  |16,467 |2022/08/01 00:08|2023/01/12 16:49|
-- 137,936 laundering transfers in 16,467 schemes, from 1 Aug 2022 to
-- 12 Jan 2023. Every row is laundering.


-- Step 0b: Check the account IDs were imported as text
-- Some IDs look like numbers in scientific notation (e.g. 800E49350
-- reads as 800 x 10^49350). If DBeaver imports them as numbers,
-- different accounts merge and R3/R4 give wrong results.
-- Every row should be text. If not, re-import with from_account and
-- to_account set to TEXT in DBeaver's import settings.
SELECT typeof(from_account)         AS from_account_type,
       typeof(to_account)           AS to_account_type,
       COUNT(*)                     AS row_count
FROM patterns
GROUP BY from_account_type, to_account_type;
-- Result:
-- |from_account_type|to_account_type|row_count|
-- |-----------------|---------------|---------|
-- |text             |text           |137,936  |
-- All 137,936 rows are text. (In a first run, DBeaver read 4,419
-- account IDs such as 800E49350 as numbers, merging them into 1,862
-- values and inflating R3 and R4. Importing as TEXT fixed it.)


-- Step 1: Exchange rates to US dollars
-- Amounts are in 15 currencies, so each is converted with an
-- approximate September 2022 rate (US dollars per unit).
DROP TABLE IF EXISTS fx_rates;
CREATE TABLE fx_rates (currency TEXT, usd_rate REAL);
INSERT INTO fx_rates VALUES
  ('US Dollar', 1.0),     ('Euro', 1.0),             ('UK Pound', 1.13),
  ('Swiss Franc', 1.03),  ('Canadian Dollar', 0.74), ('Australian Dollar', 0.67),
  ('Shekel', 0.29),       ('Saudi Riyal', 0.266),    ('Brazil Real', 0.19),
  ('Yuan', 0.145),        ('Mexican Peso', 0.05),    ('Ruble', 0.0165),
  ('Rupee', 0.0123),      ('Yen', 0.007),            ('Bitcoin', 19500.0);


-- Step 2: Prepare a clean transfers table
-- Converts amounts to US dollars and adds an amount band and the hour.
DROP TABLE IF EXISTS transfers;
CREATE TABLE transfers AS
SELECT p.attempt_id,
       p.pattern,
       replace(replace(substr(p.timestamp, 1, 7), '/', '-'), ':', '-') AS tx_month,
       CAST(substr(p.timestamp, 12, 2) AS INTEGER)                 AS tx_hour,
       p.from_bank,
       p.from_account,
       p.to_bank,
       p.to_account,
       p.payment_currency                                          AS currency,
       p.payment_format,
       ROUND(p.amount_paid * f.usd_rate, 2)                        AS amount_usd,
       CASE WHEN p.amount_paid * f.usd_rate < 1000     THEN '1. Under $1k'
            WHEN p.amount_paid * f.usd_rate < 5000     THEN '2. $1k-$5k'
            WHEN p.amount_paid * f.usd_rate < 9000     THEN '3. $5k-$9k'
            WHEN p.amount_paid * f.usd_rate < 10000    THEN '4. $9k-$10k'
            WHEN p.amount_paid * f.usd_rate < 50000    THEN '5. $10k-$50k'
            WHEN p.amount_paid * f.usd_rate < 1000000  THEN '6. $50k-$1M'
            ELSE                                            '7. $1M and over' END AS amount_band
FROM patterns p
LEFT JOIN fx_rates f ON f.currency = p.payment_currency;


-- Step 3: Count each account's different senders and receivers
DROP TABLE IF EXISTS receiver_counts;
CREATE TABLE receiver_counts AS
SELECT to_account, COUNT(DISTINCT from_account) AS senders
FROM transfers
GROUP BY to_account;

DROP TABLE IF EXISTS sender_counts;
CREATE TABLE sender_counts AS
SELECT from_account, COUNT(DISTINCT to_account) AS receivers
FROM transfers
GROUP BY from_account;


-- Step 4: Run the six rules on every transfer (1 = alert)
DROP TABLE IF EXISTS alerts;
CREATE TABLE alerts AS
SELECT t.attempt_id,
       t.pattern,
       t.tx_month,
       t.tx_hour,
       t.currency,
       t.payment_format,
       t.amount_usd,
       t.amount_band,
       CASE WHEN t.amount_usd >= 10000                       THEN 1 ELSE 0 END AS r1_large,
       CASE WHEN t.amount_usd >= 9000 AND t.amount_usd < 10000 THEN 1 ELSE 0 END AS r2_below_10k,
       CASE WHEN rc.senders >= 5                             THEN 1 ELSE 0 END AS r3_many_senders,
       CASE WHEN sc.receivers >= 5                           THEN 1 ELSE 0 END AS r4_many_receivers,
       CASE WHEN t.tx_hour < 6                               THEN 1 ELSE 0 END AS r5_night,
       CASE WHEN t.currency <> 'US Dollar'                   THEN 1 ELSE 0 END AS r6_foreign
FROM transfers t
LEFT JOIN receiver_counts rc ON rc.to_account   = t.to_account
LEFT JOIN sender_counts   sc ON sc.from_account = t.from_account;


-- Step 5: Prepare a schemes table (one row per laundering scheme)
-- A scheme counts as detected by a rule if ANY of its transfers
-- raised that rule's alert (MAX of the 1/0 flag).
DROP TABLE IF EXISTS schemes;
CREATE TABLE schemes AS
SELECT attempt_id,
       pattern,
       COUNT(*)                     AS transfers,
       MIN(tx_month)                AS start_month,
       MAX(r1_large)                AS r1,
       MAX(r2_below_10k)            AS r2,
       MAX(r3_many_senders)         AS r3,
       MAX(r4_many_receivers)       AS r4,
       MAX(r5_night)                AS r5,
       MAX(r6_foreign)              AS r6,
       CASE WHEN MAX(r1_large) + MAX(r2_below_10k) + MAX(r3_many_senders)
               + MAX(r4_many_receivers) + MAX(r5_night) + MAX(r6_foreign) > 0
            THEN 1 ELSE 0 END       AS detected
FROM alerts
GROUP BY attempt_id, pattern;


-- Q1: What data do we have? (always check before analysing)
SELECT COUNT(*)                     AS transfers,
       COUNT(DISTINCT attempt_id)   AS schemes,
       COUNT(DISTINCT currency)     AS currencies,
       MIN(tx_month)                AS first_month,
       MAX(tx_month)                AS last_month
FROM transfers;
-- Why it matters: confirms what the data covers before any conclusions are drawn.
-- Result:
-- |transfers|schemes|currencies|first_month|last_month|
-- |---------|-------|----------|-----------|----------|
-- |137,936  |16,467 |15        |2022-08    |2023-01   |
-- 15 currencies over six months.


-- Q2: Data checks: anything unusual?
SELECT 'Same account on both sides'          AS data_check, COUNT(*) AS row_count FROM transfers WHERE from_account = to_account
UNION ALL
SELECT 'Same bank on both sides',             COUNT(*) FROM transfers WHERE from_bank = to_bank
UNION ALL
SELECT 'Not paid by ACH',                     COUNT(*) FROM transfers WHERE payment_format <> 'ACH'
UNION ALL
SELECT 'Over $10 million',                    COUNT(*) FROM transfers WHERE amount_usd > 10000000
UNION ALL
SELECT 'No exchange rate',                    COUNT(*) FROM transfers WHERE amount_usd IS NULL;
-- Why it matters: shows quirks of the simulated data before they
-- distort the rules.
-- Result:
-- |data_check                |row_count|
-- |--------------------------|---------|
-- |Same account on both sides|451      |
-- |Same bank on both sides   |1,709    |
-- |Not paid by ACH           |17       |
-- |Over $10 million          |1,959    |
-- |No exchange rate          |0        |
-- Almost every transfer is by ACH and between two different banks.
-- 1,959 transfers are over $10 million, a quirk of the simulation.
-- None were removed: all are labelled laundering.


-- =============================================================
-- PART A: WHAT DOES LAUNDERING LOOK LIKE?
-- =============================================================

-- Q3: Laundering by pattern
SELECT pattern,
       COUNT(DISTINCT attempt_id)                                    AS schemes,
       COUNT(*)                                                      AS transfers,
       ROUND(1.0 * COUNT(*) / COUNT(DISTINCT attempt_id), 1)         AS transfers_per_scheme,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transfers), 1) AS share_pct
FROM transfers
GROUP BY pattern
ORDER BY transfers DESC;
-- Why it matters: each pattern needs a different kind of rule.
-- Result:
-- |pattern       |schemes|transfers|transfers_per_scheme|share_pct|
-- |--------------|-------|---------|--------------------|---------|
-- |SCATTER-GATHER|2,067  |26,978   |13.1                |19.6     |
-- |GATHER-SCATTER|2,054  |26,361   |12.8                |19.1     |
-- |STACK         |2,096  |23,624   |11.3                |17.1     |
-- |FAN-OUT       |2,040  |13,554   |6.6                 |9.8      |
-- |FAN-IN        |2,014  |13,287   |6.6                 |9.6      |
-- |CYCLE         |2,086  |12,340   |5.9                 |8.9      |
-- |BIPARTITE     |2,109  |12,174   |5.8                 |8.8      |
-- |RANDOM        |2,001  |9,618    |4.8                 |7.0      |
-- The eight patterns appear about 2,000 times each. Scatter-gather and
-- gather-scatter schemes are the largest, at about 13 transfers each.


-- Q4: Laundering by currency
SELECT currency,
       COUNT(*)                                                      AS transfers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transfers), 1) AS share_pct
FROM transfers
GROUP BY currency
ORDER BY transfers DESC;
-- Result:
-- |currency         |transfers|share_pct|
-- |-----------------|---------|---------|
-- |US Dollar        |57,981   |42.0     |
-- |Euro             |41,768   |30.3     |
-- |Yuan             |11,089   |8.0      |
-- |UK Pound         |7,536    |5.5      |
-- |Ruble            |6,522    |4.7      |
-- |Yen              |5,001    |3.6      |
-- |Rupee            |3,349    |2.4      |
-- |Australian Dollar|2,727    |2.0      |
-- |Shekel           |913      |0.7      |
-- |Canadian Dollar  |708      |0.5      |
-- |Brazil Real      |129      |0.1      |
-- |Swiss Franc      |81       |0.1      |
-- |Saudi Riyal      |77       |0.1      |
-- |Mexican Peso     |42       |0.0      |
-- |Bitcoin          |13       |0.0      |
-- 72% of laundering is in US dollars or euros, so 58% is in a
-- currency other than US dollars.


-- Q5: Laundering by payment format
SELECT payment_format,
       COUNT(*)                                                      AS transfers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transfers), 2) AS share_pct
FROM transfers
GROUP BY payment_format
ORDER BY transfers DESC;
-- Result:
-- |payment_format|transfers|share_pct|
-- |--------------|---------|---------|
-- |ACH           |137,919  |99.99    |
-- |Bitcoin       |13       |0.01     |
-- |Wire          |4        |0.0      |
-- 99.99% of laundering in this file is paid by ACH, so payment format
-- cannot separate laundering from normal payments here.


-- Q6: Laundering by amount band
SELECT amount_band,
       COUNT(*)                                                      AS transfers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transfers), 1) AS share_pct
FROM transfers
GROUP BY amount_band
ORDER BY amount_band;
-- Why it matters: shows how much laundering a $10,000 threshold can see.
-- Result:
-- |amount_band    |transfers|share_pct|
-- |---------------|---------|---------|
-- |1. Under $1k   |7,361    |5.3      |
-- |2. $1k-$5k     |29,515   |21.4     |
-- |3. $5k-$9k     |28,982   |21.0     |
-- |4. $9k-$10k    |7,275    |5.3      |
-- |5. $10k-$50k   |61,024   |44.2     |
-- |6. $50k-$1M    |843      |0.6      |
-- |7. $1M and over|2,936    |2.1      |
-- 44% of laundering transfers are $10k-$50k, so a $10,000 threshold
-- sees almost half. There is no spike just below $10,000: the $9k-$10k
-- band holds 5.3%, the same as each $1k band below it, so there is
-- no sign of structuring.


-- Q7: When does laundering happen?
SELECT CASE WHEN tx_hour < 6  THEN '1. Night (00-06)'
            WHEN tx_hour < 12 THEN '2. Morning (06-12)'
            WHEN tx_hour < 18 THEN '3. Afternoon (12-18)'
            ELSE                   '4. Evening (18-24)' END          AS time_of_day,
       COUNT(*)                                                      AS transfers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transfers), 1) AS share_pct
FROM transfers
GROUP BY time_of_day
ORDER BY time_of_day;
-- Result:
-- |time_of_day         |transfers|share_pct|
-- |--------------------|---------|---------|
-- |1. Night (00-06)    |20,017   |14.5     |
-- |2. Morning (06-12)  |40,153   |29.1     |
-- |3. Afternoon (12-18)|55,617   |40.3     |
-- |4. Evening (18-24)  |22,149   |16.1     |
-- Only 14.5% of laundering happens at night, although night is 25% of
-- the day: laundering is LESS likely at night than by day.


-- =============================================================
-- PART B: HOW WELL DO THE RULES WORK?
-- =============================================================

-- Step 6: One row per alert (which rule fired on which scheme)
DROP TABLE IF EXISTS rule_alerts;
CREATE TABLE rule_alerts AS
SELECT attempt_id, pattern, 'R1 Large transfer'     AS rule FROM alerts WHERE r1_large = 1
UNION ALL
SELECT attempt_id, pattern, 'R2 Just below $10k'            FROM alerts WHERE r2_below_10k = 1
UNION ALL
SELECT attempt_id, pattern, 'R3 Many senders'               FROM alerts WHERE r3_many_senders = 1
UNION ALL
SELECT attempt_id, pattern, 'R4 Many receivers'             FROM alerts WHERE r4_many_receivers = 1
UNION ALL
SELECT attempt_id, pattern, 'R5 Night-time'                 FROM alerts WHERE r5_night = 1
UNION ALL
SELECT attempt_id, pattern, 'R6 Foreign currency'           FROM alerts WHERE r6_foreign = 1;


-- Step 7: Rule performance table
DROP TABLE IF EXISTS rule_performance;
CREATE TABLE rule_performance AS
SELECT rule,
       COUNT(*)                                                      AS alerts,
       COUNT(DISTINCT attempt_id)                                    AS schemes_detected,
       ROUND(100.0 * COUNT(DISTINCT attempt_id) / (SELECT COUNT(*) FROM schemes), 1) AS scheme_detection_pct,
       ROUND(1.0 * COUNT(*) / COUNT(DISTINCT attempt_id), 1)         AS alerts_per_scheme
FROM rule_alerts
GROUP BY rule;


-- Q8: How does each rule perform?
SELECT * FROM rule_performance ORDER BY rule;
-- Why it matters: a good rule detects many schemes with few alerts each.
-- Result:
-- |rule               |alerts|schemes_detected|scheme_detection_pct|alerts_per_scheme|
-- |-------------------|------|----------------|--------------------|-----------------|
-- |R1 Large transfer  |64,803|12,688          |77.1                |5.1              |
-- |R2 Just below $10k |7,275 |4,675           |28.4                |1.6              |
-- |R3 Many senders    |45,393|5,492           |33.4                |8.3              |
-- |R4 Many receivers  |45,260|5,439           |33.0                |8.3              |
-- |R5 Night-time      |20,017|9,919           |60.2                |2.0              |
-- |R6 Foreign currency|79,955|13,465          |81.8                |5.9              |
-- R6 (foreign currency) and R1 (large transfer) detect the most schemes
-- (82% and 77%). R2 and R5 need the fewest alerts per scheme (1.6 and
-- 2.0). R3 and R4 need the most: 8.3 alerts for every scheme they
-- detect, the heaviest analyst workload.


-- Step 8: Schemes that only ONE rule detects
DROP TABLE IF EXISTS unique_schemes;
CREATE TABLE unique_schemes AS
SELECT rule, COUNT(*) AS unique_schemes
FROM (SELECT attempt_id, MIN(rule) AS rule
      FROM rule_alerts
      GROUP BY attempt_id
      HAVING COUNT(DISTINCT rule) = 1)
GROUP BY rule;


-- Q9: Which rules catch schemes that no other rule catches?
SELECT * FROM unique_schemes ORDER BY rule;
-- Why it matters: a rule with few unique schemes adds little
-- coverage, so retiring it saves alerts without losing much.
-- Result:
-- |rule               |unique_schemes|
-- |-------------------|--------------|
-- |R1 Large transfer  |726           |
-- |R2 Just below $10k |59            |
-- |R3 Many senders    |17            |
-- |R4 Many receivers  |17            |
-- |R5 Night-time      |162           |
-- |R6 Foreign currency|1,255         |
-- R6 and R1 each catch hundreds of schemes no other rule does. R3 and
-- R4 catch only 17 each, and R2 only 59: they add little coverage.


-- Step 9: Detection rate by pattern for each rule (% of schemes)
-- Columns r1 to r6 are the six rules.
DROP TABLE IF EXISTS rule_pattern_coverage;
CREATE TABLE rule_pattern_coverage AS
SELECT pattern,
       COUNT(*)                                       AS schemes,
       ROUND(100.0 * SUM(r1) / COUNT(*), 0)           AS r1,
       ROUND(100.0 * SUM(r2) / COUNT(*), 0)           AS r2,
       ROUND(100.0 * SUM(r3) / COUNT(*), 0)           AS r3,
       ROUND(100.0 * SUM(r4) / COUNT(*), 0)           AS r4,
       ROUND(100.0 * SUM(r5) / COUNT(*), 0)           AS r5,
       ROUND(100.0 * SUM(r6) / COUNT(*), 0)           AS r6,
       ROUND(100.0 * SUM(detected) / COUNT(*), 0)     AS any_rule
FROM schemes
GROUP BY pattern;


-- Q10: Which patterns does each rule detect?
SELECT * FROM rule_pattern_coverage ORDER BY any_rule;
-- Why it matters: shows which rule covers which pattern.
-- Result:
-- |pattern       |schemes|r1|r2|r3|r4|r5|r6|any_rule|
-- |--------------|-------|--|--|--|--|--|--|--------|
-- |BIPARTITE     |2,109  |80|25|19|18|45|83|96      |
-- |RANDOM        |2,001  |52|13|14|14|52|83|96      |
-- |FAN-IN        |2,014  |84|29|60|16|59|59|97      |
-- |FAN-OUT       |2,040  |84|26|17|61|58|86|97      |
-- |STACK         |2,096  |81|33|20|19|62|86|97      |
-- |CYCLE         |2,086  |56|17|15|15|57|85|98      |
-- |SCATTER-GATHER|2,067  |86|41|61|61|72|85|98      |
-- |GATHER-SCATTER|2,054  |93|43|62|61|77|86|99      |
-- Together the rules detect 96-99% of every pattern. R3 finds 60% of
-- fan-in schemes and R4 61% of fan-out schemes, but neither helps much
-- with any other pattern.


-- Q11: What slips through every rule?
SELECT pattern,
       COUNT(*)                                       AS schemes_missed,
       ROUND(AVG(transfers), 1)                       AS avg_transfers
FROM schemes
WHERE detected = 0
GROUP BY pattern
ORDER BY schemes_missed DESC;
-- Why it matters: these are the gaps a new rule would need to close.
-- Result:
-- |pattern       |schemes_missed|avg_transfers|
-- |--------------|--------------|-------------|
-- |BIPARTITE     |86            |1.1          |
-- |RANDOM        |80            |1.3          |
-- |FAN-IN        |67            |1.3          |
-- |FAN-OUT       |60            |1.2          |
-- |STACK         |55            |2.0          |
-- |CYCLE         |52            |2.2          |
-- |SCATTER-GATHER|45            |2.4          |
-- |GATHER-SCATTER|15            |2.3          |
-- 460 schemes (2.8%) slip through every rule. They are tiny: most have
-- only one or two transfers.


-- =============================================================
-- PART C: TUNING THE RULES
-- =============================================================

-- Step 10: Tightening R1: what if the threshold were higher?
DROP TABLE IF EXISTS threshold_tuning;
CREATE TABLE threshold_tuning AS
SELECT '1. $10,000' AS threshold, COUNT(*) AS alerts, COUNT(DISTINCT attempt_id) AS schemes_detected
FROM transfers WHERE amount_usd >= 10000
UNION ALL
SELECT '2. $25,000',  COUNT(*), COUNT(DISTINCT attempt_id) FROM transfers WHERE amount_usd >= 25000
UNION ALL
SELECT '3. $50,000',  COUNT(*), COUNT(DISTINCT attempt_id) FROM transfers WHERE amount_usd >= 50000
UNION ALL
SELECT '4. $100,000', COUNT(*), COUNT(DISTINCT attempt_id) FROM transfers WHERE amount_usd >= 100000;


-- Q12: How many alerts and schemes at each R1 threshold?
SELECT threshold,
       alerts,
       schemes_detected,
       ROUND(100.0 * schemes_detected / (SELECT COUNT(*) FROM schemes), 1) AS scheme_detection_pct
FROM threshold_tuning;
-- Why it matters: shows how many alerts a higher threshold saves,
-- and how much laundering it gives up.
-- Result:
-- |threshold  |alerts|schemes_detected|scheme_detection_pct|
-- |-----------|------|----------------|--------------------|
-- |1. $10,000 |64,803|12,688          |77.1                |
-- |2. $25,000 |4,105 |2,432           |14.8                |
-- |3. $50,000 |3,779 |2,205           |13.4                |
-- |4. $100,000|3,647 |2,129           |12.9                |
-- Raising the threshold from $10,000 to $25,000 would cut R1's alerts
-- by 94%, but scheme detection would fall from 77% to 15%. R1 should
-- not be tightened.


-- Step 11: Compare the current rules with a tuned set
DROP TABLE IF EXISTS rule_sets;
CREATE TABLE rule_sets AS
SELECT 'A. All 6 rules' AS rule_set,
       (SELECT COUNT(*) FROM rule_alerts)                                 AS alerts,
       (SELECT COUNT(*) FROM schemes WHERE detected = 1)                  AS schemes_detected
UNION ALL
SELECT 'B. Retire R2, R3 and R4',
       (SELECT COUNT(*) FROM rule_alerts
        WHERE rule IN ('R1 Large transfer', 'R5 Night-time', 'R6 Foreign currency')),
       (SELECT COUNT(*) FROM schemes WHERE r1 + r5 + r6 > 0);


-- Q13: Current rules against the tuned set
SELECT rule_set,
       alerts,
       schemes_detected,
       ROUND(100.0 * schemes_detected / (SELECT COUNT(*) FROM schemes), 1) AS scheme_detection_pct
FROM rule_sets;
-- Why it matters: the business case for the tuning plan.
-- Result:
-- |rule_set               |alerts |schemes_detected|scheme_detection_pct|
-- |-----------------------|-------|----------------|--------------------|
-- |A. All 6 rules         |262,703|16,007          |97.2                |
-- |B. Retire R2, R3 and R4|164,775|15,854          |96.3                |
-- Retiring R2, R3 and R4 cuts alerts by 37% (262,703 to 164,775) and
-- loses only 153 schemes: detection falls from 97.2% to 96.3%.


-- =============================================================
-- SUMMARY (synthetic data)
-- Data: 137,936 laundering transfers in 16,467 schemes. The file holds
--   only laundering, so it shows what each rule catches, not how many
--   false alerts it raises on normal payments.
-- Laundering: 72% is in US dollars or euros, 99.99% is paid by ACH,
--   44% is $10k-$50k, there is no structuring just below $10,000, and
--   laundering is less likely at night than by day.
-- Rules: all six together detect 97.2% of schemes. R1 (large transfer)
--   and R6 (foreign currency) do most of the work. R3 and R4 raise 8.3
--   alerts per scheme but catch only 17 schemes each that no other
--   rule catches; R2 catches only 59.
-- Recommendations:
--   1. Retire R2, R3 and R4: 37% fewer alerts for 0.9 points less
--      scheme detection.
--   2. Keep R1 at $10,000: a $25,000 threshold would miss most schemes.
--   3. Test R5 (night-time) and R6 (foreign currency) on the full
--      transactions file: they are broad rules that may also flag many
--      normal payments.
--   4. Track alerts per scheme and scheme detection rate every month.
-- =============================================================
