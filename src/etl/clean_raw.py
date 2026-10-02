"""Light, lossless clean of the raw FARS CSVs: data/raw/ -> data/processed/.

What it does (details in data/processed/README.md, which this script regenerates):
  * reads every value as text, so nothing is reformatted (leading zeros, decimals, blanks)
  * strips stray spaces from values
  * moves the duplicate text-label columns (STATENAME, HARM_EVNAME, ...) into lookup
    tables in data/processed/lookups/, then drops them from the data files
  * drops columns that are 100% empty, renames race.ORDER -> RACE_ORDER (SQL keyword)
  * writes lowercase file names

Then it proves nothing was lost: every dropped label column is rebuilt from the lookups
and compared with the raw file. Any check that fails stops the script with an error.

Usage (from the repo root):
    python -m src.etl.clean_raw
"""

import hashlib
import json
from collections import Counter, defaultdict

import pandas as pd

from src.etl.paths import LOOKUPS_DIR, PROCESSED_DIR, RAW_DIR

RENAMES = {"ORDER": "RACE_ORDER"}  # MySQL reserved words
STATE_KEYED = {"COUNTY", "CITY"}   # codes that only mean something together with STATE
MAX_MB = 50                        # GitHub warns above 50 MB, rejects above 100 MB


class CheckFailed(Exception):
    pass


def norm(label: str) -> str:
    """Collapse repeated/odd whitespace: 'Trailers  Unknown' -> 'Trailers Unknown'."""
    return " ".join(label.split())


def is_redundant(code: str, label: str) -> bool:
    """True if the label just repeats the code (e.g. LATITUDE 33.47 / LATITUDENAME 33.47)."""
    if label == code:
        return True
    try:
        return float(label) == float(code)
    except ValueError:
        return False


def code_sort_key(code: str):
    try:
        return (0, float(code), code)
    except ValueError:
        return (1, 0.0, code)


def sha256(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def clean_file(path, combos):
    """Clean one raw file, write it, and return its manifest entry.

    Also records every distinct (STATE, code, label) combination of each label pair in
    `combos`, which is used afterwards to build the lookups and run the round-trip check.
    """
    df = pd.read_csv(path, dtype=str, keep_default_na=False)
    raw_rows, raw_cols = len(df), len(df.columns)
    df = df.apply(lambda s: s.str.strip())

    pairs = [(c[:-4], c) for c in df.columns if c.endswith("NAME") and c[:-4] in df.columns]
    for code, name in pairs:
        frame = pd.DataFrame({
            "state": df["STATE"] if "STATE" in df.columns else "",
            "code": df[code],
            "label": df[name],
        })
        counts = frame.groupby(["state", "code", "label"], sort=False).size().reset_index(name="n")
        combos.append((path.name, code, counts))

    label_cols = [name for _, name in pairs]
    df = df.drop(columns=label_cols)
    empty_cols = [c for c in df.columns if (df[c] == "").all()]
    df = df.drop(columns=empty_cols)
    renamed = {old: new for old, new in RENAMES.items() if old in df.columns}
    df = df.rename(columns=renamed)

    out = PROCESSED_DIR / f"{path.stem.lower()}.csv"
    df.to_csv(out, index=False, lineterminator="\n", encoding="utf-8")

    # Re-read what we wrote and make sure it matches exactly (row count + every value).
    back = pd.read_csv(out, dtype=str, keep_default_na=False)
    if len(back) != raw_rows:
        raise CheckFailed(f"{out.name}: wrote {len(back)} rows, raw file has {raw_rows}")
    if not back.equals(df.reset_index(drop=True)):
        raise CheckFailed(f"{out.name}: re-read file does not match what was written")
    size_mb = out.stat().st_size / 1e6
    if size_mb > MAX_MB:
        raise CheckFailed(f"{out.name} is {size_mb:.1f} MB (limit {MAX_MB} MB)")

    print(f"  {path.name:22} -> {out.name:22} {raw_rows:>7,} rows  "
          f"{raw_cols:>3} -> {len(df.columns):>3} cols  {size_mb:6.1f} MB")
    return {
        "raw_file": path.name,
        "raw_sha256": sha256(path),
        "processed_file": out.name,
        "rows": raw_rows,
        "raw_columns": raw_cols,
        "processed_columns": len(df.columns),
        "processed_mb": round(size_mb, 1),
        "dropped_label_columns": label_cols,
        "dropped_empty_columns": empty_cols,
        "renamed_columns": renamed,
    }


def build_lookups(combos):
    """Turn the collected (code, label) combinations into lookup tables."""
    # Find codes whose label differs within a single file -> they depend on STATE.
    state_keyed = set()
    for _, code, counts in combos:
        real = counts[[not is_redundant(c, l) for c, l in zip(counts.code, counts.label)]]
        if real.assign(label=real.label.map(norm)).groupby("code").label.nunique().gt(1).any():
            state_keyed.add(code)
    unexpected = state_keyed - STATE_KEYED
    if unexpected:
        raise CheckFailed(f"codes with more than one label inside one file: {sorted(unexpected)}. "
                          "Check whether they depend on another column (like COUNTY on STATE).")

    # Key every label by (column, state, code); state is "" unless the code depends on it.
    label_counts = defaultdict(Counter)      # key -> Counter(label)
    sources = defaultdict(set)               # key -> raw files
    for fname, code, counts in combos:
        for state, c, label, n in counts.itertuples(index=False):
            if is_redundant(c, label):
                continue
            key = (code, state if code in state_keyed else "", c)
            label_counts[key][norm(label)] += n
            sources[key].add(fname)

    # Pick one label per code: most common, ties broken alphabetically. Record the rest.
    chosen, conflicts = {}, []
    for key, counter in label_counts.items():
        ranked = sorted(counter.items(), key=lambda kv: (-kv[1], kv[0]))
        chosen[key] = ranked[0][0]
        if len(ranked) > 1:
            for label, n in ranked:
                conflicts.append({"column": key[0], "state": key[1], "code": key[2], "label": label,
                                  "rows": n, "chosen": label == ranked[0][0]})

    rows = [{"column": col, "code": c, "label": label,
             "source_files": ";".join(sorted(sources[(col, s, c)]))}
            for (col, s, c), label in chosen.items() if col not in state_keyed]
    rows.sort(key=lambda r: (r["column"], code_sort_key(r["code"])))
    pd.DataFrame(rows).to_csv(LOOKUPS_DIR / "code_labels.csv", index=False, lineterminator="\n")

    for col in sorted(state_keyed):
        table = sorted(((s, c, label) for (k, s, c), label in chosen.items() if k == col),
                       key=lambda r: (code_sort_key(r[0]), code_sort_key(r[1])))
        pd.DataFrame(table, columns=["STATE", col, f"{col}NAME"]).to_csv(
            LOOKUPS_DIR / f"{col.lower()}.csv", index=False, lineterminator="\n")

    conflicts.sort(key=lambda r: (r["column"], code_sort_key(r["state"]), code_sort_key(r["code"]),
                                  not r["chosen"], r["label"]))
    pd.DataFrame(conflicts, columns=["column", "state", "code", "label", "rows", "chosen"]).to_csv(
        LOOKUPS_DIR / "label_conflicts.csv", index=False, lineterminator="\n")

    variants = {(r["column"], r["state"], r["code"], r["label"]) for r in conflicts}
    n_state = {col: sum(k == col for k, _, _ in chosen) for col in sorted(state_keyed)}
    print(f"  code_labels.csv: {len(rows):,} codes in {len({r['column'] for r in rows})} columns; "
          f"{', '.join(f'{c.lower()}.csv: {n:,}' for c, n in n_state.items())}; "
          f"label_conflicts.csv: {len({(r['column'], r['state'], r['code']) for r in conflicts})} codes")
    return chosen, state_keyed, variants, len(rows)


def round_trip_check(combos, chosen, state_keyed, variants):
    """Rebuild every dropped label column from the lookups and compare with the raw values."""
    failures = []
    for fname, code, counts in combos:
        for state, c, label, n in counts.itertuples(index=False):
            s = state if code in state_keyed else ""
            rebuilt = chosen.get((code, s, c), c)
            ok = (label == rebuilt
                  or norm(label) == rebuilt
                  or is_redundant(c, label)
                  or (code, s, c, norm(label)) in variants)
            if not ok:
                failures.append(f"{fname} {code}={c!r}: raw label {label!r}, rebuilt {rebuilt!r}")
    if failures:
        raise CheckFailed("round-trip check failed:\n    " + "\n    ".join(failures[:20]))
    print(f"  round-trip check passed: {sum(len(x[2]) for x in combos):,} distinct "
          f"code/label combinations in {len(combos)} label columns rebuilt from lookups")


def write_readme(manifest, n_codes):
    lines = [
        "# Processed data",
        "",
        "**Generated by `python -m src.etl.clean_raw`. Don't edit these files (or this README) by hand.**",
        "Rerun the script instead. Running it twice on the same raw data gives identical files.",
        "",
        "## What changed from `data/raw/`",
        "- Every value is kept exactly as text (no type conversion); leading/trailing spaces were trimmed.",
        "- Text-label columns (`STATENAME`, `HARM_EVNAME`, …) were moved to `lookups/` and dropped here.",
        "  Labels that only repeated the code (e.g. `LATITUDENAME`) aren't in the lookups, because the code column already has that value.",
        "- Columns that were 100% empty were dropped. `race.ORDER` was renamed to `RACE_ORDER` (SQL keyword).",
        "- No rows were removed. `drugs.csv` has repeated identical rows; these are real repeated test results.",
        "- `manifest.json` records the SHA-256 of every raw file used, so we know which FARS release this came from.",
        "",
        "## Lookups (`lookups/`)",
        "| File | Columns | Use |",
        "|---|---|---|",
        f"| `code_labels.csv` | `column, code, label, source_files` | {n_codes:,} code→label pairs. Filter by `column`. |",
        "| `county.csv` | `STATE, COUNTY, COUNTYNAME` | County codes repeat across states, so join on both. |",
        "| `city.csv` | `STATE, CITY, CITYNAME` | Same as county. |",
        "| `label_conflicts.csv` | `column, state, code, label, rows, chosen` | Codes that had more than one label in the raw data (spelling/spacing variants, a few city names), every variant with its row count, and which one was kept. |",
        "",
        "## Files",
        "| File | Rows | Columns (raw → processed) | MB | Dropped / renamed |",
        "|---|---:|---|---:|---|",
    ]
    for m in manifest["files"]:
        notes = []
        if m["dropped_label_columns"]:
            notes.append(f"{len(m['dropped_label_columns'])} label cols")
        if m["dropped_empty_columns"]:
            notes.append("empty: " + ", ".join(f"`{c}`" for c in m["dropped_empty_columns"]))
        notes += [f"`{a}`→`{b}`" for a, b in m["renamed_columns"].items()]
        lines.append(f"| `{m['processed_file']}` | {m['rows']:,} | {m['raw_columns']} → "
                     f"{m['processed_columns']} | {m['processed_mb']} | {'; '.join(notes) or '–'} |")
    lines += [
        "",
        "## Left for schema design (not done here on purpose)",
        "- FARS \"unknown\" codes (8/9, 98/99, 998/999, …) are still codes, not NULL.",
        "- Blank values are empty strings; decide on NULL vs '' when loading into MySQL.",
        "- `YEAR` (always 2024) and the `STATE`/date columns repeated in child tables are kept.",
        "- `drugs.csv` has no natural primary key (repeated rows), so it will need a surrogate key.",
        "- All values are text; choose real data types in the schema.",
        "",
    ]
    (PROCESSED_DIR / "README.md").write_text("\n".join(lines))


def main():
    raw_files = sorted((p for p in RAW_DIR.iterdir() if p.suffix.lower() == ".csv"),
                       key=lambda p: p.name.lower())
    if not raw_files:
        raise SystemExit("No CSVs in data/raw/. Run: python scripts/download_data.py")
    LOOKUPS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Cleaning {len(raw_files)} files from data/raw/ ...")
    combos, files = [], []
    for path in raw_files:
        files.append(clean_file(path, combos))

    print("Building lookups ...")
    chosen, state_keyed, variants, n_codes = build_lookups(combos)

    print("Checking ...")
    round_trip_check(combos, chosen, state_keyed, variants)

    manifest = {"source": "NHTSA FARS 2024 National (CSV + Auxiliary CSV)", "files": files}
    (PROCESSED_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    write_readme(manifest, n_codes)

    total = sum(f["processed_mb"] for f in files)
    print(f"Done. {len(files)} files, {total:.0f} MB total, written to data/processed/")


if __name__ == "__main__":
    try:
        main()
    except CheckFailed as e:
        raise SystemExit(f"CHECK FAILED: {e}")
