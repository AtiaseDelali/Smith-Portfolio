# Project Brief: Reducing Hotel Booking Cancellations

**Prepared by:** Smith Cudjoe, Business Analyst

## 1. Business problem
The hotel group runs a City Hotel in Lisbon and a Resort Hotel in the Algarve. A large share of bookings are cancelled. Every cancelled room is revenue the hotel planned on but never received, and rooms held for guests who never arrive cannot be sold to someone else.

## 2. Objective
Find where cancellations come from, measure the revenue lost, and recommend policy changes that protect revenue without putting off genuine guests.

## 3. Stakeholders
| Stakeholder | What they need |
|---|---|
| General Manager | The size of the problem and a clear recommendation |
| Revenue Manager | Which channels, booking windows and months lose the most revenue |
| Sales & Distribution | Which partners (travel agents, groups) cancel most |
| Front Office | Busiest months for staffing |
| Marketing | Whether repeat guests and engaged guests are more reliable |

## 4. Business questions
1. How many bookings are cancelled, and how much revenue is lost?
2. Which hotel has the bigger problem?
3. Do guests who book far in advance cancel more?
4. Which sales channel cancels the most?
5. Does the current deposit policy reduce cancellations?
6. Do repeat guests cancel less?
7. Do guests who make special requests cancel less?
8. Which months are busiest?
9. Which months lose the most revenue to cancellations?
10. How much revenue would a deposit on early bookings protect?

## 5. Key performance indicators
| KPI | Definition |
|---|---|
| Cancellation rate | Cancelled bookings ÷ all bookings |
| Revenue earned | Nightly rate × nights, for bookings that were not cancelled |
| Revenue lost | Nightly rate × nights, for cancelled bookings |
| Lead time | Days between booking and arrival |

## 6. Scope
- **In scope:** 119,390 bookings, July 2015 – August 2017, both hotels.
- **Out of scope:** guest identities, competitor prices, marketing spend.
- **Assumption:** revenue is estimated as nightly rate × nights booked (extras such as meals are not included).

## 7. Data
Hotel Booking Demand dataset (Antonio, Almeida and Nunes, 2019, *Data in Brief*), prepared by TidyTuesday.
Download: https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2020/2020-02-11/hotels.csv

## 8. Deliverables
1. SQL analysis answering the 10 business questions (`Hotelcancellationanalysis.sql`)
2. Power BI dashboard for management (`Hotel_Cancellation_Dashboard.pbit` and `.pdf`)
3. Findings and recommendations with estimated revenue impact
