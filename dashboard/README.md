# FARS 2024 dashboard

An interactive web app on top of our MySQL database. Every chart is a live SQL
query: change a filter and the page re-runs the queries and redraws.

## Run it

You need the `fars` database built first (see [docs/database-setup.md](../docs/database-setup.md)).
From the repository root:

```bash
# 1. one-time: indexes and the saved view used by the dashboard and q21/q22
mysql -u root -p < sql/schema/indexes.sql
mysql -u root -p < sql/schema/views.sql

# 2. one-time: Python packages (Flask, PyMySQL, python-dotenv)
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 3. your MySQL login (never committed)
cp .env.example .env               # then type your password into .env

# 4. start it
python dashboard/app.py
```

Then open <http://127.0.0.1:5000>. The green dot in the top bar means it reached
MySQL. If `views.sql` wasn't run, the app creates `v_crash_facts` on start.

## Architecture

```
browser (static/app.js)  --fetch-->  Flask (app.py)  --PyMySQL-->  MySQL 8 · fars (53 tables + v_crash_facts)
   draws SVG/canvas charts           /api/chart/<id>        runs the chart's SQL with the filters as parameters
   from the rows it gets back        /api/queries/<file>    runs a saved file from sql/queries/
                                     /api/schema            reads information_schema + COUNT(*) per table
```

- **`charts.py`**: the SQL behind each chart. Each one is a team query from
  `sql/queries/`, with `{f}` where the filter clause goes. Filter values are always
  sent as query parameters (`%(state)s`), never pasted into the SQL string.
- **`app.py`**: the Flask routes. Each chart response carries the rows, the exact SQL
  that ran, how long it took, and which saved file(s) it comes from.
- **SQL button on every card**: opens a side panel with four things:
  - who wrote the query
  - the saved `.sql` file exactly as it is in the repo (`/api/source`)
  - the SQL as this chart ran it, with the current filters
  - the result rows as a table
  
  A short note says how the chart's version differs from the saved file, for example
  "returns raw counts; the chart computes the percentages". Those notes are `SOURCES`
  in `charts.py`.
- **`portfolio.py`**: the question, technique and insight shown next to each saved query.
- **`templates/index.html`**, **`static/app.css`**, **`static/app.js`**: the front end.
  It uses no chart library: the charts are SVG and canvas drawn from the query results.
  The only things it loads from the internet are the Google Fonts; without a connection
  it falls back to system fonts.

## What's on each page

| Page | Charts (query · member) |
|---|---|
| Overview | crash dot map + KPIs (`v_crash_facts` · Ryan), holiday calendar (q17 · Ryan), weekday × hour heatmap (q05 · Tzu Yang, q10 · Jue), vehicles by state (saida_q2 · Saida), deaths by month (q09 · Jue) |
| Behavior | drinking-driver tile map (q01 · Ryan), wrong-way clock (q19 · Ryan), repeat DWI (q14 · Ryan), alcohol vs drugs (q20 · Ryan), drinking + speeding after dark (q22 · Ryan), speeding by crash type (q07 · Tzu Yang) |
| Survival | seat belts (q13 · Ryan), vehicle age (q15 · Ryan), rural vs urban time of death (q16 · Ryan), EMS response (q03 · Ryan), pedestrians by time of day (saida_q4 · Saida), vehicle types in pedestrian crashes (saida_q3 · Saida), weather (q11 · Jue), rollover (q08 · Tzu Yang) |
| Query Portfolio | every file in `sql/queries/`, run live: question → SQL → result → insight |
| Database | live table / PK / FK / row counts, the final EER diagram, the load pipeline |

That's 20 charts, and each member has at least 2 tied to their own SQL.

**Controls:**
- State, area (rural/urban) and month-range filters apply to every chart.
- Clicking a state on the tile map or the vehicles chart filters to that state.
- The map can highlight drinking-driver, after-dark or pedestrian crashes.
- Hovering any mark shows its numbers.

## Notes

- The monthly chart sums `FATALS` from `accident` directly. `09_monthly_stats.sql`
  sums it after joining to `person`, which counts each crash's deaths once per person.
- Charts that compare states (tile map, vehicles by state) ignore the state filter and
  highlight the selected state instead.
