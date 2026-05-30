#!/usr/bin/env bash
set -euo pipefail

# Bastion Shell v1.0

PROFILE="${1:?Usage: $0 <aws-profile>}"
NAME_TAG="bastion-host-ephemeral"

echo "Looking up EC2 instance with Name tag: $NAME_TAG ..."

INSTANCE_ID=$(aws ec2 describe-instances \
  --profile "$PROFILE" \
  --filters "Name=tag:Name,Values=$NAME_TAG" \
             "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "Error: No running instance found with Name tag '$NAME_TAG'" >&2
  exit 1
fi

echo "Found instance: $INSTANCE_ID"
echo "Starting SSM session..."

aws ssm start-session \
  --target "$INSTANCE_ID" \
  --profile "$PROFILE"
