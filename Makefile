.PHONY: init plan deploy destroy outputs clean fmt validate app-build app-run

init:
	terraform init -upgrade

validate:
	terraform validate

fmt:
	terraform fmt -recursive

plan: init
	terraform plan -out=tfplan

deploy: init
	terraform plan -out=tfplan
	terraform apply tfplan
	@echo ""
	@echo "=== Deployment Complete ==="
	terraform output

destroy:
	terraform destroy -auto-approve

outputs:
	terraform output

clean:
	rm -f tfplan
	rm -rf .terraform/
	rm -f .terraform.lock.hcl

app-build:
	cd app && docker build -t fullstack-app .

app-run:
	cd app && docker compose up -d

app-stop:
	cd app && docker compose down

app-logs:
	cd app && docker compose logs -f

lint: fmt
	terraform fmt -recursive -check

grafana-url:
	@echo "Grafana: http://$$(terraform output -raw grafana_url)"

prometheus-url:
	@echo "Prometheus: http://$$(terraform output -raw prometheus_url)"

alb-url:
	@echo "App ALB: http://$$(terraform output -raw alb_dns_name)"

health:
	@curl -s http://$$(terraform output -raw alb_dns_name)/health | python3 -m json.tool
