"""FARS 2024 dashboard: a Flask app that runs the team's SQL live against MySQL.

Run from the repository root:
    .venv/bin/python dashboard/app.py          # then open http://127.0.0.1:5000

Connection settings come from the repo's .env file (see .env.example).
Every chart calls /api/chart/<id>, which runs that chart's SQL (charts.py)
with the current filters passed as query parameters and returns the rows,
the exact SQL that ran, and how long it took.
"""

import datetime
import decimal
import os
import re
import textwrap
import time
from pathlib import Path

import pymysql
from dotenv import load_dotenv
from flask import Flask, abort, jsonify, render_template, request, send_file

from charts import CHARTS, SOURCES
from portfolio import MEMBERS, PORTFOLIO

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql"
QUERY_DIR = SQL_DIR / "queries"
AUTHORS = {q["file"]: q["member"] for q in PORTFOLIO}
AUTHORS.update({"views.sql": "Ryan", "indexes.sql": "Ryan"})
VIEWS_SQL = ROOT / "sql" / "schema" / "views.sql"
EER_IMAGE = ROOT / "notebooks" / "saida" / "Final_EER.png"

load_dotenv(ROOT / ".env")
app = Flask(__name__)


# ---------------------------------------------------------------- database
def connect():
    return pymysql.connect(
        host=os.getenv("MYSQL_HOST", "localhost"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("MYSQL_USER", "root"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("MYSQL_DB", "fars"),
        charset="utf8mb4",
        autocommit=True,
    )


def to_json(value):
    if isinstance(value, decimal.Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.isoformat()
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return value


def run(sql, params=None, cursor=None):
    """Run one statement; return (columns, rows, milliseconds)."""
    def _go(cur):
        start = time.perf_counter()
        cur.execute(sql, params)
        cols = [d[0] for d in cur.description] if cur.description else []
        rows = [[to_json(v) for v in row] for row in cur.fetchall()] if cur.description else []
        return cols, rows, round((time.perf_counter() - start) * 1000, 1)

    if cursor is not None:
        return _go(cursor)
    with connect() as conn, conn.cursor() as cur:
        return _go(cur)


def split_statements(text):
    """Split a .sql file into statements (full-line comments removed, USE skipped)."""
    lines = [ln for ln in text.splitlines() if not ln.strip().startswith(("--", "#"))]
    out = []
    for stmt in re.split(r";\s*(?:\n|$)", "\n".join(lines)):
        stmt = stmt.strip()
        if stmt and not re.match(r"(?i)^use\s+\w+$", stmt):
            out.append(stmt)
    return out


def ensure_view():
    """The dashboard reads v_crash_facts; create it from views.sql if it's missing."""
    with connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM information_schema.views "
                    "WHERE table_schema = DATABASE() AND table_name = 'v_crash_facts'")
        if cur.fetchone()[0] == 0:
            for stmt in split_statements(VIEWS_SQL.read_text()):
                cur.execute(stmt)


# ---------------------------------------------------------------- filters
def filter_clause(include_state=True, alias="a"):
    args = request.args
    m1 = min(max(args.get("m1", 1, type=int), 1), 12)
    m2 = min(max(args.get("m2", 12, type=int), 1), 12)
    m1, m2 = min(m1, m2), max(m1, m2)
    parts = [f"{alias}.MONTH BETWEEN %(m1)s AND %(m2)s"]
    params = {"m1": m1, "m2": m2}
    state = args.get("state", type=int)
    if include_state and state:
        parts.append(f"{alias}.STATE = %(state)s")
        params["state"] = state
    area = args.get("area", type=int)
    if area in (1, 2):
        parts.append(f"{alias}.RUR_URB = %(area)s")
        params["area"] = area
    return " AND ".join(parts), params


def readable_sql(sql, params):
    """The SQL as it ran, with parameter values shown inline (for display only)."""
    def sub(m):
        v = params[m.group(1)]
        return str(v) if isinstance(v, (int, float)) else "'" + str(v).replace("'", "''") + "'"
    return re.sub(r"%\((\w+)\)s", sub, textwrap.dedent(sql).strip())


# ---------------------------------------------------------------- pages
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/eer.png")
def eer():
    if not EER_IMAGE.exists():
        abort(404)
    return send_file(EER_IMAGE)


# ---------------------------------------------------------------- api
@app.route("/api/meta")
def meta():
    cols, rows, ms = run("""
        SELECT a.STATE, st.label, COUNT(*) AS crashes
        FROM accident a
        JOIN code_labels st ON st.`column` = 'STATE' AND st.code = CAST(a.STATE AS CHAR)
        GROUP BY a.STATE, st.label
        ORDER BY st.label""")
    with connect() as conn:
        version = conn.get_server_info()
    return jsonify(states=[{"code": r[0], "name": r[1], "crashes": r[2]} for r in rows],
                   database=os.getenv("MYSQL_DB", "fars"), version=version)


@app.route("/api/chart/<cid>")
def chart(cid):
    spec = CHARTS.get(cid)
    if spec is None:
        abort(404)
    clause, params = filter_clause(include_state=spec.get("state_filter", True))
    sql = spec["sql"].format(f=clause)
    try:
        cols, rows, ms = run(sql, params)
    except pymysql.MySQLError as exc:
        return jsonify(error=str(exc), sql=readable_sql(sql, params)), 500
    files, note = SOURCES[cid]
    sources = [{"path": p, "name": Path(p).name, "author": AUTHORS.get(Path(p).name, "")} for p in files]
    return jsonify(id=cid, file=spec["file"], member=spec["member"], sources=sources, note=note,
                   columns=cols, rows=rows, ms=ms, sql=readable_sql(sql, params))


@app.route("/api/source")
def source():
    """The saved .sql file behind a chart, exactly as it is in the repo."""
    path = (SQL_DIR / request.args.get("path", "")).resolve()
    if path.suffix != ".sql" or path.parent not in (QUERY_DIR, SQL_DIR / "schema") or not path.exists():
        abort(404)
    return jsonify(path=str(path.relative_to(ROOT)), author=AUTHORS.get(path.name, ""), text=path.read_text())


@app.route("/api/queries")
def queries():
    on_disk = {p.name for p in QUERY_DIR.glob("*.sql")}
    items = [dict(q, exists=q["file"] in on_disk) for q in PORTFOLIO]
    known = {q["file"] for q in PORTFOLIO}
    extra = sorted(on_disk - known)  # saved queries nobody has described yet
    items += [{"file": f, "member": "Unassigned", "level": "", "question": f, "technique": "",
               "insight": "", "exists": True} for f in extra]
    return jsonify(members=MEMBERS, queries=items)


@app.route("/api/queries/<name>")
def query_run(name):
    path = QUERY_DIR / name
    if path.suffix != ".sql" or path.parent != QUERY_DIR or not path.exists():
        abort(404)
    text = path.read_text()
    results = []
    try:
        with connect() as conn, conn.cursor() as cur:
            for stmt in split_statements(text):
                cols, rows, ms = run(stmt, cursor=cur)
                if cols:
                    results.append({"columns": cols, "rows": rows[:200],
                                    "total_rows": len(rows), "ms": ms})
    except pymysql.MySQLError as exc:
        return jsonify(file=name, source=text, results=results, error=str(exc))
    return jsonify(file=name, source=text, results=results)


_schema_cache = {}


@app.route("/api/schema")
def schema():
    if not _schema_cache:
        with connect() as conn, conn.cursor() as cur:
            _, tables, _ = run("""
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'
                ORDER BY table_name""", cursor=cur)
            _, pks, _ = run("""
                SELECT table_name, GROUP_CONCAT(column_name ORDER BY ordinal_position)
                FROM information_schema.key_column_usage
                WHERE table_schema = DATABASE() AND constraint_name = 'PRIMARY'
                GROUP BY table_name""", cursor=cur)
            _, fks, _ = run("""
                SELECT table_name, constraint_name,
                       GROUP_CONCAT(column_name ORDER BY ordinal_position),
                       MAX(referenced_table_name),
                       GROUP_CONCAT(referenced_column_name ORDER BY ordinal_position)
                FROM information_schema.key_column_usage
                WHERE table_schema = DATABASE() AND referenced_table_name IS NOT NULL
                GROUP BY table_name, constraint_name""", cursor=cur)
            _, cols, _ = run("""
                SELECT table_name, COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE() GROUP BY table_name""", cursor=cur)
            pk_map = {t: c for t, c in pks}
            col_map = {t: n for t, n in cols}
            fk_map = {}
            for t, _name, c, rt, rc in fks:
                fk_map.setdefault(t, []).append(f"({c}) → {rt}({rc})")
            out = []
            for (t,) in tables:
                cur.execute(f"SELECT COUNT(*) FROM `{t}`")
                out.append({"table": t, "rows": cur.fetchone()[0], "columns": col_map.get(t, 0),
                            "pk": pk_map.get(t, ""), "fks": fk_map.get(t, [])})
            _schema_cache["tables"] = out
            _schema_cache["fk_count"] = len(fks)
    tables = _schema_cache["tables"]
    return jsonify(tables=tables, table_count=len(tables),
                   pk_count=sum(1 for t in tables if t["pk"]),
                   fk_count=_schema_cache["fk_count"],
                   total_rows=sum(t["rows"] for t in tables))


if __name__ == "__main__":
    ensure_view()
    app.run(host="127.0.0.1", port=int(os.getenv("DASHBOARD_PORT", "5000")), debug=False)
