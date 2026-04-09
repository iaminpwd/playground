.PHONY: plan apply destroy

# 명령어를 칠 때 추가 옵션을 받을 수 있도록 비워둔 변수
ARGS ?=

plan:
	terragrunt run --all plan $(ARGS)

apply:
	terragrunt run --all apply $(ARGS)

destroy:
	terragrunt run --all destroy $(ARGS)