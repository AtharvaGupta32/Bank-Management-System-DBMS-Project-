"""
db.py — Oracle Database Connectivity & Interactive Flow Tracer
Project: Advanced Bank Management System (BACSE202)

Provides three helpers:
  query_all(sql, params, meta)   → SELECT  → returns rows + trace dict
  execute_dml(sql, params, meta) → DML     → returns rowcount + trace dict
  call_proc(name, in_params, out_type, meta) → PROCEDURE → returns output + trace dict

Every response includes a trace dict matching the professor's rubric:
  user_operation | component_type | tables_involved | sql_executed | effect | execution_ms
"""

import os
import time
import datetime
from decimal import Decimal

import oracledb
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Configuration — reads from .env if present, else falls back to defaults
# ---------------------------------------------------------------------------
load_dotenv()

ORACLE_USER     = os.getenv("ORACLE_USER",     "system")
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "Citi$0bank")
ORACLE_DSN      = os.getenv("ORACLE_DSN",      "localhost:1521/xe")

# Use python-oracledb in thin mode (no Oracle Client installation required)
oracledb.defaults.fetch_lobs = False


def _get_connection() -> oracledb.Connection:
    """Return a fresh Oracle connection (thin mode)."""
    return oracledb.connect(
        user=ORACLE_USER,
        password=ORACLE_PASSWORD,
        dsn=ORACLE_DSN
    )


# ---------------------------------------------------------------------------
# Serialisation helpers
# ---------------------------------------------------------------------------

def _serialize(value):
    """Convert Oracle-returned types that JSON cannot handle."""
    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.strftime("%Y-%m-%d")
    if isinstance(value, Decimal):
        return float(value)
    return value


def _serialize_row(row: tuple, columns: list[str]) -> dict:
    """Zip column names with their serialised values into a plain dict."""
    return {col: _serialize(val) for col, val in zip(columns, row)}


# ---------------------------------------------------------------------------
# Trace builder
# ---------------------------------------------------------------------------

def _build_trace(meta: dict, sql: str, effect, elapsed_ms: float) -> dict:
    """
    Construct the professor-mandated execution trace dictionary.

    meta keys used:
      op     – human-readable user operation  (e.g. "View customer overview")
      comp   – component type                 (e.g. "SELECT Query", "PL/SQL Procedure")
      tables – list/str of tables involved    (e.g. ["CUSTOMER", "ACCOUNT"])
    """
    return {
        "user_operation":   meta.get("op",     "Unspecified Operation"),
        "component_type":   meta.get("comp",   "SQL Query"),
        "tables_involved":  meta.get("tables", []),
        "sql_executed":     sql.strip(),
        "effect":           effect,
        "execution_ms":     round(elapsed_ms, 2),
    }


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def query_all(sql: str, params: dict | None = None, meta: dict | None = None) -> dict:
    """
    Execute a SELECT statement and return all rows as a list of dicts.

    Returns:
        {
            "rows":  [...],
            "count": <int>,
            "trace": {...}
        }
    """
    meta   = meta or {}
    params = params or {}
    t0     = time.perf_counter()

    with _get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            columns = [d[0].lower() for d in cur.description]
            rows    = [_serialize_row(r, columns) for r in cur.fetchall()]

    elapsed = (time.perf_counter() - t0) * 1000
    effect  = f"Retrieved {len(rows)} row(s)"

    return {
        "rows":  rows,
        "count": len(rows),
        "trace": _build_trace(meta, sql, effect, elapsed),
    }


def execute_dml(sql: str, params: dict | None = None, meta: dict | None = None) -> dict:
    """
    Execute an INSERT / UPDATE / DELETE statement and commit.

    Returns:
        {
            "success": <bool>,
            "rows_affected": <int>,
            "trace": {...}
        }
    """
    meta   = meta or {}
    params = params or {}
    t0     = time.perf_counter()

    try:
        with _get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                rows_affected = cur.rowcount
            conn.commit()

        elapsed = (time.perf_counter() - t0) * 1000
        effect  = f"DML committed — {rows_affected} row(s) affected"

        return {
            "success": True,
            "rows_affected": rows_affected,
            "trace": _build_trace(meta, sql, effect, elapsed),
        }
    except oracledb.DatabaseError as e:
        elapsed = (time.perf_counter() - t0) * 1000
        err_msg = str(e).strip()
        effect  = f"DML Failed: {err_msg}"

        return {
            "success": False,
            "error": err_msg,
            "rows_affected": 0,
            "trace": _build_trace(meta, sql, effect, elapsed),
        }


def call_proc(
    proc_name:  str,
    in_params:  list,
    out_type,             # e.g. oracledb.STRING, oracledb.NUMBER
    meta:       dict | None = None,
) -> dict:
    """
    Call a PL/SQL stored procedure that has exactly one OUT VARCHAR2 parameter
    appended after the IN parameters.

    Returns:
        {
            "output": <out_param_value>,
            "trace":  {...}
        }
    """
    meta  = meta or {}
    t0    = time.perf_counter()

    # Build the anonymous-block call so we can pass a typed OUT variable
    placeholders = ", ".join([f":p{i}" for i in range(len(in_params))])
    call_sql = (
        f"BEGIN {proc_name}({placeholders}, :out_msg); END;"
        if in_params
        else f"BEGIN {proc_name}(:out_msg); END;"
    )

    with _get_connection() as conn:
        with conn.cursor() as cur:
            out_var = cur.var(out_type)
            bind    = {f"p{i}": v for i, v in enumerate(in_params)}
            bind["out_msg"] = out_var
            cur.execute(call_sql, bind)
        conn.commit()
        output = out_var.getvalue()

    elapsed = (time.perf_counter() - t0) * 1000
    effect  = f"Procedure {proc_name} executed — output: {output}"

    return {
        "output": output,
        "trace":  _build_trace(meta, call_sql, effect, elapsed),
    }
