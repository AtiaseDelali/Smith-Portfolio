# Project Brief: Consumer Complaints and Response SLA

**Prepared by:** Smith Cudjoe, Business Analyst

## 1. Business problem
Financial companies must respond to complaints forwarded by the US regulator, the Consumer Financial Protection Bureau (CFPB), within 15 days. A late response is a missed SLA (service level agreement) and a regulatory risk. Complaints where the company has to give the customer money or another fix point to process errors.

## 2. Objective
Find which products and issues drive complaints and late responses, compare companies with their peers fairly, and recommend where an operations leader should focus first.

## 3. Stakeholders
| Stakeholder | What they need |
|---|---|
| Head of Operations | Where complaints and late responses come from, and what to fix first |
| Complaints team leads | Which products and issues miss the 15-day SLA |
| Compliance & Risk | SLA performance against peers and regulatory exposure |
| Product owners | The root causes behind their products' complaints |

## 4. Business questions
1. How many complaints are there, how many are answered on time, and how often is relief given?
2. When were the complaints received?
3. What are the top issues, and what is the root cause behind the biggest one?
4. Which products generate complaints and late responses?
5. Which product and issue combinations matter most?
6. How do credit bureaus, large banks and other companies compare?
7. Which companies and products miss the SLA?
8. How did companies respond?
9. Which issues are late most often?

## 5. Key performance indicators
| KPI | Definition |
|---|---|
| Complaints | Number of complaints received |
| Timely response rate (SLA) | Complaints answered on time ÷ all complaints |
| Late responses | Complaints not answered on time |
| Relief rate | Closed complaints where the company gave money or another fix ÷ all closed complaints |

## 6. Peer groups
Comparing raw complaint counts would be unfair, because bigger companies have more customers. Companies are grouped into **credit bureaus (3)**, **large banks (6)** and **all other companies**, and compared on rates rather than counts.

## 7. Scope and caveats
- **Data:** a recent extract of 4,991 complaints from the CFPB Consumer Complaint Database, all products and companies, 95% received 24–29 August 2026.
- The CFPB says complaint data is not a statistical sample, and volume should be read in the context of company size or market share.
- The CFPB changed its product and issue categories in April 2017; only recent data is used.
- 32 complaints were still in progress when the data was exported.

## 8. Deliverables
1. SQL analysis answering the business questions (`Bankcomplaintsanalysis.sql`)
2. Four-page Power BI dashboard (`Consumer_Complaints_Dashboard.pbit` and `.pdf`)
3. Findings and recommendations
