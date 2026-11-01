# Project Brief: Financial Crime Analytics: Monitoring Rule Performance

**Prepared by:** Smith Cudjoe

> **Synthetic data:** IBM Transactions for Anti-Money Laundering (AMLworld). No real people, banks or accounts.

## 1. Business problem
Transaction monitoring rules raise alerts that analysts must review. Rules that are too weak miss laundering; rules that are too broad bury analysts in alerts. The team needs evidence of which rules earn their alerts and which could be tightened or retired.

## 2. Objective
Test simple monitoring rules on labelled laundering data, measure what each rule catches and what it costs in alerts, and recommend a rule-tuning plan with KPIs.

## 3. Stakeholders
| Stakeholder | What they need |
|---|---|
| Head of financial crime operations | Fewer alerts without losing coverage |
| Transaction monitoring analysts | Rules whose alerts are worth reviewing |
| Compliance (MLRO) | Evidence that coverage stays high after tuning |
| Rule governance | A documented case for each rule change |

## 4. Business questions
1. What does the data contain, and was it imported correctly?
2. What does laundering look like by pattern, currency, payment format, amount and time of day?
3. How many schemes does each rule detect, and how many alerts does it raise per scheme?
4. Which rules catch schemes that no other rule catches?
5. Which patterns does each rule detect, and what slips through every rule?
6. What happens if the large-transfer threshold is raised?
7. How many alerts would a tuned rule set save, and how much detection would it lose?

## 5. Rules tested
| Rule | Fires when |
|---|---|
| R1 Large transfer | the amount is $10,000 or more |
| R2 Just below $10k | the amount is $9,000 to $9,999.99 |
| R3 Many senders | the receiving account is paid by 5+ different accounts |
| R4 Many receivers | the sending account pays 5+ different accounts |
| R5 Night-time | the transfer is sent between midnight and 6am |
| R6 Foreign currency | the transfer is not in US dollars |

## 6. Key performance indicators
| KPI | Definition |
|---|---|
| Alerts | Transfers flagged by a rule |
| Scheme detection rate | Schemes with at least one alert ÷ all schemes |
| Alerts per scheme | Alerts ÷ schemes detected |
| Unique schemes | Schemes that only this rule detects |

## 7. Data
- **Source:** IBM Transactions for Anti-Money Laundering (Kaggle), HI-Large laundering patterns file.
- **Contents:** 137,936 laundering transfers in 16,467 schemes across eight patterns (fan-in, fan-out, cycle, stack, bipartite, scatter-gather, gather-scatter and random), August 2022 to January 2023.
- **Fields:** timestamp, sending and receiving bank and account, amount, currency, payment format and the scheme's pattern.

## 8. Scope and caveats
- The data is synthetic.
- The patterns file holds only laundering transfers, so false alerts on normal payments, and laundering rates, cannot be measured. Measuring false alerts on the full transactions file is the first step of the tuning plan.
- Account IDs must be imported as text, because some look like numbers in scientific notation.
- Amounts are converted to US dollars with approximate exchange rates.

## 9. Deliverables
1. SQL analysis answering the business questions (`Amlrulesanalysis.sql`)
2. Four-page Power BI dashboard (`Financial_Crime_Dashboard.pbit` and `.pdf`)
3. Findings, a rule-tuning plan and KPIs
