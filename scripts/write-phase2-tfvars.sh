#!/usr/bin/env bash
# After the stage 1 apply, writes phase2.auto.tfvars with the account IDs
# the aliased providers need for stage 2. The file matches the gitignored
# *.tfvars pattern, so account IDs stay out of the repo.
set -euo pipefail
cd "$(dirname "$0")/.."

log_archive_id=$(terraform output -raw log_archive_account_id)
vended_json=$(terraform output -json vended_account_ids)

cat > phase2.auto.tfvars <<EOF
log_archive_account_id = "${log_archive_id}"
baseline_account_ids = ${vended_json}
EOF

echo "wrote phase2.auto.tfvars; now set phase2_enabled = true and apply"
