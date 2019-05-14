trf-init:
	terraform init terraform/

trf-plan:
	terraform plan -var-file="terraform/secrets.tfvars" terraform/

trf-apply:
	terraform apply -var-file="terraform/secrets.tfvars" terraform/