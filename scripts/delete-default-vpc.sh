#!/usr/bin/env bash
# Deletes the default VPC (and its dependencies) in a vended account, in each
# allowed region. Terraform has no resource that deletes a default VPC, so
# this runs as a deploy step after phase 2.
#
# Usage: ./scripts/delete-default-vpc.sh <account-id> [role-name] [regions...]
set -euo pipefail

ACCOUNT_ID="${1:?usage: delete-default-vpc.sh <account-id> [role-name] [regions...]}"
ROLE_NAME="${2:-OrganizationAccountAccessRole}"
shift $(( $# > 1 ? 2 : 1 ))
REGIONS=("${@:-us-east-1 us-west-2}")
[ ${#REGIONS[@]} -eq 1 ] && read -ra REGIONS <<< "${REGIONS[0]}"

creds_json=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
  --role-session-name lza-delete-default-vpc \
  --query 'Credentials' --output json)

export AWS_ACCESS_KEY_ID=$(echo "$creds_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$creds_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$creds_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["SessionToken"])')

for region in "${REGIONS[@]}"; do
  vpc_id=$(aws ec2 describe-vpcs --region "$region" \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' --output text)

  if [ "$vpc_id" = "None" ] || [ -z "$vpc_id" ]; then
    echo "[$region] no default VPC, nothing to do"
    continue
  fi

  echo "[$region] deleting default VPC $vpc_id"

  igw_id=$(aws ec2 describe-internet-gateways --region "$region" \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query 'InternetGateways[0].InternetGatewayId' --output text)
  if [ "$igw_id" != "None" ] && [ -n "$igw_id" ]; then
    aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"
    aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$igw_id"
  fi

  for subnet_id in $(aws ec2 describe-subnets --region "$region" \
      --filters "Name=vpc-id,Values=$vpc_id" \
      --query 'Subnets[].SubnetId' --output text); do
    aws ec2 delete-subnet --region "$region" --subnet-id "$subnet_id"
  done

  aws ec2 delete-vpc --region "$region" --vpc-id "$vpc_id"
  echo "[$region] deleted"
done
