# Data

## Source
**NHTSA Fatality Analysis Reporting System (FARS), 2024 national data.** FARS is a census of every fatal motor-vehicle crash on U.S. public roads.

- Overview: https://www.nhtsa.gov/research-data/fatality-analysis-reporting-system-fars
- Downloads: https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/FARS/2024/National/
- Column meanings: see the *FARS/CRSS Analytical User's Manual* (linked from the overview page)

## Folders

| Folder | In git? | What goes here |
|---|---|---|
| `raw/` | **No** (gitignored) | The original FARS CSVs, exactly as downloaded. Never edit these. |
| `processed/` | **Yes** | Cleaned CSVs that the team shares and loads into MySQL. |

### Getting the raw data
From the repo root:
```bash
python scripts/download_data.py
```
This downloads two zips from NHTSA (main + auxiliary) and unpacks all 36 CSVs into `data/raw/`, about 390 MB in total.

### Rules for `processed/`
1. **Every processed file is made by a script** in `src/etl/`. Don't edit CSVs by hand, so anyone can regenerate them.
2. **Keep each file under 50 MB.** GitHub warns above 50 MB and rejects files over 100 MB.
   - The biggest savings come from dropping the `*NAME` columns. FARS stores every code twice (`STATE=1` *and* `STATENAME=Alabama`). Put each code→label pair in a small table in `processed/lookups/` instead. That is also the normalized design we want in MySQL.
   - If a file is still too big, ask the team before using Git LFS.
3. **Rebuild with** `python -m src.etl.clean_raw`. It regenerates [processed/README.md](processed/README.md) and `processed/manifest.json`, which records the raw files' checksums. NHTSA republishes FARS, so the manifest tells us exactly which release our processed data came from.

## Raw file sizes (2024)
Most files are small. The large ones are:

| File | Size | Rows | Columns (of which `*NAME`) |
|---|---|---|---|
| person.csv | 112 MB | 88,326 | 126 (60) |
| vehicle.csv | 105 MB | 56,011 | 201 (92) |
| vpicdecode.csv | 45 MB | | |
| accident.csv | 23 MB | 36,297 | 80 (34) |
| drugs.csv | 21 MB | | |

See [../docs/data_dictionary.md](../docs/data_dictionary.md) for how the tables join.
