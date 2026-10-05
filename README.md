# team-database-tech
SJSU DATA 201 Database Technology team project

We're designing a **MySQL** database for the **NHTSA FARS 2024** dataset. FARS records every fatal motor-vehicle crash in the U.S. We'll load the data into MySQL and use SQL to answer questions about it.

## Team

| Name | Role / focus | GitHub |
|---|---|---|
| Ryan Williams | | |
| Jue Wang | Normalization, Relational schema design | |
| | | |
| | | |

---

## Repo map

```
team-database-tech/
├── data/
│   ├── raw/          ← original FARS CSVs (NOT in git; download them, see below)
│   └── processed/    ← cleaned CSVs shared by the team (in git)
├── scripts/          ← one-off utilities (download_data.py)
├── src/etl/          ← Python code that cleans data and loads it into MySQL
├── sql/
│   ├── schema/       ← CREATE TABLE scripts, run in numeric order
│   ├── load/         ← scripts that load processed data into MySQL
│   └── queries/      ← analysis queries, one question per file
├── notebooks/        ← Jupyter exploration
├── docs/             ← ER diagram, data dictionary, proposal
└── reports/          ← final report and slides
```

**Where does my work go?**

| I'm working on… | Put it in… |
|---|---|
| Cleaning a table | a script in `src/etl/` that writes to `data/processed/` |
| Table design / DDL | `sql/schema/` + update `docs/erd/` |
| An analysis question | `sql/queries/qNN_short_name.sql` |
| Poking around the data | `notebooks/NN_initials_topic.ipynb` |
| Writing / slides | `reports/` |

Each folder has its own README with the details.

---

## Setup (do this once)

You need: [Git](https://git-scm.com/downloads), Python 3.10+, and [MySQL 8](https://dev.mysql.com/downloads/) (MySQL Workbench is helpful too).

```bash
# 1. Get the code
git clone https://github.com/FlorenceOTATO-index/team-database-tech.git
cd team-database-tech

# 2. Make a Python environment and install packages
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 3. Add your MySQL login
cp .env.example .env               # then open .env and type your password
```

The cleaned data in `data/processed/` comes with the clone, so most people can start there. You only need the raw data if you want to look at the original files or change the cleaning:

```bash
python scripts/download_data.py    # raw FARS data (~390 MB) into data/raw/
python -m src.etl.clean_raw        # rebuilds data/processed/ from data/raw/ (~20 sec)
```

To build the database, run the files in `sql/schema/` in order, then the ones in `sql/load/`.

---

## Data rules (please read)

- **`data/raw/` is never committed.** The files are too big for GitHub (two are over 100 MB). Everyone downloads them with the script above.
- **`data/processed/` is committed**, so we all use the same cleaned data. Every file there must be made by a script in `src/etl/`. Never edit a CSV by hand.
- **Keep processed files under 50 MB.** `src/etl/clean_raw.py` already does this by moving the duplicate `...NAME` text columns (FARS stores `STATE=1` *and* `STATENAME=Alabama`) into lookup tables in `data/processed/lookups/`. It checks that nothing is lost. See [data/processed/README.md](data/processed/README.md) for what changed.
- **Never commit `.env`.** It has your password. It's already in `.gitignore`.

---

## How we work with Git

**Short version: never push directly to `main`.** Make a branch, push it, and open a Pull Request (PR) so a teammate can look at it before it's merged. This keeps us from overwriting each other's work.

### Every time you start something new

```bash
git checkout main
git pull                                   # get everyone's latest work
git checkout -b yourname/short-description # e.g. ryan/accident-table-ddl
```

### While you work

```bash
git status                                 # see what changed
git add sql/schema/01_create_tables.sql    # add specific files
git commit -m "Add accident table DDL"     # short message, what + why
```
Commit often. Small commits are easier to review and undo.

### When you're ready to share

```bash
git push -u origin yourname/short-description
```
Then open GitHub. You'll see a yellow banner with a **"Compare & pull request"** button. Click it, write a sentence or two about what you did, and request a teammate as reviewer.

### Reviewing / merging
- The reviewer reads the changes and leaves comments or approves.
- After approval, click **"Squash and merge"** on GitHub, then delete the branch.
- Everyone else runs `git checkout main && git pull` to get the update.

### If `main` changed while you were working
```bash
git checkout main && git pull
git checkout yourname/short-description
git merge main          # fix any conflicts, then git add + git commit
```

### Tips to avoid conflicts
- Tell the group chat what you're working on, so two people don't edit the same file.
- Notebooks are especially hard to merge, so each person uses their own (`NN_initials_topic.ipynb`).
- Before committing, check `git status` and make sure no raw data or `.env` slipped in.

---

## Conventions

| Thing | Convention | Example |
|---|---|---|
| Branches | `name/what-youre-doing` | `maria/clean-person` |
| Schema SQL | numbered, run in order | `sql/schema/02_create_lookups.sql` |
| Query SQL | one question per file, question in a top comment | `sql/queries/q03_alcohol_by_hour.sql` |
| Notebooks | number, initials, topic | `notebooks/02_rw_explore_vehicle.ipynb` |
| ETL scripts | `clean_<table>.py` | `src/etl/clean_accident.py` |
| SQL style | `UPPERCASE` keywords, `snake_case` names | `SELECT st_case FROM accident` |

---

## References
- [FARS overview & user manuals](https://www.nhtsa.gov/research-data/fatality-analysis-reporting-system-fars) for what each column means
- [FARS 2024 file downloads](https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/FARS/2024/National/)
- [docs/data_dictionary.md](docs/data_dictionary.md): how the tables join, with gotchas
