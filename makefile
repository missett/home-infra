jq=jq -r
tf_account=888577031405
tf_env=AWS_REGION=eu-west-2 AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
tf_role=arn:aws:iam::$(tf_account):role/terraform-admin
tf_mfa=arn:aws:iam::$(tf_account):mfa/terraform-admin
tf_mfa_code=${MFA_CODE}

terraform/%/creds.json:
	$(tf_env) aws sts assume-role --role-arn=$(tf_role) --role-session-name=terraform --duration-seconds=3600 --serial-number $(tf_mfa) --token-code $(tf_mfa_code) --output json > $@

terraform/%/init: terraform/%/creds.json
	AWS_REGION="eu-west-2" AWS_ACCESS_KEY_ID="$$(cat $(@D)/creds.json | $(jq) '.Credentials.AccessKeyId')" AWS_SECRET_ACCESS_KEY="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SecretAccessKey')" AWS_SESSION_TOKEN="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SessionToken')" terraform -chdir=$(@D) init -backend-config="bucket=tfstate-$(tf_account)" -backend-config="key=$(@D)" -backend-config="dynamodb_table=tfstate-lock" -input=false

terraform/%/plan: terraform/%/init
	AWS_REGION="eu-west-2" AWS_ACCESS_KEY_ID="$$(cat $(@D)/creds.json | $(jq) '.Credentials.AccessKeyId')" AWS_SECRET_ACCESS_KEY="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SecretAccessKey')" AWS_SESSION_TOKEN="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SessionToken')" terraform -chdir=$(@D) plan -out $(@F) -input=false

terraform/%/apply: terraform/%/plan
	AWS_REGION="eu-west-2" AWS_ACCESS_KEY_ID="$$(cat $(@D)/creds.json | $(jq) '.Credentials.AccessKeyId')" AWS_SECRET_ACCESS_KEY="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SecretAccessKey')" AWS_SESSION_TOKEN="$$(cat $(@D)/creds.json | $(jq) '.Credentials.SessionToken')" terraform -chdir=$(@D) apply -input=false plan



