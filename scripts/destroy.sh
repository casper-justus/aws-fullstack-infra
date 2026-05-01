#!/bin/bash
set -e

echo "=== AWS Fullstack Infrastructure Destroy ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "WARNING: This will destroy all infrastructure resources!"
echo ""
read -r -p "Are you sure? Type 'destroy' to confirm: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "=== Infrastructure Destroyed ==="
