# Project Brief: US Bank Consolidation and Branch Impact

**Prepared by:** Smith Cudjoe, Business Analyst

## 1. Business problem
A merger is the largest change programme a bank goes through. The absorbed bank's accounts, positions and collateral have to be migrated and reconciled, systems are cut over, and branches are often closed, so customers have to change how they bank. Integration teams need to know how often these programmes happen, how big they are, and what they mean for branches and customers.

## 2. Objective
Use the FDIC's official record of bank structure changes to measure how fast US banks are consolidating, who is buying whom, and how mergers affect branch networks, then turn the findings into a merger integration readiness checklist with KPIs.

## 3. Stakeholders
| Stakeholder | What they need |
|---|---|
| Integration programme director | How big and how frequent merger programmes are |
| Head of branch network | When and where branches close after a merger |
| Operations & reconciliation leads | What has to be migrated and reconciled at cutover |
| Compliance & customer experience | Closure notices, customer impact and complaints |

## 4. Business questions
1. What does the data contain, and which periods are complete?
2. What do the data checks remove?
3. What kinds of bank-level change happen most?
4. How fast are banks consolidating, and are new banks replacing them?
5. How many branches change hands through mergers, and which deals are largest?
6. Who is buying whom, by deal size and by type of bank?
7. In which states are banks being absorbed, and by local or out-of-state buyers?
8. Which buyers are the most active?
9. Is the branch network shrinking, where, and which kinds of branch are closing?
10. Do buyers close more branches after a merger?

## 5. Key performance indicators
| KPI | Definition |
|---|---|
| Mergers | Banks absorbed into another bank (one per bank and date, de-duplicated) |
| Net change in banks | New banks − mergers − failures − voluntary closings |
| Branches acquired | Branches that moved to the buyer in a merger |
| Closings per opening | Branch closings ÷ branch openings |
| Closings after merger | Branch closings within 12 months after the bank completed a merger as the buyer |

## 6. Data
- **Source:** FDIC BankFind Suite, structure change history: one row per event (merger, failure, new bank, charter or name change, branch opening or closing) at FDIC-insured banks.
- **Extract:** 10,000 rows, the download limit. Bank-level records are complete for January 2020 to September 2022; branch-level records are a random one-in-eight sample from January 2020 to October 2026.
- **Key fields:** CERT (the FDIC's unique bank ID), CHANGECODE (type of change), EFFDATE (date the change took effect), the acquiring and absorbed banks, and UNINUM (the unique branch number).

## 7. Data-quality rules
- Translate the change codes into a few readable groups.
- One merger appears as several rows, so keep one row per absorbed bank and date.
- Bank names change while the CERT stays the same, so always join on CERT, never on name.
- Remove credit unions, banks that are not FDIC-insured, and events recorded long after they happened.
- Compare branch figures as shares and trends, because they are a sample.

## 8. Scope and caveats
- The extract is not the full FDIC history, so totals are a lower bound.
- Bank failures in 2023 fall outside the complete period.
- Linking a branch closing to a merger by timing shows association, not proof of cause.
- Matching complaints to mergers (with the CFPB complaints project) needs two to three years of complaints data; the current complaints extract covers about one week.

## 9. Deliverables
1. SQL analysis answering the business questions (`Bankconsolidationanalysis.sql`)
2. Four-page Power BI dashboard (`Bank_Consolidation_Dashboard.pbit` and `.pdf`)
3. Findings, a merger integration readiness checklist and KPIs
