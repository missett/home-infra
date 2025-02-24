docker_flags  = 
tf_mfa_code  ?= 
tf_account   ?=
tf_region    ?= eu-west-2
tf_role       = arn:aws:iam::$(tf_account):role/terraform-admin
tf_mfa        = arn:aws:iam::$(tf_account):mfa/terraform-admin
aws           = docker run --rm $(docker_flags) amazon/aws-cli:2.24.10
terraform     = docker run --rm $(docker_flags) --volume `pwd`:/mnt --workdir /mnt hashicorp/terraform:1.10
jq            = docker run --rm --volume `pwd`:/mnt --workdir /mnt --interactive imega/jq -r

terraform/%/creds.json: docker_flags = --env AWS_ACCOUNT_ID=$(tf_account) --env AWS_REGION=$(tf_region) --env AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} --env AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
terraform/%/creds.json:
	$(aws) sts assume-role --role-arn=$(tf_role) --role-session-name=terraform --duration-seconds=3600 --serial-number $(tf_mfa) --token-code $(tf_mfa_code) --output json > $@

terraform/%/init: docker_flags = --env AWS_REGION="$(tf_region)" --env AWS_ACCESS_KEY_ID="$$(cat $(@D)/creds.json | $(jq) '.Credentials.AccessKeyId')" --env AWS_SECRET_ACCESS_KEY="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SecretAccessKey')" --env AWS_SESSION_TOKEN="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SessionToken')"
terraform/%/init: terraform/%/creds.json
	 $(terraform) -chdir=$(@D) init -backend-config="bucket=tfstate-$(tf_account)" -backend-config="key=$(@D)" -backend-config="dynamodb_table=tfstate-lock" -input=false

terraform/%/plan: docker_flags = --env AWS_REGION="$(tf_region)" --env AWS_ACCESS_KEY_ID="$$(cat $(@D)/creds.json | $(jq) '.Credentials.AccessKeyId')" --env AWS_SECRET_ACCESS_KEY="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SecretAccessKey')" --env AWS_SESSION_TOKEN="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SessionToken')"
terraform/%/plan: terraform/%/init
	$(terraform) -chdir=$(@D) plan -out $(@F) -input=false

terraform/%/apply: docker_flags = --env AWS_REGION="$(tf_region)" --env AWS_ACCESS_KEY_ID="$$(cat $(@D)/creds.json | $(jq) '.Credentials.AccessKeyId')" --env AWS_SECRET_ACCESS_KEY="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SecretAccessKey')" --env AWS_SESSION_TOKEN="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SessionToken')"
terraform/%/apply: terraform/%/plan
	$(terraform) -chdir=$(@D) apply -input=false plan



