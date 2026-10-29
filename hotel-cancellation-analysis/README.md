# Hotel Booking Cancellations: What Are They Costing Us?

**A business analysis by Smith Cudjoe · SQL (SQLite) · Power BI**

![Power BI dashboard](dashboard.png)

Two hotels in Portugal, a city hotel in Lisbon and a resort in the Algarve, were losing revenue to cancelled bookings. As the business analyst, I defined the problem, stakeholders and KPIs, analysed 119,390 bookings (July 2015 – August 2017) in SQL, and built a Power BI dashboard to show management where the revenue is lost and which policy change would protect the most.

📄 [Project brief](Project_Brief.md) · 🗂️ [SQL analysis](Hotelcancellationanalysis.sql) · 📊 [Dashboard (PDF)](Hotel_Cancellation_Dashboard.pdf) · 💾 [Power BI template](Hotel_Cancellation_Dashboard.pbit)

---

## At a glance

| Valid bookings | Cancellation rate | Revenue earned | Revenue lost |
|:---:|:---:|:---:|:---:|
| **117,429** | **37.5%** | **€26.0M** | **€16.7M** |

---

## 1. The business problem
Every cancelled booking is a room the hotel held and revenue it expected but never received. Management asked three questions:
- **Where** do the cancellations come from?
- **How much** are they costing?
- **What** policy change would protect the most revenue?

## 2. Stakeholders
| Stakeholder | What they need |
|---|---|
| General Manager | The size of the problem and a clear recommendation |
| Revenue Manager | Which channels, booking windows and months lose the most |
| Sales & Distribution | Which partners (travel agents, groups) cancel most |
| Front Office | Busiest months for staffing |
| Marketing | Whether repeat and engaged guests are more reliable |

## 3. KPIs
| KPI | Definition |
|---|---|
| Cancellation rate | Cancelled bookings ÷ all bookings |
| Revenue earned | Nightly rate × nights, for bookings that were kept |
| Revenue lost | Nightly rate × nights, for cancelled bookings |
| Lead time | Days between booking and arrival |

---

## 4. Findings

| # | Business question | Answer |
|---|---|---|
| 1 | How big is the problem? | 44,010 of 117,429 bookings cancelled (37.5%), up to €16.7M lost |
| 2 | Which hotel is worse? | City Hotel: 42.2% cancelled, €10.9M lost · Resort: 28.1%, €5.8M |
| 3 | Do early bookings cancel more? | Yes: 9.7% within a week → 57.2% over 6 months ahead |
| 4 | Which channel loses most? | Online travel agents €10.2M · Groups cancel most (61.7%) · Direct least (15.4%) |
| 5 | Does a deposit help? | Non-refundable bookings cancel 99.4% of the time (see below) |
| 6 | Do repeat guests cancel less? | Yes: 16.2% vs 38.1% for new guests |
| 7 | Do special requests matter? | Yes: 22.0% with requests vs 48.3% without |
| 8 | Busiest months? | August (8,483 stays at €145/night), then July |
| 9 | Which months lose most? | August €3.0M, July €2.5M |
| 10 | Business case | 39,178 no-deposit bookings made 90+ days ahead lost €7.0M |

### The surprising deposit result
A deposit should reduce cancellations, so a 99.4% cancellation rate for non-refundable bookings needed investigating before drawing conclusions. A follow-up query (Q5b) showed that **97% of these bookings came from Portuguese groups and travel agents, booked 213 days ahead on average**, compared with 90 days for no-deposit bookings. They look like rooms blocked in advance and released later, not ordinary guests. If the hotel kept these deposits, about €3.6M of the "lost" revenue was actually collected, so the **real loss is likely nearer €13.1M**.

---

## 5. Recommendations
1. **Ask for a deposit on early bookings** made more than 90 days ahead.
2. **Tighten group and agent contracts:** release unsold blocked rooms earlier and limit rooms held without payment.
3. **Investigate before acting:** confirm with Reservations and Finance how non-refundable bookings are recorded.
4. **Engage guests before arrival:** pre-arrival emails inviting special requests, and a loyalty offer for repeat guests.

## 6. The business case
If a deposit prevented, or paid for, **a quarter** of the cancellations among the 39,178 long-lead, no-deposit bookings, the hotels would protect about **€1.76M over the 26 months of data (roughly €0.8M a year)**. Guests who book close to their stay, who already cancel least, would not be affected.

**Next steps:** confirm the non-refundable figures with Finance, agree the deposit level with the Revenue Manager, and track the cancellation rate monthly on the dashboard.

---

## Method
1. **Brief:** problem, stakeholders, questions, KPIs and scope ([Project_Brief.md](Project_Brief.md)).
2. **Clean (SQL):** convert types, calculate nights and booking value, remove 1,961 bookings with no nights or an impossible price.
3. **Analyse (SQL):** 10 business questions plus a follow-up on the deposit result, using `COUNT`, `SUM`, `CASE` and `GROUP BY`.
4. **Present (Power BI):** one-page management dashboard with a hotel filter and finding-led chart titles.

**To open the dashboard:** open `Hotel_Cancellation_Dashboard.pbit` in Power BI Desktop and enter the full path to `hotels.csv` when asked.

## Notes on the data
- Revenue is estimated as nightly rate × nights; extras such as meals are not included.
- "Cancelled" includes 1,181 no-shows (guests who never arrived).
- Data: Antonio, N., de Almeida, A. and Nunes, L. (2019) "Hotel booking demand datasets", *Data in Brief*, 22, 41–49, via [TidyTuesday](https://github.com/rfordatascience/tidytuesday/tree/master/data/2020/2020-02-11).

## Files
```
├── index.html                          <- project page (GitHub Pages)
├── README.md                           <- this page
├── Project_Brief.md                    <- business analyst project brief
├── Hotelcancellationanalysis.sql       <- SQL analysis with results
├── Hotel_Cancellation_Dashboard.pbit   <- Power BI template
├── Hotel_Cancellation_Dashboard.pdf    <- dashboard as PDF
├── hotels.csv                          <- the data (119,390 bookings)
├── dashboard.png                       <- dashboard screenshot
├── sql_preview.png                     <- SQL preview image
└── powerbi_preview.png                 <- Power BI preview image
```
