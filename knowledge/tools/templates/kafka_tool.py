#!/usr/bin/env python3
"""Kafka access tool.

This is the ONLY sanctioned way for an agent to reach Kafka. Agents never produce
or consume directly: they go through this tool.

Full produce and consume privileges on the LOCAL workspace Kafka. The tool refuses
any bootstrap server that is not local.

Usage:
    python kafka_tool.py produce <topic> --message '{"id":1}'
    python kafka_tool.py produce <topic> --file messages.ndjson
    python kafka_tool.py consume <topic> --max 10 --timeout 5
    python kafka_tool.py topics

Connection settings come from the environment:
    KAFKA_BOOTSTRAP_SERVERS  (default: localhost:9094)
    KAFKA_GROUP_ID           (default: local-tool)

Exit codes:
    0 - command executed
    1 - usage or execution error
    2 - refused: the bootstrap server is not local
"""

import argparse
import os
import sys

from confluent_kafka import Consumer, Producer
from confluent_kafka.admin import AdminClient

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1", "0.0.0.0"}


def require_local_servers(servers):
    """Every bootstrap server must be on the local machine."""
    for entry in servers.split(","):
        host = entry.strip().rsplit(":", 1)[0]
        if host not in LOCAL_HOSTS:
            sys.stderr.write(
                "refused: KAFKA_BOOTSTRAP_SERVERS contains '%s', which is not a local host.\n"
                "This tool operates on the local workspace Kafka only.\n" % host
            )
            sys.exit(2)


def do_produce(servers, args):
    producer = Producer({"bootstrap.servers": servers})

    if args.message:
        messages = [args.message]
    elif args.file:
        with open(args.file, "r", encoding="utf-8") as handle:
            messages = [line for line in (raw.strip() for raw in handle) if line]
    else:
        sys.stderr.write("nothing to produce: pass --message or --file\n")
        sys.exit(1)

    for message in messages:
        producer.produce(args.topic, value=message.encode("utf-8"), key=args.key)
    producer.flush()
    print("%s messages produced to %s" % (len(messages), args.topic))


def do_consume(servers, args):
    consumer = Consumer(
        {
            "bootstrap.servers": servers,
            "group.id": os.environ.get("KAFKA_GROUP_ID", "local-tool"),
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )
    consumer.subscribe([args.topic])

    seen = 0
    try:
        while seen < args.max:
            message = consumer.poll(timeout=args.timeout)
            if message is None:
                break
            if message.error():
                sys.stderr.write("error: %s\n" % message.error())
                break
            value = message.value()
            print(value.decode("utf-8") if value is not None else "NULL")
            seen += 1
    finally:
        consumer.close()
    print("%s messages consumed from %s" % (seen, args.topic), file=sys.stderr)


def do_topics(servers):
    admin = AdminClient({"bootstrap.servers": servers})
    metadata = admin.list_topics(timeout=10)
    for name in sorted(metadata.topics):
        print(name)


def main():
    parser = argparse.ArgumentParser(description="Produce to and consume from the local workspace Kafka.")
    sub = parser.add_subparsers(dest="action", required=True)

    p_produce = sub.add_parser("produce")
    p_produce.add_argument("topic")
    p_produce.add_argument("--message", help="a single message value")
    p_produce.add_argument("--file", help="newline-delimited file, one message per line")
    p_produce.add_argument("--key", default=None, help="optional message key")

    p_consume = sub.add_parser("consume")
    p_consume.add_argument("topic")
    p_consume.add_argument("--max", type=int, default=10, help="stop after this many messages")
    p_consume.add_argument("--timeout", type=float, default=5.0, help="poll timeout in seconds")

    sub.add_parser("topics")

    args = parser.parse_args()

    servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9094")
    require_local_servers(servers)

    try:
        if args.action == "produce":
            do_produce(servers, args)
        elif args.action == "consume":
            do_consume(servers, args)
        elif args.action == "topics":
            do_topics(servers)
    except Exception as exc:  # noqa: BLE001 - surface the real client error
        sys.stderr.write("error: %s\n" % exc)
        sys.exit(1)


if __name__ == "__main__":
    main()
