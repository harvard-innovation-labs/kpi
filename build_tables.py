"""
build_tables.py

Runs the calculated-table SQL scripts in order:
  00_airtable_bookings.sql  -- rebuild airtable_bookings from airtable_raw (current AY)
  01_student_dim.sql        -- rebuild student_dim from salesforce_members_raw
  02_student_events.sql     -- rebuild student_events from oncehub/airtable/eventbrite
  03_kpis.sql               -- KPI queries (read-only, prints results)

Usage:
    python3 build_tables.py --all              # run all steps in order
    python3 build_tables.py --airtable         # only rebuild airtable_bookings
    python3 build_tables.py --dim              # only rebuild student_dim
    python3 build_tables.py --events           # only rebuild student_events
    python3 build_tables.py --kpis             # only run KPI queries
    python3 build_tables.py --dim --events     # rebuild dim + events, skip airtable
    python3 build_tables.py --airtable --events  # rebuild airtable + events, skip dim
"""

import argparse
import configparser
import os
import sys
import psycopg2

SQL_DIR = os.path.join(os.path.dirname(__file__), "sql")


def db_connect():
    config = configparser.ConfigParser()
    config.read(os.path.join(os.path.dirname(__file__), "config.ini"))
    return psycopg2.connect(
        database=config.get("database", "db_name"),
        user=config.get("database", "db_user"),
        password=config.get("database", "db_password"),
        host=config.get("database", "db_host"),
        port=config.get("database", "db_port"),
    )


def split_statements(sql_text):
    """Split a SQL file into individual statements on semicolons,
    skipping empty/comment-only chunks."""
    statements = []
    for chunk in sql_text.split(";"):
        stmt = chunk.strip()
        code_lines = [l for l in stmt.splitlines() if not l.strip().startswith("--") and l.strip()]
        if code_lines:
            statements.append(stmt)
    return statements


def first_code_line(stmt):
    """Return the first non-comment, non-blank line of a statement, for logging."""
    for line in stmt.splitlines():
        if line.strip() and not line.strip().startswith("--"):
            return line.strip()[:80]
    return stmt.strip()[:80]


def run_sql_file(conn, filename, fetch_results=False):
    path = os.path.join(SQL_DIR, filename)
    print(f"\n=== Running {filename} ===")
    with open(path, "r") as f:
        sql_text = f.read()

    statements = split_statements(sql_text)
    cur = conn.cursor()
    results = []
    for i, stmt in enumerate(statements, start=1):
        print(f"  [{i}/{len(statements)}] {first_code_line(stmt)}...")
        try:
            cur.execute(stmt)
            if fetch_results and cur.description:
                colnames = [desc[0] for desc in cur.description]
                rows = cur.fetchall()
                results.append((colnames, rows))
        except psycopg2.Error as e:
            conn.rollback()
            print(f"    ERROR: {e}")
            sys.exit(1)
    conn.commit()
    print(f"  done ({len(statements)} statement(s) committed).")
    return results


def print_kpi_results(results):
    for colnames, rows in results:
        print("\n" + " | ".join(colnames))
        print("-" * 60)
        for row in rows:
            print(" | ".join(str(v) for v in row))


def main():
    parser = argparse.ArgumentParser(
        description="Rebuild i-lab calculated tables and/or run KPI queries.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  python3 build_tables.py --airtable         only rebuild airtable_bookings
  python3 build_tables.py --student_dim      only rebuild student_dim
  python3 build_tables.py --events           only rebuild student_events
  python3 build_tables.py --kpis             only run KPI queries
  python3 build_tables.py --all              full monthly rebuild + KPIs
        """
    )
    parser.add_argument("--all",      action="store_true", help="Run all steps: airtable, dim, events, kpis")
    parser.add_argument("--airtable", action="store_true", help="Rebuild airtable_bookings from airtable_raw (current AY only)")
    parser.add_argument("--student_dim",      action="store_true", help="Rebuild student_dim from salesforce_members_raw")
    parser.add_argument("--events",   action="store_true", help="Rebuild student_events from all 3 sources")
    parser.add_argument("--kpis",     action="store_true", help="Run KPI queries and print results")
    args = parser.parse_args()

    # if no flags given, print help and exit
    if not any([args.all, args.airtable, args.student_dim, args.events, args.kpis]):
        parser.print_help()
        sys.exit(0)

    conn = db_connect()
    print("Connected to database.")

    try:
        if args.all or args.airtable:
            run_sql_file(conn, "00_airtable_bookings.sql")
        if args.all or args.student_dim:
            run_sql_file(conn, "01_student_dim.sql")
        if args.all or args.events:
            run_sql_file(conn, "02_student_events.sql")
        if args.all or args.kpis:
            results = run_sql_file(conn, "03_kpis.sql", fetch_results=True)
            print_kpi_results(results)
    finally:
        conn.close()

    print("\nAll done.")


if __name__ == "__main__":
    main()
