-- =============================================================
-- US BANK CONSOLIDATION: WHAT DO MERGERS MEAN FOR BRANCHES
-- AND THE CUSTOMERS WHO USE THEM?
-- FDIC BankFind Suite: structure change history (mergers,
-- failures, new banks, charter and name changes, and branch
-- openings and closings at FDIC-insured banks)
-- Table: fdic_history (10,000 rows, imported from fdic_history.csv)
-- Tool: SQLite (DBeaver)
-- Analysis by Smith Cudjoe
--
-- Business problem:
--   A merger is the largest change programme a bank goes through:
--   new systems, accounts moved to a new bank, and branches closed.
--   A bank's change and integration leadership wants to know how
--   fast US banks are consolidating, who is buying whom, and what
--   mergers mean for branch networks and the customers who use them.
--
-- What this extract contains (see Q1):
--   The FDIC download stops at 10,000 rows. Because of the order
--   the FDIC returns rows, this file holds two different things:
--   1. Bank-level records (mergers, failures, new banks, charter
--      and name changes): COMPLETE for everything processed from
--      2 Jan 2020 to 19 Oct 2022. Analysed for Jan 2020 - Sep 2022.
--   2. Branch-level records (openings, closings, branches moving in
--      a merger): a RANDOM 1-IN-8 SAMPLE, Jan 2020 - Oct 2026.
--      Counts are a sample, so compare shares and trends, not totals.
--
-- Change groups (from the FDIC change codes):
--   1. Merger                 a bank absorbed into another bank
--   2. Failure                a bank closed by its regulator
--   3. New bank               a new bank opened
--   4. Voluntary closing      a bank closed by its owners
--   5. Branch opening
--   6. Branch closing
--   7. Branch changed owner   branch moved to another bank
--   8. Office relocated
--   9. Charter, name or other change
--   0. Acquirer-side duplicate  the second row the FDIC records
--                               for every merger (not counted)
--
-- KPIs:
--   Mergers              = banks absorbed into another bank
--                          (one per bank and date, de-duplicated)
--   Net change in banks  = new banks - mergers - failures
--                          - voluntary closings
--   Branches acquired    = branches that moved to the buyer in a merger
--   Closings per opening = branch closings / branch openings
--   Closings after merger = branch closings within 12 months after
--                          the bank completed a merger as the buyer
-- =============================================================


-- Step 0: Check the import
SELECT COUNT(*)                     AS rows_imported,
       COUNT(DISTINCT ID)           AS unique_ids,
       MIN(PROCDATE)                AS first_processed,
       MAX(PROCDATE)                AS last_processed
FROM fdic_history;
-- Result:
-- |rows_imported|unique_ids|first_processed    |last_processed     |
-- |-------------|----------|-------------------|-------------------|
-- |10,000       |10,000    |2020-01-02T00:00:00|2026-10-21T00:00:00|
-- 10,000 rows: exactly the download limit, so this file is an extract,
-- not every event since 2020. Q1 shows what it contains.


-- Step 1: Label every row
-- A view (a saved query) that keeps all columns and adds:
--   record_level: bank-level IDs contain '_' (e.g. 202000025_223_...),
--                 branch-level IDs are 32-character codes.
--   data_check:   the reason a row is kept or removed.
DROP VIEW IF EXISTS history_checked;
CREATE VIEW history_checked AS
SELECT *,
       CASE WHEN instr(ID, '_') > 0 THEN 'Bank-level' ELSE 'Branch-level' END AS record_level,
       -- Dates look like 2023-06-16T00:00:00: keep the first 10 characters.
       -- (If DBeaver stored the date as a number, convert it.)
       CASE WHEN typeof(EFFDATE) = 'integer' THEN date(EFFDATE / 1000, 'unixepoch')
            ELSE substr(EFFDATE, 1, 10) END                              AS eff_date_clean,
       CASE WHEN typeof(PROCDATE) = 'integer' THEN date(PROCDATE / 1000, 'unixepoch')
            ELSE substr(PROCDATE, 1, 10) END                             AS proc_date_clean,
       CASE
         WHEN COALESCE(NULLIF(CLASS, ''), NULLIF(OUT_CLASS, ''), NULLIF(ACQ_CLASS, ''), '') = 'CU'
           OR INSAGENT1 = 'NCUA'                    THEN '2. Removed: credit union, not a bank'
         WHEN COALESCE(NULLIF(CLASS, ''), NULLIF(OUT_CLASS, ''), NULLIF(ACQ_CLASS, ''), '') IN ('NC', 'NS')
           OR INSAGENT1 = 'NONE'                    THEN '3. Removed: not FDIC-insured'
         WHEN COALESCE(NULLIF(CERT, ''), NULLIF(OUT_CERT, '')) IS NULL
                                                    THEN '4. Removed: no bank ID (CERT)'
         WHEN substr(EFFDATE, 1, 10) < '2020-01-01' THEN '5. Removed: took effect before 2020'
         WHEN instr(ID, '_') > 0
          AND substr(EFFDATE, 1, 10) > '2022-09-30' THEN '6. Removed: bank-level, after Sep 2022 (incomplete)'
         ELSE '1. Kept'
       END                                                               AS data_check
FROM fdic_history;


-- Q1: What does this extract contain? (rows by year processed)
SELECT record_level,
       COUNT(*)                                                         AS row_count,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2020' THEN 1 ELSE 0 END) AS y2020,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2021' THEN 1 ELSE 0 END) AS y2021,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2022' THEN 1 ELSE 0 END) AS y2022,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2023' THEN 1 ELSE 0 END) AS y2023,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2024' THEN 1 ELSE 0 END) AS y2024,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2025' THEN 1 ELSE 0 END) AS y2025,
       SUM(CASE WHEN substr(PROCDATE, 1, 4) = '2026' THEN 1 ELSE 0 END) AS y2026
FROM history_checked
GROUP BY record_level;
-- Why it matters: shows that the two kinds of record cover
-- different periods, so they must be analysed separately.
-- Result:
-- |record_level|row_count|y2020|y2021|y2022|y2023|y2024|y2025|y2026|
-- |------------|---------|-----|-----|-----|-----|-----|-----|-----|
-- |Bank-level  |4,570    |1954 |1567 |1048 |0    |1    |0    |0    |
-- |Branch-level|5,430    |808  |1173 |895  |812  |534  |600  |608  |
-- Bank-level rows stop in October 2022 (the last was processed on
-- 19 Oct 2022; one more was re-processed in 2024). Branch-level rows
-- run steadily from 2020 to October 2026.


-- Q1b: Are the branch-level records a fair sample?
-- Branch IDs are random codes (0-9, a-f). This file holds every ID
-- starting 00 to 1f: 32 of the 256 possible starts, or 1 in 8.
SELECT substr(ID, 1, 1)             AS first_character,
       COUNT(*)                     AS row_count,
       MIN(substr(ID, 1, 2))        AS lowest_start,
       MAX(substr(ID, 1, 2))        AS highest_start
FROM history_checked
WHERE record_level = 'Branch-level'
GROUP BY first_character;
-- Result:
-- |first_character|row_count|lowest_start|highest_start|
-- |---------------|---------|------------|-------------|
-- |0              |2,765    |00          |0f           |
-- |1              |2,643    |10          |1f           |
-- |2              |22       |20          |20           |
-- Branch-level IDs start 00 to 1f (plus 22 starting 20): about 32 of
-- 256 possible starts. Because the codes are random, this is a fair
-- 1-in-8 sample of all branch events, at the same rate every year.


-- Q2: What did the data checks remove? (for "How I cleaned it")
SELECT data_check,
       COUNT(*)                                                         AS row_count,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fdic_history), 1) AS share_pct
FROM history_checked
GROUP BY data_check
ORDER BY data_check;
-- Why it matters: the FDIC file also records credit unions and
-- events recorded years after they happened. Leaving them in would
-- overstate bank mergers.
-- Result:
-- |data_check                                         |row_count|share_pct|
-- |---------------------------------------------------|---------|---------|
-- |1. Kept                                            |7,168    |71.7     |
-- |2. Removed: credit union, not a bank               |1,876    |18.8     |
-- |3. Removed: not FDIC-insured                       |85       |0.8      |
-- |4. Removed: no bank ID (CERT)                      |440      |4.4      |
-- |5. Removed: took effect before 2020                |408      |4.1      |
-- |6. Removed: bank-level, after Sep 2022 (incomplete)|23       |0.2      |
-- 72% of rows are kept. Credit unions (19% of rows) are insured by the
-- NCUA, not the FDIC, so they are not banks for this analysis.


-- Step 2: Prepare a clean events table
-- One row per event, with readable groups and ONE bank ID (CERT).
-- Merger and failure rows keep the absorbed bank's CERT in OUT_CERT,
-- so CERT falls back to OUT_CERT when it is empty.
DROP TABLE IF EXISTS events;
CREATE TABLE events AS
SELECT ID                                                            AS event_id,
       record_level,
       TRANSNUM                                                      AS transaction_id,
       CAST(COALESCE(NULLIF(CERT, ''), NULLIF(OUT_CERT, '')) AS INTEGER) AS cert,
       COALESCE(NULLIF(INSTNAME, ''),
                CASE WHEN CERT = ACQ_CERT THEN ACQ_INSTNAME ELSE OUT_INSTNAME END) AS bank_name,
       CAST(CHANGECODE AS INTEGER)                                   AS change_code,
       CHANGECODE_DESC                                               AS change_desc,
       CASE
         WHEN CAST(CHANGECODE AS INTEGER) IN (221, 222, 223)          THEN '1. Merger'
         WHEN CAST(CHANGECODE AS INTEGER) BETWEEN 210 AND 219         THEN '2. Failure'
         WHEN CAST(CHANGECODE AS INTEGER) BETWEEN 100 AND 199         THEN '3. New bank'
         WHEN CAST(CHANGECODE AS INTEGER) BETWEEN 240 AND 249         THEN '4. Voluntary closing'
         WHEN CAST(CHANGECODE AS INTEGER) = 711                       THEN '5. Branch opening'
         WHEN CAST(CHANGECODE AS INTEGER) = 721                       THEN '6. Branch closing'
         WHEN CAST(CHANGECODE AS INTEGER) IN (712, 713, 722)          THEN '7. Branch changed owner'
         WHEN CAST(CHANGECODE AS INTEGER) = 520                       THEN '8. Office relocated'
         WHEN CAST(CHANGECODE AS INTEGER) IN (810, 811)               THEN '0. Acquirer-side duplicate'
         ELSE '9. Charter, name or other change'
       END                                                           AS change_group,
       eff_date_clean                                                AS eff_date,
       CAST(substr(eff_date_clean, 1, 4) AS INTEGER)                 AS eff_year,
       NULLIF(PSTALP, '')                                            AS hq_state,
       CAST(NULLIF(UNINUM, '') AS INTEGER)                           AS branch_id,
       NULLIF(OFF_NAME, '')                                          AS branch_name,
       NULLIF(OFF_PSTALP, '')                                        AS branch_state,
       CASE WHEN OFF_SERVTYPE_DESC = 'FULL SERVICE - BRICK AND MORTAR' THEN '1. Full-service branch'
            WHEN OFF_SERVTYPE_DESC = 'FULL SERVICE - RETAIL'           THEN '2. In-store branch'
            WHEN OFF_SERVTYPE_DESC LIKE 'LIMITED SERVICE%'             THEN '3. Limited-service office'
            WHEN NULLIF(OFF_SERVTYPE_DESC, '') IS NOT NULL             THEN '4. Other'
       END                                                           AS branch_type,
       CAST(NULLIF(ACQ_CERT, '') AS INTEGER)                         AS acq_cert,
       NULLIF(ACQ_INSTNAME, '')                                      AS acq_name,
       NULLIF(ACQ_PSTALP, '')                                        AS acq_state,
       NULLIF(ACQ_CLASS_TYPE_DESC, '')                               AS acq_type,
       CAST(NULLIF(OUT_CERT, '') AS INTEGER)                         AS out_cert,
       NULLIF(OUT_INSTNAME, '')                                      AS out_name,
       NULLIF(OUT_PSTALP, '')                                        AS out_state,
       NULLIF(OUT_CLASS_TYPE_DESC, '')                               AS out_type,
       CAST(NULLIF(ACQ_BRANCHES, '') AS INTEGER)                     AS branches_acquired
FROM history_checked
WHERE data_check = '1. Kept';


-- Step 3: Prepare a mergers table (one row per absorbed bank)
-- One merger appears as several rows (the absorbed bank, the buyer,
-- and one row for every branch that moved), so this keeps ONE row
-- per absorbed bank and date. Buyers are identified by CERT, never
-- by name, because bank names change while the CERT stays the same.
DROP TABLE IF EXISTS mergers;
CREATE TABLE mergers AS
SELECT out_cert                                   AS target_cert,
       MAX(out_name)                              AS target_name,
       MAX(out_state)                             AS target_state,
       MAX(out_type)                              AS target_type,
       MAX(acq_cert)                              AS acquirer_cert,
       MAX(acq_name)                              AS acquirer_name,
       MAX(acq_state)                             AS acquirer_state,
       MAX(acq_type)                              AS acquirer_type,
       eff_date,
       eff_year,
       COALESCE(MAX(branches_acquired), 0)        AS branches_acquired,
       CASE WHEN MAX(out_state) = MAX(acq_state) THEN 0 ELSE 1 END AS is_cross_state,
       CASE WHEN COALESCE(MAX(branches_acquired), 0) <= 1   THEN '1. 0-1 branches'
            WHEN MAX(branches_acquired) <= 5                THEN '2. 2-5 branches'
            WHEN MAX(branches_acquired) <= 20               THEN '3. 6-20 branches'
            WHEN MAX(branches_acquired) <= 100              THEN '4. 21-100 branches'
            ELSE                                                 '5. Over 100 branches' END AS deal_size
FROM events
WHERE change_group = '1. Merger'
GROUP BY out_cert, eff_date;


-- Step 4: Flag branch closings that came soon after a merger
-- 1 = the bank closed this branch within 12 months after
-- completing a merger as the buyer.
ALTER TABLE events ADD COLUMN after_merger_12m INTEGER DEFAULT 0;

UPDATE events
SET after_merger_12m = 1
WHERE change_group = '6. Branch closing'
  AND EXISTS (SELECT 1
              FROM mergers m
              WHERE m.acquirer_cert = events.cert
                AND events.eff_date >= m.eff_date
                AND events.eff_date <  date(m.eff_date, '+12 months'));


-- Q0: What data do we have after cleaning?
SELECT record_level,
       COUNT(*)                     AS events,
       COUNT(DISTINCT cert)         AS banks,
       MIN(eff_date)                AS first_date,
       MAX(eff_date)                AS last_date
FROM events
GROUP BY record_level;
-- Why it matters: confirms what the data covers before any conclusions are drawn.
-- Result:
-- |record_level|events|banks|first_date|last_date |
-- |------------|------|-----|----------|----------|
-- |Bank-level  |1,994 |1,400|2020-01-01|2022-09-30|
-- |Branch-level|5,174 |1,097|2020-01-01|2026-10-19|
-- 1,994 bank-level events (complete, Jan 2020 - Sep 2022) and 5,174
-- branch-level events (1-in-8 sample, Jan 2020 - Oct 2026).


-- =============================================================
-- PART A: BANKS (complete records, January 2020 - September 2022)
-- =============================================================

-- Q3: What kinds of bank-level change happen?
SELECT change_group,
       COUNT(*)                                                         AS events,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM events
                                 WHERE record_level = 'Bank-level'
                                   AND change_group <> '0. Acquirer-side duplicate'), 1) AS share_pct
FROM events
WHERE record_level = 'Bank-level'
  AND change_group <> '0. Acquirer-side duplicate'
GROUP BY change_group
ORDER BY events DESC;
-- Why it matters: shows how much bank-level change is consolidation.
-- Result:
-- |change_group                    |events|share_pct|
-- |--------------------------------|------|---------|
-- |9. Charter, name or other change|611   |39.2     |
-- |8. Office relocated             |449   |28.8     |
-- |1. Merger                       |361   |23.1     |
-- |7. Branch changed owner         |87    |5.6      |
-- |3. New bank                     |28    |1.8      |
-- |4. Voluntary closing            |20    |1.3      |
-- |2. Failure                      |4     |0.3      |
-- 361 banks were absorbed in mergers: 23% of all bank-level changes.
-- Charter, name and regulator changes are the most common event.


-- Q4: One merger, many rows: why de-duplication matters
SELECT (SELECT COUNT(*) FROM events
        WHERE change_group IN ('1. Merger', '0. Acquirer-side duplicate')) AS merger_rows_raw,
       (SELECT COUNT(*) FROM mergers)                                     AS mergers_after_dedup,
       ROUND(1.0 * (SELECT COUNT(*) FROM events
                    WHERE change_group IN ('1. Merger', '0. Acquirer-side duplicate'))
                 / (SELECT COUNT(*) FROM mergers), 1)                     AS rows_per_merger;
-- Why it matters: counting raw rows would double the number of
-- mergers, because the FDIC records each merger from both sides.
-- Result:
-- |merger_rows_raw|mergers_after_dedup|rows_per_merger|
-- |---------------|-------------------|---------------|
-- |795            |361                |2.2            |
-- 795 merger rows describe 361 mergers: every merger is recorded from
-- both sides (the absorbed bank and the buyer).


-- Q5: How fast are banks consolidating?
WITH yearly AS (
    SELECT eff_year,
           SUM(CASE WHEN change_group = '2. Failure'           THEN 1 ELSE 0 END) AS failures,
           SUM(CASE WHEN change_group = '3. New bank'          THEN 1 ELSE 0 END) AS new_banks,
           SUM(CASE WHEN change_group = '4. Voluntary closing' THEN 1 ELSE 0 END) AS voluntary_closings
    FROM events
    WHERE record_level = 'Bank-level'
    GROUP BY eff_year
),
merged AS (
    SELECT eff_year,
           COUNT(*)                                                       AS mergers,
           SUM(CASE WHEN substr(eff_date, 6, 2) <= '09' THEN 1 ELSE 0 END) AS mergers_jan_sep
    FROM mergers
    GROUP BY eff_year
)
SELECT y.eff_year,
       m.mergers,
       m.mergers_jan_sep,
       y.failures,
       y.voluntary_closings,
       y.new_banks,
       y.new_banks - m.mergers - y.failures - y.voluntary_closings        AS net_change_in_banks
FROM yearly y
LEFT JOIN merged m ON m.eff_year = y.eff_year
ORDER BY y.eff_year;
-- Why it matters: shows whether new banks replace the banks that
-- disappear. 2022 covers January to September only, so the
-- mergers_jan_sep column compares the same nine months each year.
-- Result:
-- |eff_year|mergers|mergers_jan_sep|failures|voluntary_closings|new_banks|net_change_in_banks|
-- |--------|-------|---------------|--------|------------------|---------|-------------------|
-- |2020    |156    |134            |4       |7                 |7        |-160               |
-- |2021    |129    |74             |0       |8                 |9        |-128               |
-- |2022    |76     |76             |0       |5                 |12       |-69                |
-- The number of FDIC-insured banks fell by a net 357 in 33 months:
-- 361 mergers, 4 failures and 20 voluntary closings, against only
-- 28 new banks. On a like-for-like
-- January-September basis, mergers fell from 134 (2020) to 74 (2021)
-- and 76 (2022).


-- Q6: How many branches changed hands through mergers?
SELECT eff_year,
       COUNT(*)                                                         AS mergers,
       SUM(branches_acquired)                                           AS branches_acquired,
       ROUND(AVG(branches_acquired), 1)                                 AS avg_per_merger,
       MAX(branches_acquired)                                           AS largest_deal
FROM mergers
GROUP BY eff_year
ORDER BY eff_year;
-- Why it matters: every acquired branch is a set of customers
-- whose accounts, cards and systems must be migrated.
-- Result:
-- |eff_year|mergers|branches_acquired|avg_per_merger|largest_deal|
-- |--------|-------|-----------------|--------------|------------|
-- |2020    |156    |1,308            |8.4           |192         |
-- |2021    |129    |2,032            |15.8          |644         |
-- |2022    |76     |1,460            |19.2          |348         |
-- 4,800 branches moved to a new bank. Deals got bigger: the average
-- merger moved 8.4 branches in 2020 and 19.2 in 2022.


-- Q7: The 10 largest mergers by branches acquired
SELECT eff_date,
       target_name,
       acquirer_name,
       branches_acquired
FROM mergers
ORDER BY branches_acquired DESC
LIMIT 10;
-- Why it matters: these are the largest integration programmes.
-- Result:
-- |eff_date  |target_name                               |acquirer_name                          |branches_acquired|
-- |----------|------------------------------------------|---------------------------------------|-----------------|
-- |2021-10-08|BBVA USA                                  |PNC Bank, National Association         |644              |
-- |2021-06-09|TCF National Bank                         |The Huntington National Bank           |506              |
-- |2022-04-02|People's United Bank, National Association|Manufacturers and Traders Trust Company|348              |
-- |2020-07-02|Iberiabank                                |First Horizon Bank                     |192              |
-- |2022-02-01|Great Western Bank                        |First Interstate Bank                  |176              |
-- |2020-06-08|South State Bank                          |CenterState Bank, National Association |168              |
-- |2022-04-07|Investors Bank                            |Citizens Bank, National Association    |153              |
-- |2022-02-16|First Midwest Bank                        |Old National Bank                      |111              |
-- |2021-10-29|Cadence Bank, N.A.                        |BancorpSouth Bank                      |105              |
-- |2022-01-04|CIT Bank, National Association            |First-Citizens Bank & Trust Company    |84               |
-- PNC's purchase of BBVA USA moved 644 branches, the largest
-- integration in the period, followed by Huntington-TCF (506).


-- Q8: Who is buying whom? (mergers by deal size)
SELECT deal_size,
       COUNT(*)                                                         AS mergers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM mergers), 1)      AS share_of_mergers_pct,
       SUM(branches_acquired)                                           AS branches_acquired,
       ROUND(100.0 * SUM(branches_acquired)
                   / (SELECT SUM(branches_acquired) FROM mergers), 1)   AS share_of_branches_pct
FROM mergers
GROUP BY deal_size
ORDER BY deal_size;
-- Why it matters: compares how many deals there are with how many
-- customers' branches they move.
-- Result:
-- |deal_size           |mergers|share_of_mergers_pct|branches_acquired|share_of_branches_pct|
-- |--------------------|-------|--------------------|-----------------|---------------------|
-- |1. 0-1 branches     |84     |23.3                |83               |1.7                  |
-- |2. 2-5 branches     |160    |44.3                |528              |11.0                 |
-- |3. 6-20 branches    |83     |23.0                |828              |17.3                 |
-- |4. 21-100 branches  |25     |6.9                 |958              |20.0                 |
-- |5. Over 100 branches|9      |2.5                 |2,403            |50.1                 |
-- Most mergers are small: 68% moved 5 branches or fewer. But just 9
-- deals (2.5% of mergers) moved half of all acquired branches.


-- Q9: Who is buying whom? (commercial banks and savings banks)
SELECT acquirer_type   AS buyer_type,
       target_type     AS absorbed_bank_type,
       COUNT(*)                                                         AS mergers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM mergers), 1)      AS share_pct
FROM mergers
GROUP BY acquirer_type, target_type
ORDER BY mergers DESC;
-- Why it matters: shows whether savings banks (thrifts) are being
-- absorbed into commercial banks.
-- Result:
-- |buyer_type|absorbed_bank_type|mergers|share_pct|
-- |----------|------------------|-------|---------|
-- |Commercial|Commercial        |308    |85.3     |
-- |Commercial|Savings           |20     |5.5      |
-- |Savings   |Savings           |18     |5.0      |
-- |Savings   |Commercial        |15     |4.2      |
-- 85% of mergers were commercial banks buying commercial banks. Savings
-- banks were absorbed into commercial banks 20 times.


-- Q10: Where are banks being absorbed? (top 10 states)
SELECT target_state,
       COUNT(*)                                                         AS mergers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM mergers), 1)      AS share_pct,
       ROUND(100.0 * SUM(is_cross_state) / COUNT(*), 1)                 AS bought_from_another_state_pct
FROM mergers
GROUP BY target_state
ORDER BY mergers DESC
LIMIT 10;
-- Why it matters: shows where customers are most likely to be
-- moved to a new bank.
-- Result:
-- |target_state|mergers|share_pct|bought_from_another_state_pct|
-- |------------|-------|---------|-----------------------------|
-- |TX          |28     |7.8      |28.6                         |
-- |IL          |23     |6.4      |30.4                         |
-- |IA          |19     |5.3      |5.3                          |
-- |MO          |17     |4.7      |23.5                         |
-- |OK          |16     |4.4      |6.3                          |
-- |MN          |16     |4.4      |25.0                         |
-- |TN          |15     |4.2      |46.7                         |
-- |NY          |15     |4.2      |46.7                         |
-- |CA          |15     |4.2      |33.3                         |
-- |WI          |14     |3.9      |21.4                         |
-- Texas (28) and Illinois (23) lost the most banks. In Iowa and
-- Oklahoma, almost every buyer was local; in Tennessee and New York,
-- nearly half came from another state.


-- Q11: The most active buyers (top 10)
SELECT acquirer_cert,
       MAX(acquirer_name)                                               AS acquirer,
       MAX(acquirer_state)                                              AS state,
       COUNT(*)                                                         AS banks_absorbed,
       SUM(branches_acquired)                                           AS branches_acquired
FROM mergers
GROUP BY acquirer_cert
ORDER BY banks_absorbed DESC, branches_acquired DESC
LIMIT 10;
-- Why it matters: serial buyers run integration programmes again
-- and again, so readiness matters most for them.
-- Result:
-- |acquirer_cert|acquirer                             |state|banks_absorbed|branches_acquired|
-- |-------------|-------------------------------------|-----|--------------|-----------------|
-- |131          |Seacoast National Bank               |FL   |5             |16               |
-- |11813        |BancorpSouth Bank                    |MS   |4             |135              |
-- |3890         |Simmons Bank                         |AR   |4             |83               |
-- |10359        |Happy State Bank                     |TX   |4             |20               |
-- |16889        |United Community Bank                |SC   |3             |53               |
-- |57038        |Nicolet National Bank                |WI   |3             |39               |
-- |32527        |BayVanguard Bank                     |MD   |3             |10               |
-- |33555        |SouthState Bank, National Association|FL   |2             |171              |
-- |22858        |United Bank                          |VA   |2             |98               |
-- |11063        |First-Citizens Bank & Trust Company  |NC   |2             |87               |
-- Seacoast National Bank absorbed 5 banks; BancorpSouth absorbed 4,
-- taking 135 branches.


-- Q12: Same bank, different names: why we join on CERT
SELECT cert,
       COUNT(DISTINCT bank_name)                                        AS names_used,
       MIN(bank_name)                                                   AS one_name,
       MAX(bank_name)                                                   AS another_name
FROM events
WHERE bank_name IS NOT NULL
GROUP BY cert
HAVING COUNT(DISTINCT bank_name) > 1
ORDER BY names_used DESC, cert
LIMIT 10;
-- Why it matters: a join on name would split one bank into two
-- after a rebrand. CERT never changes.
-- Result:
-- |cert |names_used|one_name                              |another_name                               |
-- |-----|----------|--------------------------------------|-------------------------------------------|
-- |27015|3         |42 North Private Bank                 |Ethic, A Wealth Bank                       |
-- |33555|3         |CenterState Bank, National Association|SouthState Bank, National Association      |
-- |485  |2         |Security Bank Midwest                 |Security State Bank                        |
-- |2832 |2         |First  Bank of Alabama                |First Bank of Alabama                      |
-- |3301 |2         |First Liberty Bank                    |The First Liberty National Bank            |
-- |7074 |2         |Arrow Bank National Association       |Glens Falls National Bank and Trust Company|
-- |8120 |2         |Magnolia Bank                         |Magnolia Bank, Incorporated                |
-- |10641|2         |Riverstone Bank                       |Tri Valley Bank                            |
-- |11035|2         |Peapack Private Bank & Trust          |Peapack-Gladstone Bank                     |
-- |11741|2         |Forreston State Bank                  |Solutions Bank                             |
-- CenterState Bank became SouthState Bank under the same CERT (33555).
-- A join on name would have split it into two banks. One name even
-- has a double space ("First  Bank of Alabama").


-- Q13: Which banks failed, and who took them over?
SELECT eff_date,
       out_name                                                         AS failed_bank,
       out_state                                                        AS state,
       acq_name                                                         AS taken_over_by
FROM events
WHERE change_group = '2. Failure'
ORDER BY eff_date;
-- Why it matters: failures are the most disruptive change of all:
-- customers move to a new bank over a weekend.
-- Result:
-- |eff_date  |failed_bank               |state|taken_over_by             |
-- |----------|--------------------------|-----|--------------------------|
-- |2020-02-14|Ericson State Bank        |NE   |Farmers and Merchants Bank|
-- |2020-04-03|The First State Bank      |WV   |MVB Bank, Inc             |
-- |2020-10-16|First City Bank of Florida|FL   |United Fidelity Bank, fsb |
-- |2020-10-23|Almena State Bank         |KS   |Equity Bank               |
-- Only 4 banks failed, all in 2020, and each was taken over by another
-- bank. (The 2023 failures fall outside the complete period.)


-- =============================================================
-- PART B: BRANCHES (1-in-8 sample, January 2020 - October 2026)
-- =============================================================

-- Q14: Branch openings against closings, by year
SELECT eff_year,
       SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END) AS openings,
       SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END) AS closings,
       SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END)
     - SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END) AS net_change,
       ROUND(1.0 * SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END)
                 / SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END), 1) AS closings_per_opening
FROM events
WHERE record_level = 'Branch-level'
GROUP BY eff_year
ORDER BY eff_year;
-- Why it matters: shows whether the branch network is shrinking.
-- The sample rate is the same every year, so years compare fairly.
-- Note: 2026 runs only to October.
-- Result:
-- |eff_year|openings|closings|net_change|closings_per_opening|
-- |--------|--------|--------|----------|--------------------|
-- |2020    |144     |417     |-273      |2.9                 |
-- |2021    |164     |577     |-413      |3.5                 |
-- |2022    |145     |383     |-238      |2.6                 |
-- |2023    |143     |304     |-161      |2.1                 |
-- |2024    |135     |229     |-94       |1.7                 |
-- |2025    |126     |169     |-43       |1.3                 |
-- |2026    |114     |115     |-1        |1.0                 |
-- Closings outnumbered openings every year, but the gap is closing:
-- 3.5 closings per opening in 2021, falling to 1.0 in 2026.


-- Q15: Which states are losing the most branches? (top 10)
SELECT branch_state,
       SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END) AS openings,
       SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END) AS closings,
       SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END)
     - SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END) AS net_change
FROM events
WHERE change_group IN ('5. Branch opening', '6. Branch closing')
GROUP BY branch_state
ORDER BY net_change ASC
LIMIT 10;
-- Why it matters: shows where customers are most likely to lose
-- their local branch.
-- Result:
-- |branch_state|openings|closings|net_change|
-- |------------|--------|--------|----------|
-- |CA          |48      |216     |-168      |
-- |NY          |44      |147     |-103      |
-- |IL          |29      |114     |-85       |
-- |FL          |70      |146     |-76       |
-- |OH          |26      |98      |-72       |
-- |NJ          |20      |84      |-64       |
-- |PA          |54      |117     |-63       |
-- |MI          |16      |77      |-61       |
-- |GA          |26      |65      |-39       |
-- |NC          |31      |70      |-39       |
-- California, New York and Illinois lost the most branches.


-- Q16: What kind of branch is closing?
SELECT branch_type,
       SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END) AS openings,
       SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END) AS closings,
       ROUND(1.0 * SUM(CASE WHEN change_group = '6. Branch closing' THEN 1 ELSE 0 END)
                 / SUM(CASE WHEN change_group = '5. Branch opening' THEN 1 ELSE 0 END), 1) AS closings_per_opening
FROM events
WHERE change_group IN ('5. Branch opening', '6. Branch closing')
GROUP BY branch_type
ORDER BY branch_type;
-- Why it matters: shows which kind of branch customers are losing.
-- Result:
-- |branch_type              |openings|closings|closings_per_opening|
-- |-------------------------|--------|--------|--------------------|
-- |1. Full-service branch   |881     |1,781   |2.0                 |
-- |2. In-store branch       |13      |222     |17.1                |
-- |3. Limited-service office|75      |181     |2.4                 |
-- |4. Other                 |2       |10      |5.0                 |
-- In-store branches (inside supermarkets and shops) are disappearing:
-- 17 closings for every opening, against 2 for full-service branches.


-- Q17: How many branch closings follow a merger? (2020-2022)
-- Only years where the merger records are complete.
SELECT eff_year,
       COUNT(*)                                                         AS branch_closings,
       SUM(after_merger_12m)                                            AS within_12m_of_merger,
       ROUND(100.0 * SUM(after_merger_12m) / COUNT(*), 1)               AS within_12m_of_merger_pct
FROM events
WHERE change_group = '6. Branch closing'
  AND eff_year <= 2022
GROUP BY eff_year
ORDER BY eff_year;
-- Why it matters: links branch closures directly to merger activity.
-- Result:
-- |eff_year|branch_closings|within_12m_of_merger|within_12m_of_merger_pct|
-- |--------|---------------|--------------------|------------------------|
-- |2020    |417            |48                  |11.5                    |
-- |2021    |577            |71                  |12.3                    |
-- |2022    |383            |92                  |24.0                    |
-- The share of closings that came within a year of the bank's merger
-- doubled, from 11.5% in 2020 to 24.0% in 2022.


-- Q18: Do buyers close more branches after a merger?
-- Compares each buyer's branch closings and openings in the 12
-- months before and the 12 months after its first merger.
-- Only buyers whose first merger was between Jan 2021 and Sep 2022,
-- so a full year on both sides is in the data.
WITH first_merger AS (
    SELECT acquirer_cert,
           MIN(eff_date) AS merger_date
    FROM mergers
    GROUP BY acquirer_cert
)
SELECT COUNT(DISTINCT f.acquirer_cert)                                  AS buyers,
       SUM(CASE WHEN e.change_group = '6. Branch closing'
                 AND e.eff_date >= date(f.merger_date, '-12 months')
                 AND e.eff_date <  f.merger_date THEN 1 ELSE 0 END)    AS closings_12m_before,
       SUM(CASE WHEN e.change_group = '6. Branch closing'
                 AND e.eff_date >= f.merger_date
                 AND e.eff_date <  date(f.merger_date, '+12 months') THEN 1 ELSE 0 END) AS closings_12m_after,
       SUM(CASE WHEN e.change_group = '5. Branch opening'
                 AND e.eff_date >= date(f.merger_date, '-12 months')
                 AND e.eff_date <  f.merger_date THEN 1 ELSE 0 END)    AS openings_12m_before,
       SUM(CASE WHEN e.change_group = '5. Branch opening'
                 AND e.eff_date >= f.merger_date
                 AND e.eff_date <  date(f.merger_date, '+12 months') THEN 1 ELSE 0 END) AS openings_12m_after
FROM first_merger f
LEFT JOIN events e
       ON e.cert = f.acquirer_cert
      AND e.change_group IN ('5. Branch opening', '6. Branch closing')
WHERE f.merger_date BETWEEN '2021-01-01' AND '2022-09-30';
-- Why it matters: tests the "spike after a merger" directly.
-- Result:
-- |buyers|closings_12m_before|closings_12m_after|openings_12m_before|openings_12m_after|
-- |------|-------------------|------------------|-------------------|------------------|
-- |153   |67                 |121               |19                 |18                |
-- In the 12 months after their first merger, 153 buyers closed 81%
-- more branches (121 against 67 in the sample) while openings stayed
-- flat (18 against 19).


-- Q19: Which buyers closed the most branches within 12 months of a merger? (top 10)
SELECT e.cert,
       (SELECT MAX(m.acquirer_name) FROM mergers m
        WHERE m.acquirer_cert = e.cert)                                 AS bank,
       (SELECT SUM(m.branches_acquired) FROM mergers m
        WHERE m.acquirer_cert = e.cert)                                 AS branches_acquired,
       COUNT(*)                                                         AS sampled_closings_within_12m
FROM events e
WHERE e.after_merger_12m = 1
GROUP BY e.cert
ORDER BY sampled_closings_within_12m DESC
LIMIT 10;
-- Why it matters: these are the integration programmes with the
-- biggest customer impact.
-- Result:
-- |cert |bank                                   |branches_acquired|sampled_closings_within_12m|
-- |-----|---------------------------------------|-----------------|---------------------------|
-- |6560 |The Huntington National Bank           |506              |35                         |
-- |6384 |PNC Bank, National Association         |644              |23                         |
-- |11063|First-Citizens Bank & Trust Company    |87               |17                         |
-- |57957|Citizens Bank, National Association    |153              |14                         |
-- |33555|SouthState Bank, National Association  |171              |9                          |
-- |57038|Nicolet National Bank                  |39               |8                          |
-- |3890 |Simmons Bank                           |83               |8                          |
-- |17838|Wilmington Savings Fund Society, FSB   |40               |7                          |
-- |11813|BancorpSouth Bank                      |135              |7                          |
-- |588  |Manufacturers and Traders Trust Company|348              |7                          |
-- Huntington closed the most branches within a year of absorbing TCF,
-- then PNC after BBVA USA. The largest mergers have the largest
-- branch impact.


-- =============================================================
-- SUMMARY
-- Data: the FDIC download stops at 10,000 rows. Bank-level records
--   are complete from Jan 2020 to Sep 2022; branch-level records are
--   a random 1-in-8 sample from Jan 2020 to Oct 2026.
-- Consolidation: FDIC-insured banks fell by a net 357 in 33 months.
--   361 were absorbed in mergers, and only 28 new banks opened.
-- Who is buying whom: deals are getting bigger. 9 deals (2.5% of
--   mergers) moved half of the 4,800 acquired branches, led by
--   PNC-BBVA USA (644) and Huntington-TCF (506).
-- Branches: closings outnumbered openings every year, peaking at 3.5
--   per opening in 2021 and falling to 1.0 in 2026. In-store
--   branches close 17 times for every one that opens.
-- Merger impact: buyers closed 81% more branches in the year after a
--   merger, and by 2022 a quarter of all closings came within a year
--   of the bank's merger.
-- Recommendations:
--   1. Reconcile every account before cutover and match records on
--      stable IDs (account number, CERT), never on names.
--   2. Plan branch decisions and customer notices for the first 12
--      months after a merger, when closures cluster.
--   3. Give extra support to customers of in-store and rural branches.
--   4. Track complaints for 90 days after cutover against the 90 days
--      before (link to the CFPB complaints project).
--   5. Re-run on a complete download (several smaller downloads) to
--      confirm the branch figures.
-- =============================================================
