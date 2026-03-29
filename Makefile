.PHONY: plan apply destroy

plan:
	terragrunt run --all plan

apply:
	terragrunt run --all apply

destroy:
	terragrunt run --all destroy