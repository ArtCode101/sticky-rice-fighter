#!/usr/bin/env python3
"""PostgreSQL access tool.

This is the ONLY sanctioned way for an agent to reach PostgreSQL. Agents never
connect to the database directly: they run SQL through this tool.

On the LOCAL workspace database the agent has full privileges: SELECT, INSERT,
UPDATE, DELETE, DDL and mock data generation for testing are all allowed. The tool
refuses to connect to anything that is not a local host, so that latitude cannot
reach a dev, sys or production database.

Usage:
    python db_tool.py --sql "SELECT * FROM users LIMIT 5"
    python db_tool.py --file seed.sql
    echo "SELECT 1" | python db_tool.py --stdin

Connection settings come from the environment, which mirrors the workspace's
config repository:
    POSTGRES_HOST      (default: localhost)
    POSTGRES_PORT      (default: 5432)
    POSTGRES_DB        (required)
    POSTGRES_USER      (required)
    POSTGRES_PASSWORD  (required)

Exit codes:
    0 - statements executed
    1 - usage or execution error
    2 - refused: the target host is not local
"""

import argparse
import os
import sys

import psycopg

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1", "0.0.0.0"}


def require_local_host(host):
    """Refuse any host that is not the local machine.

    Full read/write privileges are granted for the local workspace database only.
    This check is what keeps that grant local.
    """
    if host not in LOCAL_HOSTS:
        sys.stderr.write(
            "refused: POSTGRES_HOST is '%s', which is not a local host.\n"
            "This tool operates on the local workspace database only.\n" % host
        )
        sys.exit(2)


def read_statements(args):
    if args.sql:
        return args.sql
    if args.file:
        with open(args.file, "r", encoding="utf-8") as handle:
            return handle.read()
    if args.stdin:
        return sys.stdin.read()
    sys.stderr.write("nothing to run: pass --sql, --file or --stdin\n")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Run SQL against the local workspace database.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--sql", help="SQL to execute")
    group.add_argument("--file", help="path to a .sql file to execute")
    group.add_argument("--stdin", action="store_true", help="read SQL from stdin")
    args = parser.parse_args()

    host = os.environ.get("POSTGRES_HOST", "localhost")
    require_local_host(host)

    missing = [k for k in ("POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD") if not os.environ.get(k)]
    if missing:
        sys.stderr.write("missing environment variables: %s\n" % ", ".join(missing))
        sys.exit(1)

    statements = read_statements(args)

    conninfo = "host=%s port=%s dbname=%s user=%s password=%s" % (
        host,
        os.environ.get("POSTGRES_PORT", "5432"),
        os.environ["POSTGRES_DB"],
        os.environ["POSTGRES_USER"],
        os.environ["POSTGRES_PASSWORD"],
    )

    try:
        with psycopg.connect(conninfo, autocommit=True) as conn:
            with conn.cursor() as cur:
                cur.execute(statements)
                # Walk every result set the batch produced.
                while True:
                    if cur.description is not None:
                        columns = [d[0] for d in cur.description]
                        print(" | ".join(columns))
                        print("-+-".join("-" * len(c) for c in columns))
                        for row in cur.fetchall():
                            print(" | ".join("NULL" if v is None else str(v) for v in row))
                    elif cur.rowcount is not None and cur.rowcount >= 0:
                        print("%s rows affected" % cur.rowcount)
                    else:
                        # DDL and other statements that report no row count.
                        print("statement executed")
                    if not cur.nextset():
                        break
    except Exception as exc:  # noqa: BLE001 - surface the real driver error
        sys.stderr.write("error: %s\n" % exc)
        sys.exit(1)


if __name__ == "__main__":
    main()
