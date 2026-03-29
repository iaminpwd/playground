.PHONY: all init apply destroy

all: apply

init:
	cd 01-network && terraform init
	cd 02-security && terraform init
	cd 03-services && terraform init

apply:
	cd 01-network && terraform apply -auto-approve
	cd 02-security && terraform apply -auto-approve
	cd 03-services && terraform apply -auto-approve

destroy:
	cd 03-services && terraform destroy -auto-approve
	cd 02-security && terraform destroy -auto-approve
	cd 01-network && terraform destroy -auto-approve
