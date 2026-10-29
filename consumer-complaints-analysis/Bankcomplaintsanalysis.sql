-- =============================================================
-- CONSUMER COMPLAINTS: WHERE SHOULD OPERATIONS FOCUS FIRST?
-- CFPB Consumer Complaint Database: a recent extract of 4,991
-- complaints (95% received 24-29 August 2026), all products
-- and all companies
-- Table: complaints (imported from Complaint_concise.csv)
-- Tool: SQLite (DBeaver)
-- Analysis by Smith Cudjoe
--
-- Business problem:
--   Companies must respond to complaints forwarded by the
--   regulator (the CFPB) within 15 days. A late response is a
--   missed SLA (service level agreement) and a regulatory risk.
--   An operations leader wants to know which products and issues
--   drive complaints and late responses, how companies compare
--   with their peers, and where to focus first.
--
-- Peer groups:
--   1. Credit bureaus (3): Experian, TransUnion, Equifax
--   2. Large banks (6): JPMorgan Chase, Bank of America, Wells Fargo,
--      Citibank, Capital One, U.S. Bank
--   3. All other companies
--
-- KPIs:
--   Complaints         = number of complaints
--   Timely rate (SLA)  = complaints answered on time / all complaints
--   Late responses     = complaints NOT answered on time
--   Relief rate        = closed complaints where the company gave the
--                        customer money or another fix / all closed
--                        complaints (a sign the company got it wrong)
-- =============================================================


-- Step 0: Check the column names after importing
SELECT * FROM complaints LIMIT 5;


-- Step 1: Prepare a clean complaints table
-- Turns the date into YYYY-MM-DD, gives each company a short name
-- and a peer group, and adds 1/0 flags so the KPIs are easy to calculate.
CREATE TABLE complaints_clean AS
WITH dated AS (
    SELECT *,
           -- CFPB dates look like 8/22/2025 (month/day/year).
           -- This rebuilds them as 2025-08-22 so they sort correctly.
           CASE
             WHEN "Date received" LIKE '%/%/%' THEN
                  substr("Date received", -4) || '-' ||
                  printf('%02d', CAST(substr("Date received", 1, instr("Date received", '/') - 1) AS INTEGER)) || '-' ||
                  printf('%02d', CAST(substr(substr("Date received", instr("Date received", '/') + 1), 1,
                                      instr(substr("Date received", instr("Date received", '/') + 1), '/') - 1) AS INTEGER))
             ELSE substr("Date received", 1, 10)      -- already YYYY-MM-DD
           END AS date_received
    FROM complaints
)
SELECT "Complaint ID"                         AS complaint_id,
       date_received,
       substr(date_received, 1, 7)            AS month,
       "Product"                              AS product,
       "Issue"                                AS issue,
       "Sub-issue"                            AS sub_issue,
       "Company"                              AS company,
       CASE
         WHEN "Company" IN ('Experian Information Solutions Inc.',
                            'TRANSUNION INTERMEDIATE HOLDINGS, INC.',
                            'EQUIFAX, INC.')              THEN '1. Credit bureaus (3)'
         WHEN upper("Company") LIKE '%JPMORGAN%'
           OR upper("Company") LIKE '%BANK OF AMERICA%'
           OR upper("Company") LIKE '%WELLS FARGO%'
           OR upper("Company") LIKE '%CITIBANK%'
           OR upper("Company") LIKE '%CAPITAL ONE%'
           OR upper("Company") LIKE '%U.S. BANCORP%'      THEN '2. Large banks (6)'
         ELSE '3. All other companies'
       END                                    AS company_group,
       "Company response to consumer"         AS company_response,
       CASE WHEN "Timely response?" = 'Yes' THEN 1 ELSE 0 END AS is_timely,
       CASE WHEN "Timely response?" = 'No'  THEN 1 ELSE 0 END AS is_late,
       CASE WHEN "Company response to consumer" LIKE 'Closed%' THEN 1 ELSE 0 END AS is_closed,
       CASE WHEN "Company response to consumer" IN ('Closed with monetary relief',
                                                    'Closed with non-monetary relief')
            THEN 1 ELSE 0 END                 AS got_relief
FROM dated;


-- Q0: What data do we have? (always check before analysing)
SELECT COUNT(*)                    AS complaints,
       MIN(date_received)          AS first_date,
       MAX(date_received)          AS last_date,
       COUNT(DISTINCT company)     AS companies,
       COUNT(DISTINCT product)     AS products
FROM complaints_clean;
-- Why it matters: confirms what the data covers before any conclusions are drawn.
-- Result:
-- |complaints|first_date|last_date |companies|products|
-- |----------|----------|----------|---------|--------|
-- |4,991     |2025-08-22|2026-08-29|183      |11      |
-- A few complaints go back to 2025, but 95% were received between
-- 24 and 29 August 2026, so this is a snapshot, not a long-term trend.


-- Q1: How big is the problem? (the baseline KPIs)
SELECT COUNT(*)                                               AS complaints,
       ROUND(100.0 * SUM(is_timely) / COUNT(*), 1)            AS timely_rate_pct,
       SUM(is_late)                                           AS late_responses,
       ROUND(100.0 * SUM(got_relief) / SUM(is_closed), 1)     AS relief_rate_pct
FROM complaints_clean;
-- Why it matters: the starting point every other number is compared with.
-- Result:
-- |complaints|timely_rate_pct|late_responses|relief_rate_pct|
-- |----------|---------------|--------------|---------------|
-- |4,991     |98.6           |68            |42.6           |


-- Q2: When were the complaints received? (monthly volume)
SELECT month,
       COUNT(*)                                               AS complaints,
       SUM(is_late)                                           AS late_responses
FROM complaints_clean
GROUP BY month
ORDER BY month;
-- Why it matters: shows whether a trend can be read from the data.
-- Result:
-- |month  |complaints|late_responses|
-- |-------|----------|--------------|
-- |2025-08|1         |1             |
-- |2025-09|1         |1             |
-- |2025-10|2         |0             |
-- |2025-11|1         |1             |
-- |2025-12|2         |2             |
-- |2026-03|2         |1             |
-- |2026-04|14        |9             |
-- |2026-05|18        |3             |
-- |2026-06|17        |7             |
-- |2026-07|70        |11            |
-- |2026-08|4,863     |32            |


-- Q3: What are the top 5 issues?
SELECT issue,
       COUNT(*)                                               AS complaints,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints_clean), 1) AS share_pct,
       SUM(is_late)                                           AS late_responses
FROM complaints_clean
GROUP BY issue
ORDER BY complaints DESC
LIMIT 5;
-- Why it matters: a few issues usually drive most of the volume.
-- Result:
-- |issue                                                          |complaints|share_pct|late_responses|
-- |---------------------------------------------------------------|----------|---------|--------------|
-- |Incorrect information on your report                           |2,886     |57.8     |4             |
-- |Problem with a company's investigation into an existing problem|997       |20.0     |0             |
-- |Improper use of your report                                    |711       |14.2     |3             |
-- |Attempts to collect debt not owed                              |73        |1.5      |6             |
-- |Managing an account                                            |46        |0.9      |4             |
-- "Incorrect information on your report" alone is 58% of all complaints.


-- Q3b: What exactly is incorrect?
SELECT sub_issue,
       COUNT(*)                                               AS complaints,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints_clean), 1) AS share_of_all_pct
FROM complaints_clean
WHERE issue = 'Incorrect information on your report'
GROUP BY sub_issue
ORDER BY complaints DESC
LIMIT 3;
-- Why it matters: finds the root cause behind the biggest issue.
-- Result:
-- |sub_issue                          |complaints|share_of_all_pct|
-- |-----------------------------------|----------|----------------|
-- |Information belongs to someone else|1,807     |36.2            |
-- |Account information incorrect      |748       |15.0            |
-- |Account status incorrect           |197       |3.9             |
-- In 36% of ALL complaints, the consumer says the information on their
-- credit report belongs to someone else: a data-matching problem.


-- Q4: Which products generate complaints and late responses?
SELECT product,
       COUNT(*)                                               AS complaints,
       SUM(is_late)                                           AS late_responses,
       ROUND(100.0 * SUM(is_timely) / COUNT(*), 1)            AS timely_rate_pct,
       ROUND(100.0 * SUM(got_relief) / SUM(is_closed), 1)     AS relief_rate_pct
FROM complaints_clean
GROUP BY product
ORDER BY complaints DESC;
-- Why it matters: tells us which product teams own the problem.
-- Result:
-- |product                                                |complaints|late_responses|timely_rate_pct|relief_rate_pct|
-- |-------------------------------------------------------|----------|--------------|---------------|---------------|
-- |Credit reporting or other personal consumer reports    |4,619     |7             |99.8           |44.1           |
-- |Debt collection                                        |146       |28            |80.8           |27.8           |
-- |Checking or savings account                            |68        |5             |92.6           |15.6           |
-- |Credit card                                            |46        |3             |93.5           |27.3           |
-- |Money transfer, virtual currency, or money service     |26        |6             |76.9           |23.5           |
-- |Mortgage                                               |25        |6             |76.0           |9.5            |
-- |Payday loan, title loan, personal loan, or advance loan|21        |2             |90.5           |5.3            |
-- |Vehicle loan or lease                                  |19        |4             |78.9           |17.6           |
-- |Student loan                                           |10        |7             |30.0           |0.0            |
-- |Prepaid card                                           |8         |0             |100.0          |25.0           |
-- |Debt or credit management                              |3         |0             |100.0          |50.0           |
-- Credit reporting is 92.5% of complaints but almost always on time.
-- Debt collection has the most late responses (28), and only 3 of 10
-- student loan complaints were answered on time.


-- Q5: Root cause: which product + issue combinations matter most?
SELECT product,
       issue,
       COUNT(*)                                               AS complaints,
       SUM(is_late)                                           AS late_responses,
       ROUND(100.0 * SUM(got_relief) / SUM(is_closed), 1)     AS relief_rate_pct
FROM complaints_clean
GROUP BY product, issue
ORDER BY complaints DESC
LIMIT 10;
-- Why it matters: a high relief rate means the company often had to
-- fix something, a sign of a process problem rather than a
-- misunderstanding.
-- Result:
-- |product                                            |issue                                                          |complaints|late_responses|relief_rate_pct|
-- |---------------------------------------------------|---------------------------------------------------------------|----------|--------------|---------------|
-- |Credit reporting or other personal consumer reports|Incorrect information on your report                           |2,879     |3             |43.7           |
-- |Credit reporting or other personal consumer reports|Problem with a company's investigation into an existing problem|996       |0             |43.7           |
-- |Credit reporting or other personal consumer reports|Improper use of your report                                    |711       |3             |47.1           |
-- |Debt collection                                    |Attempts to collect debt not owed                              |73        |6             |34.3           |
-- |Checking or savings account                        |Managing an account                                            |46        |4             |13.6           |
-- |Debt collection                                    |Took or threatened to take negative or legal action            |26        |14            |18.8           |
-- |Debt collection                                    |Written notification about debt                                |25        |2             |21.7           |
-- |Credit card                                        |Problem with a purchase shown on your statement                |15        |0             |35.7           |
-- |Credit reporting or other personal consumer reports|Problem with fraud alerts or security freezes                  |11        |0             |9.1            |
-- |Credit reporting or other personal consumer reports|Unable to get your credit report or credit score               |11        |0             |0.0            |


-- Q6: How does each peer group compare?
-- Compares RATES, not just counts, because bigger companies
-- naturally receive more complaints.
SELECT company_group,
       COUNT(*)                                               AS complaints,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints_clean), 1) AS share_pct,
       ROUND(100.0 * SUM(is_timely) / COUNT(*), 1)            AS timely_rate_pct,
       SUM(is_late)                                           AS late_responses,
       ROUND(100.0 * SUM(got_relief) / SUM(is_closed), 1)     AS relief_rate_pct
FROM complaints_clean
GROUP BY company_group
UNION ALL
SELECT 'ALL COMPANIES',
       COUNT(*),
       100.0,
       ROUND(100.0 * SUM(is_timely) / COUNT(*), 1),
       SUM(is_late),
       ROUND(100.0 * SUM(got_relief) / SUM(is_closed), 1)
FROM complaints_clean;
-- Why it matters: shows which group is below the average on the SLA.
-- Result:
-- |company_group         |complaints|share_pct|timely_rate_pct|late_responses|relief_rate_pct|
-- |----------------------|----------|---------|---------------|--------------|---------------|
-- |1. Credit bureaus (3) |4,538     |90.9     |100.0          |0             |44.6           |
-- |2. Large banks (6)    |69        |1.4      |98.6           |1             |29.9           |
-- |3. All other companies|384       |7.7      |82.6           |67            |17.5           |
-- |ALL COMPANIES         |4,991     |100.0    |98.6           |68            |42.6           |
-- Smaller companies receive 7.7% of complaints but cause 67 of the
-- 68 late responses. The large banks match the overall average.


-- Q7: Where exactly are the late responses? (company + product)
SELECT company,
       product,
       COUNT(*)                                               AS complaints,
       SUM(is_late)                                           AS late_responses,
       ROUND(100.0 * SUM(is_timely) / COUNT(*), 1)            AS timely_rate_pct
FROM complaints_clean
GROUP BY company, product
HAVING SUM(is_late) > 0
ORDER BY late_responses DESC
LIMIT 10;
-- Why it matters: pinpoints the teams that are missing the SLA.
-- Result:
-- |company                                         |product                                            |complaints|late_responses|timely_rate_pct|
-- |------------------------------------------------|---------------------------------------------------|----------|--------------|---------------|
-- |Servicer under contract with Federal Student Aid|Debt collection                                    |9         |9             |0.0            |
-- |Professional Recovery Management                |Debt collection                                    |8         |8             |0.0            |
-- |MOHELA                                          |Student loan                                       |7         |6             |14.3           |
-- |FinCo Services Inc DBA Current                  |Checking or savings account                        |5         |4             |20.0           |
-- |TClub Inc                                       |Money transfer, virtual currency, or money service |4         |4             |0.0            |
-- |Shellpoint Partners, LLC                        |Mortgage                                           |7         |3             |57.1           |
-- |Imprint Payments, Inc.                          |Credit card                                        |2         |2             |0.0            |
-- |Jana Ferrell & Associates LLC                   |Debt collection                                    |2         |2             |0.0            |
-- |NISSAN MOTOR ACCEPTANCE COMPANY LLC             |Vehicle loan or lease                              |2         |2             |0.0            |
-- |Professional Recovery Management                |Credit reporting or other personal consumer reports|2         |2             |0.0            |


-- Q8: How did companies respond?
SELECT company_response,
       COUNT(*)                                               AS complaints,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM complaints_clean), 1) AS share_pct
FROM complaints_clean
GROUP BY company_response
ORDER BY complaints DESC;
-- Why it matters: shows how often customers got money back or a fix.
-- Result:
-- |company_response               |complaints|share_pct|
-- |-------------------------------|----------|---------|
-- |Closed with explanation        |2,832     |56.7     |
-- |Closed with non-monetary relief|2,078     |41.6     |
-- |In progress                    |32        |0.6      |
-- |Untimely response              |28        |0.6      |
-- |Closed with monetary relief    |21        |0.4      |


-- Q9: Which issue is late most often? (issues with 20+ complaints)
SELECT issue,
       COUNT(*)                                               AS complaints,
       SUM(is_late)                                           AS late_responses,
       ROUND(100.0 * SUM(is_timely) / COUNT(*), 1)            AS timely_rate_pct
FROM complaints_clean
GROUP BY issue
HAVING COUNT(*) >= 20
ORDER BY timely_rate_pct ASC
LIMIT 5;
-- Why it matters: shows where a specialist team would protect the SLA.
-- Result:
-- |issue                                              |complaints|late_responses|timely_rate_pct|
-- |---------------------------------------------------|----------|--------------|---------------|
-- |Took or threatened to take negative or legal action|26        |14            |46.2           |
-- |Managing an account                                |46        |4             |91.3           |
-- |Attempts to collect debt not owed                  |73        |6             |91.8           |
-- |Written notification about debt                    |25        |2             |92.0           |
-- |Improper use of your report                        |711       |3             |99.6           |
-- Complaints that a company "took or threatened to take negative or
-- legal action" were late 14 times out of 26.


-- =============================================================
-- SUMMARY
-- Problem: complaints must be answered within 15 days. 98.6% were,
--   but 68 were late, and 42.6% of closed complaints needed a fix.
-- Main drivers: credit reporting is 92.5% of complaints, and 36% of
--   all complaints say the information belongs to someone else.
-- Peers: credit bureaus were 100% on time, the large banks 98.6%,
--   but smaller companies (7.7% of complaints) caused 67 of 68
--   late responses, mostly in debt collection and student loans.
-- Recommendations:
--   1. Improve identity matching between lenders and credit bureaus.
--   2. Track debt collection and student loan complaints daily, and
--      send complaints about threatened legal action to a specialist
--      team with a 10-day internal target.
--   3. Use the relief rate as a monthly early warning of process errors.
--   4. Re-run on 2-3 years of data for the bank peer group.
-- =============================================================
