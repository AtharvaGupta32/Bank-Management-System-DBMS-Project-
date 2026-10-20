"""
init_db.py — One-Click Oracle Database Initialiser
Project: Advanced Bank Management System (BACSE202)

Usage:
    python init_db.py

Reads and executes, in order:
    1. sql/01_schema_ddl.sql  — drops + creates all 14 tables
    2. sql/02_seed_data.sql   — inserts realistic Indian banking seed data
    3. sql/03_plsql_blocks.sql — creates triggers, functions, procedures, cursor

Splitting strategy:
  • PL/SQL blocks (TRIGGER / FUNCTION / PROCEDURE / anonymous BEGIN…END / 
    DECLARE…BEGIN…END) are delimited by a lone '/' on its own line.
  • Plain SQL statements are delimited by ';'.
  • SET / SAVEPOINT / ROLLBACK lines and SQL*Plus meta-commands are skipped.
"""

import os
import re
import sys
import time

import oracledb
from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
load_dotenv()
USER     = os.getenv("ORACLE_USER",     "system")
PASSWORD = os.getenv("ORACLE_PASSWORD", "Citi$0bank")
DSN      = os.getenv("ORACLE_DSN",      "localhost:1521/xe")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SQL_DIR  = os.path.join(BASE_DIR, "sql")

SQL_FILES = [
    ("01_schema_ddl.sql",   "Schema DDL — Drop + Create 14 Tables"),
    ("02_seed_data.sql",    "Seed Data — 149 INSERTs across 14 Tables"),
    ("03_plsql_blocks.sql", "PL/SQL Objects — Triggers, Functions, Procedures, Cursor"),
]

# SQL*Plus meta-commands to skip entirely
SKIP_PREFIXES = (
    "set serveroutput", "set echo", "set feedback", "set heading",
    "set linesize", "set pagesize", "set verify", "set termout",
    "spool", "exit", "quit", "show", "@",
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ANSI_GREEN  = "\033[92m"
ANSI_YELLOW = "\033[93m"
ANSI_RED    = "\033[91m"
ANSI_RESET  = "\033[0m"
ANSI_BOLD   = "\033[1m"
ANSI_CYAN   = "\033[96m"

def ok(msg: str):    print(f"  {ANSI_GREEN}[OK]{ANSI_RESET}  {msg}")
def warn(msg: str):  print(f"  {ANSI_YELLOW}[!]{ANSI_RESET}   {msg}")
def fail(msg: str):  print(f"  {ANSI_RED}[X]{ANSI_RESET}   {msg}")
def info(msg: str):  print(f"  {ANSI_CYAN}->{ANSI_RESET}   {msg}")
def header(msg: str):print(f"\n{ANSI_BOLD}{msg}{ANSI_RESET}")


def _is_plsql_block(text: str) -> bool:
    """Detect PL/SQL blocks that must be submitted as a unit."""
    upper = text.strip().upper()
    return (
        upper.startswith("CREATE OR REPLACE")
        or upper.startswith("DECLARE")
        or upper.startswith("BEGIN")
        or re.match(r"^CREATE\s+(OR\s+REPLACE\s+)?(TRIGGER|FUNCTION|PROCEDURE|PACKAGE)", upper) is not None
    )


def split_sql_file(filepath: str) -> list[tuple[str, bool]]:
    """
    Parse a .sql file and return a list of (statement, is_plsql) tuples.

    Rules:
      1. A lone '/' on its own line terminates the current PL/SQL block.
      2. A ';' at the end of a non-PL/SQL line terminates a plain SQL stmt.
      3. Lines beginning with SQL*Plus meta-commands are discarded.
      4. Pure comment lines are discarded when they form isolated segments.
    """
    with open(filepath, encoding="utf-8") as fh:
        raw = fh.read()

    statements: list[tuple[str, bool]] = []
    current:    list[str]              = []
    in_plsql                           = False

    for line in raw.splitlines():
        stripped = line.strip()

        # Skip blank lines and pure comment lines when buffer is empty
        if not stripped or stripped.startswith("--"):
            if current:
                current.append(line)
            continue

        # Skip SQL*Plus meta-commands (only outside PL/SQL)
        if not in_plsql and any(stripped.lower().startswith(p) for p in SKIP_PREFIXES):
            continue

        # Lone '/' → end of a PL/SQL block
        if stripped == "/":
            if current:
                block = "\n".join(current).strip()
                if block:
                    statements.append((block, True))
                current   = []
                in_plsql  = False
            continue

        current.append(line)

        # Detect start of PL/SQL
        if not in_plsql and _is_plsql_block("\n".join(current)):
            in_plsql = True

        # Plain SQL terminated by ';' (and NOT inside a PL/SQL block)
        if not in_plsql:
            line_code = re.sub(r"--.*$", "", stripped).rstrip()
            if line_code.endswith(";"):
                last_line = current.pop()
                semi_idx = last_line.rfind(";")
                if semi_idx != -1:
                    last_line = last_line[:semi_idx]
                if last_line.strip():
                    current.append(last_line)
                block = "\n".join(current).strip()
                # Remove any leftover trailing semicolon
                block = re.sub(r";\s*$", "", block).strip()
                if block and not block.lstrip().startswith("--"):
                    statements.append((block, False))
                current = []

    # Flush any remaining
    if current:
        block = "\n".join(current).strip()
        if block:
            statements.append((block, in_plsql))

    return statements


# ---------------------------------------------------------------------------
# Friendly label extraction for progress messages
# ---------------------------------------------------------------------------

def _label_for(stmt: str, is_plsql: bool) -> str:
    upper = stmt.strip().upper()

    # PL/SQL objects
    m = re.match(
        r"CREATE\s+OR\s+REPLACE\s+(TRIGGER|FUNCTION|PROCEDURE)\s+(\w+)",
        upper
    )
    if m:
        kind, name = m.group(1).capitalize(), m.group(2)
        return f"{kind}: {name}"

    if upper.startswith("BEGIN") or upper.startswith("DECLARE"):
        first_line = stmt.strip().splitlines()[0][:60]
        return f"Anonymous Block: {first_line}…"

    # Plain SQL
    m2 = re.match(r"(CREATE\s+TABLE|DROP\s+TABLE|INSERT\s+INTO|UPDATE|DELETE\s+FROM|DELETE)\s+(\w+)", upper)
    if m2:
        op, tbl = m2.group(1).replace("  ", " "), m2.group(2)
        return f"{op}: {tbl}"

    return stmt.strip()[:60] + "…"


# ---------------------------------------------------------------------------
# Execution engine
# ---------------------------------------------------------------------------

def execute_file(conn: oracledb.Connection, filepath: str, label: str):
    header(f"[{label}]  {os.path.basename(filepath)}")
    statements = split_sql_file(filepath)
    info(f"Parsed {len(statements)} statement(s) from file.")

    ok_count = skip_count = err_count = 0

    with conn.cursor() as cur:
        for stmt, is_plsql in statements:
            lbl = _label_for(stmt, is_plsql)
            try:
                cur.execute(stmt)
                if not is_plsql:
                    # Commit plain DML immediately; DDL auto-commits in Oracle
                    conn.commit()
                ok_count += 1
                ok(lbl)
            except oracledb.DatabaseError as e:
                error_obj, = e.args
                # ORA-00942: table does not exist (safe to skip in drop blocks)
                if error_obj.code == 942:
                    skip_count += 1
                    warn(f"Skipped (already absent): {lbl}")
                # ORA-00955: name already used (idempotent object creation)
                elif error_obj.code == 955:
                    skip_count += 1
                    warn(f"Skipped (already exists): {lbl}")
                else:
                    err_count += 1
                    fail(f"{lbl}\n      Oracle Error {error_obj.code}: {error_obj.message.strip()}")

    conn.commit()
    print(
        f"\n  Summary: {ANSI_GREEN}{ok_count} ok{ANSI_RESET}  "
        f"{ANSI_YELLOW}{skip_count} skipped{ANSI_RESET}  "
        f"{ANSI_RED}{err_count} errors{ANSI_RESET}"
    )
    return err_count


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print(f"\n{'='*65}")
    print(f"  {ANSI_BOLD}Nova Bank - Advanced Bank Management System (BACSE202){ANSI_RESET}")
    print(f"  One-Click Oracle Database Initialiser")
    print(f"{'='*65}")
    print(f"  Connecting to Oracle  ->  {DSN}  as  {USER}")

    t_start = time.perf_counter()

    try:
        conn = oracledb.connect(user=USER, password=PASSWORD, dsn=DSN)
        ok("Connected successfully.")
    except oracledb.DatabaseError as e:
        fail(f"Connection failed: {e}")
        sys.exit(1)

    total_errors = 0
    for filename, label in SQL_FILES:
        path = os.path.join(SQL_DIR, filename)
        if not os.path.exists(path):
            fail(f"File not found: {path}")
            sys.exit(1)
        total_errors += execute_file(conn, path, label)

    conn.close()
    elapsed = time.perf_counter() - t_start

    print(f"\n{'='*65}")
    if total_errors == 0:
        print(f"  {ANSI_GREEN}{ANSI_BOLD}[OK]  Database initialisation COMPLETE in {elapsed:.2f}s{ANSI_RESET}")
        print(f"  All 14 tables, seed data, 2 triggers, 2 functions,")
        print(f"  2 procedures, and 1 cursor procedure are ready.")
    else:
        print(f"  {ANSI_RED}{ANSI_BOLD}[X]   Completed with {total_errors} error(s). Review output above.{ANSI_RESET}")
    print(f"{'='*65}\n")
    sys.exit(0 if total_errors == 0 else 1)


if __name__ == "__main__":
    main()
