#!/usr/bin/env python3
"""list_ours_sqs.py — lista colas aws-emulator-lab-* (URLs) para make clean."""
import os, sys
from urllib.parse import urlparse
import boto3

ENDPOINT = os.environ.get("AWS_ENDPOINT_URL", "")
PORT = urlparse(ENDPOINT).port or 9297
EMU = os.path.expanduser(f"~/.aws/emulator/{PORT}")
creds = dict(
    line.strip().split("=", 1)
    for line in open(os.path.join(EMU, "emulator_credentials"))
    if "=" in line and not line.startswith("#")
)
sqs = boto3.client("sqs", endpoint_url=ENDPOINT,
                   aws_access_key_id=creds["aws_access_key_id"],
                   aws_secret_access_key=creds["aws_secret_access_key"],
                   region_name="us-east-1")
paginator = sqs.get_paginator("list_queues")
for page in paginator.paginate():
    for q in page.get("QueueUrls", []):
        if "/aws-emulator-lab-" in q:
            print(q)
