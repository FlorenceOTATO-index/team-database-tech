# Saida — SQL portfolio (final presentation)

Seven new queries: **2 basic + 5 advanced**, each in its own file.
Every advanced query uses a **different** technique, so my set alone
covers five of the rubric's categories.

## Coverage

| File | Type | Technique | Question |
|---|---|---|---|
| `saida_q05_basic_work_zone.sql` | basic | WHERE + lookup join + GROUP BY | How many fatal crashes were in a road work zone? |
| `saida_q06_basic_seat_position.sql` | basic | 2-table join + GROUP BY + LIMIT | Where were people sitting? |
| `saida_q07_advanced_view_occupant_safety.sql` | advanced | **VIEW** | Did the air bag deploy, and who survived? |
| `saida_q08_advanced_window_seat_rank.sql` | advanced | **WINDOW FUNCTION** (`RANK()`) | Which seat is the most dangerous? |
| `saida_q09_advanced_subquery_parked_units.sql` | advanced | **SUBQUERY** (`IN`) | Are crashes with a parked/working vehicle deadlier? |
| `saida_q10_advanced_cte_school_bus.sql` | advanced | **CTE** | How do school-bus crashes compare? |
| `saida_q11_advanced_index_work_zone.sql` | advanced | **INDEXING** (`EXPLAIN ANALYZE`) | How much faster is the work-zone filter with an index? |

Plus my four from the mid-presentation: `saida_q1_basic`, `saida_q2_basic`,
`saida_q3_advanced` (subquery), `saida_q4_advanced` (CTE).

## No overlap with teammates

Checked against every file in `sql/queries/` on 2026-11-27.

| Topic | Who |
|---|---|
| alcohol, driver age, EMS, seatbelts, prior DWI, vehicle age, holidays, hit-and-run, wrong-way, drugs | Ryan |
| time of day, one vs many vehicles, speeding, rollover | Matt |
| monthly, day of week, weather | Jue |
| **work zones, seat position, air bags, parked/working vehicles, school buses** | **mine — untouched by anyone** |

Ryan's view `v_crash_facts` is crash-level; my `v_occupant_safety` is
person-level, so the two do not overlap. His indexes are on
`accident(STATE, MONTH)` and `vehicle(PREV_DWI)`; mine is on
`accident(WRK_ZONE)`.

## Run order

1. `saida_q07_...` — creates the view that Q08 reads from
2. Everything else in any order
3. `saida_q11_...` creates an index; the file has the `DROP INDEX` to undo it

## Results — all seven run 2026-11-27

| Q | Headline |
|---|---|
| 05 | 763 work-zone crashes, 850 deaths — 2.1% of all crashes; Construction is 58% of them |
| 06 | 70% of occupants were in the driver's seat; 86% in the front row |
| 07 | Air bag deployed → 46.6% died; not deployed → 32.2%. Confounded, not causal |
| 08 | Driver's seat ranks 1st at 44.2% died. Front row is 1.9× deadlier than the second row |
| 09 | Parked/working vehicle in 2.9% of crashes; no deadlier (1.10 vs 1.08) — a null result |
| 10 | School buses in 92 crashes; 2× the people involved, only 11% more deaths |
| 11 | Index cuts rows read 36,297 → 763 and time 13.7 ms → 2.8 ms |

### Consistency checks, all passing

These are worth one slide sentence, because they show the queries agree
with each other rather than each being run in isolation.

- **36,297 crashes** — Q09 (35,227 + 1,070) and Q10 (36,205 + 92) both
  partition the whole `accident` table and both add up.
- **39,254 deaths** — Q09 and Q10 produce the same total independently.
- **79,306 occupants** — Q06 counts them straight from `person`; Q08
  reaches the same seat counts row for row through the view.
- **763 work-zone crashes** — Q05 counts them, Q11's index scan reads
  exactly that many rows.
- **`INJ_SEV = 4` is the fatal code** — confirmed by arithmetic, not
  assumed: Q07's 30,741 occupant deaths plus 8,513 non-motorist deaths
  equals Q09's 39,254 total, and 8,513 of 9,020 non-motorists is 94%,
  which is what a pedestrian-fatality rate should look like.
