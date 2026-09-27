#!/usr/bin/env python3
"""Redis access tool.

This is the ONLY sanctioned way for an agent to reach Redis. Agents never connect
directly: they read and write through this tool.

Full read and write privileges on the LOCAL workspace Redis. The tool refuses any
host that is not local.

Usage:
    python redis_tool.py get <key>
    python redis_tool.py set <key> <value> [--ttl 60]
    python redis_tool.py delete <key>
    python redis_tool.py keys "prefix:*"
    python redis_tool.py command PING
    python redis_tool.py command HSET myhash field value

Connection settings come from the environment:
    REDIS_HOST      (default: localhost)
    REDIS_PORT      (default: 6379)
    REDIS_PASSWORD  (optional)
    REDIS_DB        (default: 0)

Exit codes:
    0 - command executed
    1 - usage or execution error
    2 - refused: the target host is not local
"""

import argparse
import os
import sys

import redis

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1", "0.0.0.0"}


def require_local_host(host):
    if host not in LOCAL_HOSTS:
        sys.stderr.write(
            "refused: REDIS_HOST is '%s', which is not a local host.\n"
            "This tool operates on the local workspace Redis only.\n" % host
        )
        sys.exit(2)


def main():
    parser = argparse.ArgumentParser(description="Read and write the local workspace Redis.")
    sub = parser.add_subparsers(dest="action", required=True)

    p_get = sub.add_parser("get")
    p_get.add_argument("key")

    p_set = sub.add_parser("set")
    p_set.add_argument("key")
    p_set.add_argument("value")
    p_set.add_argument("--ttl", type=int, default=None, help="expiry in seconds")

    p_del = sub.add_parser("delete")
    p_del.add_argument("key")

    p_keys = sub.add_parser("keys")
    p_keys.add_argument("pattern")

    p_cmd = sub.add_parser("command", help="run an arbitrary Redis command")
    p_cmd.add_argument("argv", nargs=argparse.REMAINDER)

    args = parser.parse_args()

    host = os.environ.get("REDIS_HOST", "localhost")
    require_local_host(host)

    client = redis.Redis(
        host=host,
        port=int(os.environ.get("REDIS_PORT", "6379")),
        password=os.environ.get("REDIS_PASSWORD") or None,
        db=int(os.environ.get("REDIS_DB", "0")),
        decode_responses=True,
    )

    try:
        if args.action == "get":
            value = client.get(args.key)
            print("NULL" if value is None else value)
        elif args.action == "set":
            client.set(args.key, args.value, ex=args.ttl)
            print("OK")
        elif args.action == "delete":
            print("%s keys deleted" % client.delete(args.key))
        elif args.action == "keys":
            for key in client.keys(args.pattern):
                print(key)
        elif args.action == "command":
            if not args.argv:
                sys.stderr.write("command needs at least a command name\n")
                sys.exit(1)
            print(client.execute_command(*args.argv))
    except Exception as exc:  # noqa: BLE001 - surface the real client error
        sys.stderr.write("error: %s\n" % exc)
        sys.exit(1)


if __name__ == "__main__":
    main()
