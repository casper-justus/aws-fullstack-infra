#!/bin/bash
set -e

echo "=== AWS Fullstack Infrastructure Deployment ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Step 1: Checking prerequisites..."
if ! command -v terraform &> /dev/null; then
    echo "ERROR: terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "ERROR: awscli is not installed"
    exit 1
fi

echo "Step 2: Verifying AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "ERROR: AWS credentials not configured. Run 'aws configure' first."
    exit 1
}

echo "Step 3: Checking terraform.tfvars..."
if [ ! -f "terraform.tfvars" ]; then
    echo "ERROR: terraform.tfvars not found!"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    exit 1
fi

echo "Step 4: Initializing Terraform..."
terraform init

echo "Step 5: Validating Terraform configuration..."
terraform validate

echo "Step 6: Planning Terraform deployment..."
terraform plan -out=tfplan

echo ""
echo "=== Terraform plan created ==="
echo "Run 'terraform apply tfplan' to deploy the infrastructure."
echo ""
echo "Or run './scripts/deploy.sh' to plan and apply in one step."
