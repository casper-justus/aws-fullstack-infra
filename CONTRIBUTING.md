# Contributing

Thank you for your interest in contributing! Contributions are welcome in the form of bug reports, Terraform module improvements, Docker config changes, and documentation fixes.

## Getting Started

1. **Fork** the repository and create a new branch from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. Make your changes.
3. Run `terraform validate` and `terraform plan` to ensure no breaking changes.
4. Open a **Pull Request** against `main` with a clear description of what changed and why.

## What You Can Contribute

- ☁️ **Terraform modules** — new AWS resources, improved IAM policies, VPC changes
- 🐳 **Docker improvements** — better container configs, healthchecks, multi-stage builds
- 📊 **Monitoring** — new Prometheus metrics, Grafana dashboards, alerting rules
- 📚 **Documentation** — architecture diagrams, deployment guides, cost breakdowns

## Pull Request Guidelines

- Keep PRs focused — one change per PR
- Use clear commit messages (e.g. `feat: add S3 bucket versioning`)
- Never commit AWS credentials or secrets
- Run `terraform fmt` before submitting

## Reporting Issues

When reporting a bug, please include:
- The Terraform error or AWS error message
- The resource or module affected
- Your Terraform version (`terraform version`)

## Code of Conduct

Be respectful and constructive. Everyone is welcome regardless of experience level.
