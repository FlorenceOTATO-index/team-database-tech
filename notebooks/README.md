# Notebooks

Exploration and analysis notebooks.

- **Naming:** `NN_initials_topic.ipynb`, e.g. `01_rw_explore_accident.ipynb`. Your initials keep two people from editing the same notebook, which causes merge conflicts that are very hard to fix.
- **Read data from** `../data/raw/` or `../data/processed/`. Never write back into `raw/`.
- **Clear large outputs** before committing (*Kernel → Restart & Clear Output*) so diffs stay readable.
- Once cleaning code works, move it into a script in `src/etl/` so everyone can rerun it.
