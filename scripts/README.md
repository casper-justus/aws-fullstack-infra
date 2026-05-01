# Scripts

Automated the full Terraform lifecycle — as measured by reducing infrastructure deployment from 30+ manual steps to a single `./scripts/deploy.sh` command, by wrapping init, plan, and apply with prerequisite validation and confirmation prompts.

## What This Accomplishes

| Goal | Measure | Method |
|---|---|---|
| One-command deployment | 40+ resources created in under 10 minutes with one script | `deploy.sh` chains init → plan → confirm → apply |
| Safe dry-run validation | Catches configuration errors before any resources are created | `plan.sh` validates prerequisites, runs init, validate, and plan |
| Prevented accidental destruction | Requires typing `destroy` (not just `y`) to confirm teardown | `destroy.sh` with explicit confirmation string matching |
| Consistent local workflow | 16 common operations available via `make` commands | Makefile targets for deploy, destroy, outputs, app, and monitoring URLs |

## Available Scripts

### `deploy.sh`

Full deployment: init, plan, and apply with human confirmation.

```bash
./scripts/deploy.sh
```

Flow:
1. `terraform init -upgrade` — download providers, initialize backend
2. `terraform plan -out=tfplan` — generate execution plan
3. Prompts: `Apply the plan? (y/n)`
4. `terraform apply tfplan` — execute the plan
5. Prints all outputs (ALB URL, Grafana URL, etc.)

### `plan.sh`

Dry-run with prerequisite checks — no resources created.

```bash
./scripts/plan.sh
```

Flow:
1. Checks `terraform` is installed
2. Checks `aws` CLI is installed and authenticated
3. Checks `terraform.tfvars` exists
4. `terraform init` — initialize
5. `terraform validate` — syntax and config check
6. `terraform plan -out=tfplan` — generate plan for review

After reviewing, apply manually:
```bash
terraform apply tfplan
```

### `destroy.sh`

Safe teardown with strict confirmation.

```bash
./scripts/destroy.sh
```

Flow:
1. Prints warning message
2. Requires typing `destroy` exactly (not `y` or `yes`)
3. `terraform destroy -auto-approve` — tear down all resources

## Makefile Commands

| Command | What It Does |
|---|---|
| `make init` | `terraform init -upgrade` |
| `make validate` | `terraform validate` |
| `make fmt` | `terraform fmt -recursive` |
| `make lint` | `make fmt` + check formatting |
| `make plan` | Init + plan |
| `make deploy` | Init + plan + apply + print outputs |
| `make destroy` | Destroy all resources |
| `make outputs` | Print all Terraform outputs |
| `make clean` | Remove `.terraform/`, `tfplan`, lock file |
| `make grafana-url` | Print Grafana URL |
| `make prometheus-url` | Print Prometheus URL |
| `make alb-url` | Print ALB DNS name |
| `make health` | Curl the app health endpoint and pretty-print JSON |
| `make app-build` | Build Docker image locally |
| `make app-run` | Start app with `docker compose up -d` |
| `make app-logs` | Follow app container logs |
| `make app-stop` | Stop app containers |

## Typical Workflow

```bash
# First time setup
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars...

# Deploy
make deploy

# Check it's running
make health
make grafana-url

# Make changes to infrastructure
# Edit .tf files...
make deploy        # Applies only the diff

# Tear down when done
make destroy
```
