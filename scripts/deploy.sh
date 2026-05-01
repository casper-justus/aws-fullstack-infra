#!/bin/bash
set -e

echo "=== AWS Fullstack Infrastructure Deploy ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Step 1: Initializing Terraform..."
terraform init -upgrade

echo "Step 2: Planning..."
terraform plan -out=tfplan

echo ""
read -p "Apply the plan? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo "Step 3: Applying Terraform plan..."
terraform apply tfplan

echo ""
echo "=== Deployment Complete ==="
echo ""
terraform output
