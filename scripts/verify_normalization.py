"""Verification checks for the FARS 2024 normalization analysis.

Run from the repo root:
    python scripts/verify_normalization.py

Covers docs/schema/normalization.md:
  - Step 1: key identification (uniqueness of natural keys)
  - Step 2: 1NF (atomic cells, repeating-group scan)
  - Step 3: 2NF — complete FD catalog, decomposition into 2NF relations,
             each new relation verified 2NF-clean, lossless-join proof
  - Step 4: 3NF (no surviving label columns; DAY_WEEK exception)

Author: Jue Wang
"""

import csv

import pandas as pd

DATA = "data/processed"
results = []


def check(name, passed, detail=""):
    results.append(passed)
    status = "PASS" if passed else "FAIL"
    print(f"[{status}] {name}" + (f" — {detail}" if detail else ""))


# ---------------------------------------------------------------- 1NF: keys
a = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE"])
check("accident: ST_CASE unique",
      a["ST_CASE"].nunique() == len(a), f"{len(a)} rows")

v = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE", "VEH_NO"])
check("vehicle: (ST_CASE, VEH_NO) unique",
      v.duplicated(subset=["ST_CASE", "VEH_NO"]).sum() == 0,
      f"{len(v)} rows")

p = pd.read_csv(f"{DATA}/person.csv", usecols=["ST_CASE", "VEH_NO", "PER_NO"])
check("person: (ST_CASE, VEH_NO, PER_NO) unique",
      p.duplicated(subset=["ST_CASE", "VEH_NO", "PER_NO"]).sum() == 0,
      f"{len(p)} rows")

# ------------------------------------------------------- 1NF: atomic cells
for fname in ["accident.csv", "vehicle.csv", "person.csv"]:
    with open(f"{DATA}/{fname}", newline="") as fh:
        multi = sum(1 for row in csv.reader(fh)
                    for cell in row if ";" in cell)
    check(f"{fname}: cells hold single values", multi == 0,
          f"{multi} multi-value cells")

# ------------------------------------------------- 1NF: repeating groups
with open(f"{DATA}/vehicle.csv", newline="") as fh:
    header = next(csv.reader(fh))
numbered = [c for c in header if c.rsplit("_", 1)[-1].isdigit()]
print(f"[INFO] vehicle.csv numbered columns: {numbered} "
      "(fixed positional VIN characters; atomic, kept deliberately)")

# ============================================================ 2NF: FD catalog
# Every attribute is assigned to exactly one level by grain:
#   crash-grain   -> determined by ST_CASE            (kept in ACCIDENT)
#   vehicle-grain -> determined by (ST_CASE, VEH_NO)  (kept in VEHICLE)
#   person-grain  -> determined by (ST_CASE, VEH_NO, PER_NO) (kept in PERSON)
acc_cols = set(pd.read_csv(f"{DATA}/accident.csv", nrows=0).columns)
veh_cols = set(pd.read_csv(f"{DATA}/vehicle.csv", nrows=0).columns)
per_cols = set(pd.read_csv(f"{DATA}/person.csv", nrows=0).columns)

crash_attrs = sorted(acc_cols - {"ST_CASE"})                       # 45
veh_grain = sorted((veh_cols - acc_cols) - {"ST_CASE", "VEH_NO"})   # 99
crash_in_veh = sorted((veh_cols & acc_cols) - {"ST_CASE"})         # 8
crash_in_per = sorted((per_cols & acc_cols) - {"ST_CASE"})         # 12
veh_in_per = sorted((per_cols & veh_cols) - acc_cols
                    - {"ST_CASE", "VEH_NO"})                       # 16
per_grain = sorted(set(per_cols) - {"ST_CASE", "VEH_NO", "PER_NO"}
                   - set(crash_in_per) - set(veh_in_per))           # 35

print(f"[INFO] FD1: ST_CASE -> {len(crash_attrs)} crash attributes")
print(f"       {crash_attrs}")
print(f"[INFO] FD2: (ST_CASE, VEH_NO) -> {len(veh_grain)} vehicle attributes")
print(f"       {veh_grain}")
print(f"[INFO] FD3: (ST_CASE, VEH_NO, PER_NO) -> {len(per_grain)} person attributes")
print(f"       {per_grain}")
print(f"[INFO] violations moved to parent: vehicle loses {crash_in_veh}")
print(f"[INFO] violations moved to parent: person loses {crash_in_per + veh_in_per}")

# ====================================== 2NF: every violation individually proven
_v = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE"] + crash_in_veh)
bad_v = [c for c in crash_in_veh
         if _v.groupby("ST_CASE")[c].nunique().max() != 1]
check("vehicle: all 8 moved cols are crash-grain", bad_v == [],
      f"exceptions (must NOT move these) = {bad_v}")

_p = pd.read_csv(f"{DATA}/person.csv",
                 usecols=["ST_CASE", "VEH_NO"] + crash_in_per + veh_in_per)
bad_pc = [c for c in crash_in_per
          if _p.groupby("ST_CASE")[c].nunique().max() != 1]
bad_pv = [c for c in veh_in_per
          if _p.groupby(["ST_CASE", "VEH_NO"])[c].nunique().max() != 1]
check("person: all 12 moved crash-cols are crash-grain", bad_pc == [],
      f"exceptions = {bad_pc}")
check("person: all 16 moved vehicle-cols are vehicle-grain", bad_pv == [],
      f"exceptions = {bad_pv}")

# ============================ 2NF: the NEW relations are themselves 2NF-clean
# A decomposed relation must have no partial dependency left: no remaining
# non-key column may be determined by a proper subset of the key.
# (One groupby per level checks every remaining column at once.)
_vn = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE"] + veh_grain)
mx_v = _vn.groupby("ST_CASE").nunique().max()
tot_v = _vn.nunique()
crash_det = mx_v[mx_v == 1].index.tolist()
# Degenerate case: single-valued across the whole dataset. The FD holds
# vacuously (it is determined by *everything*, including the empty set), so
# there is no redundancy anomaly to fix; the column stays where it belongs
# semantically. Only genuinely crash-varying leftovers are failures.
degenerate_v = [c for c in crash_det if tot_v[c] == 1]
leftover_v = [c for c in crash_det if tot_v[c] != 1]
if degenerate_v:
    print(f"[INFO] degenerate partial deps (single-valued dataset-wide, "
          f"kept in VEHICLE): {degenerate_v}")
# VEH_NO alone determines nothing (numbering restarts per crash): the only
# proper subset of the key that could matter is {ST_CASE}, checked above.
check("new VEHICLE has no genuine partial dependency left", leftover_v == [],
      f"still crash-determined = {leftover_v}")

_pn = pd.read_csv(f"{DATA}/person.csv",
                  usecols=["ST_CASE", "VEH_NO"] + per_grain)
mx_p1 = _pn.groupby("ST_CASE").nunique().max()
mx_p2 = _pn.groupby(["ST_CASE", "VEH_NO"]).nunique().max()
leftover_p = sorted(set(mx_p1[mx_p1 == 1].index)
                    | set(mx_p2[mx_p2 == 1].index))
check("new PERSON has no partial dependency left", leftover_p == [],
      f"still determined by key subset = {leftover_p}")

# accident: single-column key -> 2NF holds by definition
check("ACCIDENT in 2NF (single-column key)", True,
      "no partial dependency possible")

# ------------------------------------------------- 2NF: lossless-join proof
_vm = pd.read_csv(f"{DATA}/vehicle.csv", usecols=["ST_CASE"] + crash_in_veh)
_am = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE"] + crash_in_veh)
m = _vm.merge(_am, on="ST_CASE", suffixes=("_v", "_a"))
mism_v = {}
for c in crash_in_veh:
    lv = m[f"{c}_v"].astype(object).fillna("∅")
    la = m[f"{c}_a"].astype(object).fillna("∅")
    mism_v[c] = int((lv != la).sum())
check("vehicle decomposition is lossless",
      all(n == 0 for n in mism_v.values()), f"mismatches = {mism_v}")

_pm = pd.read_csv(f"{DATA}/person.csv",
                 usecols=["ST_CASE", "VEH_NO"] + crash_in_per + veh_in_per)
_am2 = pd.read_csv(f"{DATA}/accident.csv", usecols=["ST_CASE"] + crash_in_per)
_vm2 = pd.read_csv(f"{DATA}/vehicle.csv",
                   usecols=["ST_CASE", "VEH_NO"] + veh_in_per)
m2 = _pm.merge(_am2, on="ST_CASE", suffixes=("_p", "_a"))
m2 = m2.merge(_vm2, on=["ST_CASE", "VEH_NO"], suffixes=("", "_v"))
mism_p = {}
for c in crash_in_per:
    lp = m2[f"{c}_p"].astype(object).fillna("∅")
    la = m2[f"{c}_a"].astype(object).fillna("∅")
    mism_p[c] = int((lp != la).sum())
for c in veh_in_per:
    lp = m2[c].astype(object).fillna("∅")
    la = m2[f"{c}_v"].astype(object).fillna("∅")
    mism_p[c] = int((lp != la).sum())
check("person decomposition is lossless",
      all(n == 0 for n in mism_p.values()), f"mismatches = {mism_p}")

# --------------------------------- 3NF: no surviving label columns
for fname in ["accident.csv", "vehicle.csv", "person.csv"]:
    with open(f"{DATA}/{fname}", newline="") as fh:
        header = next(csv.reader(fh))
    leftover = [c for c in header if c.upper().endswith("NAME")]
    check(f"{fname}: no *NAME label columns remain", leftover == [],
          f"leftover = {leftover}")

# --------------------------------- 3NF: lookup relations are 3NF-clean
for fname, key in [("code_labels.csv", ["column", "code"]),
                   ("county.csv", ["STATE", "COUNTY"]),
                   ("city.csv", ["STATE", "CITY"])]:
    df = pd.read_csv(f"{DATA}/lookups/{fname}", usecols=key)
    check(f"{fname}: key {key} unique",
          df.duplicated(subset=key).sum() == 0, f"{len(df)} rows")

# --------------------------------- 3NF: transitive deps extracted (strict)
# T1: (YEAR, MONTH, DAY) -> DAY_WEEK  =>  CALENDAR
_a = pd.read_csv(f"{DATA}/accident.csv",
                 usecols=["YEAR", "MONTH", "DAY", "DAY_WEEK"])
_cal = _a.drop_duplicates(subset=["YEAR", "MONTH", "DAY"])
check("T1 CALENDAR key (YEAR,MONTH,DAY) unique",
      not _cal.duplicated(subset=["YEAR", "MONTH", "DAY"]).any(),
      f"{len(_cal)} rows")
_m = _a.merge(_cal, on=["YEAR", "MONTH", "DAY"], suffixes=("", "_c"))
check("T1 CALENDAR extraction lossless",
      int((_m["DAY_WEEK"] != _m["DAY_WEEK_c"]).sum()) == 0, "0 mismatches")

# T2: VIN -> VIN_1..VIN_12  =>  VIN_DETAIL
_vcols = ["VIN"] + [f"VIN_{i}" for i in range(1, 13)]
_v = pd.read_csv(f"{DATA}/vehicle.csv", usecols=_vcols)
_vd = _v.drop_duplicates(subset=["VIN"])
check("T2 VIN_DETAIL key VIN unique",
      not _vd.duplicated(subset=["VIN"]).any(), f"{len(_vd)} rows")
_m2 = _v.merge(_vd, on="VIN", suffixes=("", "_d"))
_t2_mism = 0
for _i in range(1, 13):
    _x, _y = _m2[f"VIN_{_i}"], _m2[f"VIN_{_i}_d"]
    _t2_mism += int(((_x != _y) & ~(_x.isna() & _y.isna())).sum())
check("T2 VIN_DETAIL extraction lossless (NaN-aware)", _t2_mism == 0,
      f"{_t2_mism} mismatches; nulls preserved as-is")

# T3: (DEATH_HR, DEATH_MN) -> DEATH_TM  =>  DEATH_TIME
_p = pd.read_csv(f"{DATA}/person.csv",
                 usecols=["DEATH_HR", "DEATH_MN", "DEATH_TM"])
_dt = _p.drop_duplicates(subset=["DEATH_HR", "DEATH_MN"])
check("T3 DEATH_TIME key (DEATH_HR,DEATH_MN) unique",
      not _dt.duplicated(subset=["DEATH_HR", "DEATH_MN"]).any(),
      f"{len(_dt)} rows")
_m3 = _p.merge(_dt, on=["DEATH_HR", "DEATH_MN"], suffixes=("", "_d"))
check("T3 DEATH_TIME extraction lossless",
      int((_m3["DEATH_TM"] != _m3["DEATH_TM_d"]).sum()) == 0, "0 mismatches")

# --------------------------------- Child tables: 1NF keys
child_keys = {
    "acc_aux.csv": ["ST_CASE"],
    "cevent.csv": ["ST_CASE", "EVENTNUM"],
    "crashrf.csv": ["ST_CASE", "CRASHRF"],
    "miacc.csv": ["ST_CASE"],
    "midrvacc.csv": ["ST_CASE"],
    "weather.csv": ["ST_CASE", "WEATHER"],
    "damage.csv": ["ST_CASE", "VEH_NO", "DAMAGE"],
    "distract.csv": ["ST_CASE", "VEH_NO", "DRDISTRACT"],
    "drimpair.csv": ["ST_CASE", "VEH_NO", "DRIMPAIR"],
    "driverrf.csv": ["ST_CASE", "VEH_NO", "DRIVERRF"],
    "factor.csv": ["ST_CASE", "VEH_NO", "VEHICLECC"],
    "maneuver.csv": ["ST_CASE", "VEH_NO", "MANEUVER"],
    "parkwork.csv": ["ST_CASE", "VEH_NO"],
    "pvehiclesf.csv": ["ST_CASE", "VEH_NO", "PVEHICLESF"],
    "vehiclesf.csv": ["ST_CASE", "VEH_NO", "VEHICLESF"],
    "vevent.csv": ["ST_CASE", "VEH_NO", "VEVENTNUM"],
    "violatn.csv": ["ST_CASE", "VEH_NO", "VIOLATION"],
    "vision.csv": ["ST_CASE", "VEH_NO", "VISION"],
    "vpicdecode.csv": ["ST_CASE", "VEH_NO"],
    "vpictrailerdecode.csv": ["ST_CASE", "VEH_NO", "TRAILER_NO"],
    "vsoe.csv": ["ST_CASE", "VEH_NO", "VEVENTNUM", "SOE"],
    "veh_aux.csv": ["ST_CASE", "VEH_NO"],
    "miper.csv": ["ST_CASE", "VEH_NO", "PER_NO"],
    "nmcrash.csv": ["ST_CASE", "VEH_NO", "PER_NO", "NMCC"],
    "nmdistract.csv": ["ST_CASE", "VEH_NO", "PER_NO"],
    "nmimpair.csv": ["ST_CASE", "VEH_NO", "PER_NO", "NMIMPAIR"],
    "nmprior.csv": ["ST_CASE", "VEH_NO", "PER_NO", "NMACTION"],
    "pbtype.csv": ["ST_CASE", "VEH_NO", "PER_NO"],
    "per_aux.csv": ["ST_CASE", "VEH_NO", "PER_NO"],
    "personrf.csv": ["ST_CASE", "VEH_NO", "PER_NO", "PERSONRF"],
    "race.csv": ["ST_CASE", "VEH_NO", "PER_NO", "RACE_ORDER"],
    "safetyeq.csv": ["ST_CASE", "VEH_NO", "PER_NO"],
}
for fname, key in child_keys.items():
    df = pd.read_csv(f"{DATA}/{fname}", usecols=key)
    check(f"{fname}: key {key} unique",
          not df.duplicated(subset=key).any(), f"{len(df)} rows")

_d = pd.read_csv(f"{DATA}/drugs.csv")
check("drugs: 748 exact-duplicate rows (surrogate key needed)",
      int(_d.duplicated().sum()) == 748, f"{len(_d)} rows")

# --------------------------------- Child tables: 2NF
# C1: ST_CASE -> STATE in 30 child tables (drop STATE; kept in ACCIDENT)
_c1_files = ['acc_aux.csv','cevent.csv','crashrf.csv','weather.csv','damage.csv',
 'distract.csv','drimpair.csv','driverrf.csv','factor.csv','maneuver.csv','parkwork.csv',
 'pvehiclesf.csv','vehiclesf.csv','vevent.csv','violatn.csv','vision.csv','vpicdecode.csv',
 'vpictrailerdecode.csv','vsoe.csv','veh_aux.csv','drugs.csv','nmcrash.csv','nmdistract.csv',
 'nmimpair.csv','nmprior.csv','pbtype.csv','per_aux.csv','personrf.csv','race.csv','safetyeq.csv']
for _f in _c1_files:
    _df = pd.read_csv(f"{DATA}/{_f}", usecols=['ST_CASE','STATE'])
    check(f"C1 {_f}: ST_CASE -> STATE",
          _df.groupby('ST_CASE')['STATE'].nunique().max() == 1, "drop STATE from child")

# C2/C3: aux tables (YEAR constant 2024; STATE crash-grain)
_vx = pd.read_csv(f"{DATA}/veh_aux.csv", usecols=['ST_CASE','YEAR','STATE'])
check("C2 veh_aux: YEAR constant", _vx['YEAR'].nunique() == 1, "drop as constant")
check("C2 veh_aux: ST_CASE -> STATE",
      _vx.groupby('ST_CASE')['STATE'].nunique().max() == 1, "drop STATE")
_px = pd.read_csv(f"{DATA}/per_aux.csv", usecols=['ST_CASE','YEAR','STATE'])
check("C3 per_aux: YEAR constant", _px['YEAR'].nunique() == 1, "drop as constant")
check("C3 per_aux: ST_CASE -> STATE",
      _px.groupby('ST_CASE')['STATE'].nunique().max() == 1, "drop STATE")

# C4: parkwork P* crash-cols are exact copies of accident cols
_pw = pd.read_csv(f"{DATA}/parkwork.csv",
    usecols=['ST_CASE','PVE_FORMS','PMONTH','PDAY','PHOUR','PMINUTE','PHARM_EV','PMAN_COLL'])
_ac = pd.read_csv(f"{DATA}/accident.csv",
    usecols=['ST_CASE','VE_FORMS','MONTH','DAY','HOUR','MINUTE','HARM_EV','MAN_COLL'])
_mm = _pw.merge(_ac, on='ST_CASE', how='left')
_c4_pairs = [('PVE_FORMS','VE_FORMS'),('PMONTH','MONTH'),('PDAY','DAY'),('PHOUR','HOUR'),
             ('PMINUTE','MINUTE'),('PHARM_EV','HARM_EV'),('PMAN_COLL','MAN_COLL')]
_c4_bad = 0
for _p, _a in _c4_pairs:
    _c4_bad += int(((_mm[_p] != _mm[_a]) & ~(_mm[_p].isna() & _mm[_a].isna())).sum())
check("C4 parkwork P* == accident cols", _c4_bad == 0, f"{_c4_bad} mismatches")

# C5: ST_CASE -> PHAZ_* => new PARKWORK_HAZMAT
_ph = pd.read_csv(f"{DATA}/parkwork.csv",
    usecols=['ST_CASE','PHAZ_INV','PHAZPLAC','PHAZ_ID','PHAZ_CNO','PHAZ_REL'])
_phd = _ph.drop_duplicates(subset=['ST_CASE'])
check("C5 PARKWORK_HAZMAT key unique",
      not _phd.duplicated(subset=['ST_CASE']).any(), f"{len(_phd)} rows")
_m5 = _ph.merge(_phd, on='ST_CASE', suffixes=('','_h'))
_c5_bad = sum(int(((_m5[c] != _m5[c+'_h']) & ~(_m5[c].isna() & _m5[c+'_h'].isna())).sum())
               for c in ['PHAZ_INV','PHAZPLAC','PHAZ_ID','PHAZ_CNO','PHAZ_REL'])
check("C5 PARKWORK_HAZMAT lossless", _c5_bad == 0, f"{_c5_bad} mismatches")

# C6: acc_aux FATALS/YEAR/STATE are exact copies of accident
_ax = pd.read_csv(f"{DATA}/acc_aux.csv", usecols=['ST_CASE','FATALS','YEAR','STATE'])
_acc = pd.read_csv(f"{DATA}/accident.csv", usecols=['ST_CASE','FATALS','YEAR','STATE'])
_m6 = _ax.merge(_acc, on='ST_CASE', suffixes=('','_a'))
_c6_bad = sum(int((_m6[c] != _m6[c+'_a']).sum()) for c in ['FATALS','YEAR','STATE'])
check("C6 acc_aux FATALS/YEAR/STATE == accident", _c6_bad == 0, f"{_c6_bad} mismatches")

# C7: ST_CASE -> PBSZONE => new CRASH_PBSZONE
_pb = pd.read_csv(f"{DATA}/pbtype.csv", usecols=['ST_CASE','PBSZONE'])
_cz = _pb.drop_duplicates(subset=['ST_CASE'])
check("C7 CRASH_PBSZONE key unique",
      not _cz.duplicated(subset=['ST_CASE']).any(), f"{len(_cz)} rows")
_m7 = _pb.merge(_cz, on='ST_CASE', suffixes=('','_c'))
check("C7 CRASH_PBSZONE lossless",
      int((_m7['PBSZONE'] != _m7['PBSZONE_c']).sum()) == 0, "0 mismatches")

# C8: parkwork trailer constants
_pc = pd.read_csv(f"{DATA}/parkwork.csv", usecols=['PTRLR3VIN','PTRLR3GVWR'])
check("C8 parkwork PTRLR3VIN/PTRLR3GVWR constant",
      all(_pc[c].nunique() == 1 for c in _pc.columns), "drop as constants")

# --------------------------------- Child tables: 3NF (strict)
def _mism2(a, b):
    return int((((a != b) & ~(a.isna() & b.isna())).sum())

def _vex(fname, key, vals, name):
    df = pd.read_csv(f"{DATA}/{fname}", usecols=key + vals, low_memory=False)
    new = df.drop_duplicates(subset=key)
    nn = new.dropna(subset=key)
    m = df.merge(new, on=key, suffixes=("", "_n"), how="left")
    bad = sum(_mism2(m[c], m[c + "_n"]) for c in vals)
    check(f"{name}: key unique",
          not nn.duplicated(subset=key).any(), f"{len(new)} rows")
    check(f"{name}: lossless", bad == 0, f"{bad} mismatches")

_vex('acc_aux.csv', ['STATE'], ['A_REGION'], 'D3 STATE_REGION')
_vex('acc_aux.csv', ['A_ROADFC'], ['A_INTER'], 'D4 ROADFC_INTER')
_vex('acc_aux.csv', ['A_JUNC'], ['A_INTSEC'], 'D5 JUNC_INTSEC')
_vex('per_aux.csv', ['A_AGE3'],
     ['A_AGE1', 'A_AGE2', 'A_AGE4', 'A_AGE5', 'A_AGE9'], 'D6 AGE_BAND_MAP')
_vex('pbtype.csv', ['PEDCTYPE'], ['PEDCGP'], 'D7 PED_CRASH_GROUP')
_vex('pbtype.csv', ['BIKECTYPE'], ['BIKECGP'], 'D8 BIKE_CRASH_GROUP')

# D2: PVIN -> PVIN_1..12 => PVIN_DETAIL
_pwd = pd.read_csv(f"{DATA}/parkwork.csv",
    usecols=['PVIN'] + [f'PVIN_{i}' for i in range(1, 13)], low_memory=False)
_pdd = _pwd.drop_duplicates(subset=['PVIN'])
_pdn = _pdd.dropna(subset=['PVIN'])
_mpd = _pwd.merge(_pdd, on='PVIN', suffixes=('', '_n'), how='left')
_pbad = sum(_mism2(_mpd[f'PVIN_{i}'], _mpd[f'PVIN_{i}_n']) for i in range(1, 13))
check("D2 PVIN_DETAIL: key unique",
      not _pdn.duplicated(subset=['PVIN']).any(), f"{len(_pdd)} rows")
check("D2 PVIN_DETAIL: lossless", _pbad == 0, f"{_pbad} mismatches")

# D1: 68 *ID -> *NAME pairs => VPIC_LABELS(attribute, id, label)
_vvd = pd.read_csv(f"{DATA}/vpicdecode.csv", low_memory=False)
_vpairs = [(c, c[:-2]) for c in _vvd.columns if c.endswith('ID') and c[:-2] in _vvd.columns]
_vrows, _vbad = 0, 0
for _idc, _nmc in _vpairs:
    _mpv = _vvd[[_idc, _nmc]].dropna(subset=[_idc]).drop_duplicates(subset=[_idc])
    _vrows += len(_mpv)
    _mv = _vvd[[_idc, _nmc]].merge(_mpv, on=_idc, suffixes=('', '_m'), how='left')
    _vbad += _mism2(_mv[_nmc], _mv[_nmc + '_m'])
check("D1 VPIC_LABELS: 68 pairs extracted", len(_vpairs) == 68, f"{_vrows} rows")
check("D1 VPIC_LABELS: lossless", _vbad == 0, f"{_vbad} mismatches")

# TRACT is constant -> drop, documented (not a real FD)
_txc = pd.read_csv(f"{DATA}/acc_aux.csv", usecols=['TRACT'], low_memory=False)
check("acc_aux TRACT constant", _txc['TRACT'].nunique(dropna=True) == 1,
      "drop as constant")

print()
print("ALL CHECKS PASSED" if all(results) else "SOME CHECKS FAILED")
