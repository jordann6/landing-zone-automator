# Landing Zone Automator

A Terraform account vending machine for AWS. Point it at a fresh AWS Organization and it stands up a SOC 2 ready multi-account foundation: organizational units, guardrail policies, centralized audit logging, SSO permission sets, and budget alarms. New accounts are requested by adding one block to a tfvars file, and each account arrives with its baseline already applied.

Built for the gap between "one shared account with a root login" and "we need AWS Control Tower and a platform team." That gap is where startups getting SOC 2 ready, small SaaS companies separating dev/staging/prod, and MSPs onboarding new clients all live.

## The three audiences

The same workflow reads three ways, and the demo is written so each framing works:

1. **Startups, SOC 2 readiness.** Auditors ask for account separation, centralized immutable audit logs, SSO with least privilege, and root account controls. This module delivers all four in one apply.
2. **SaaS platform teams, account vending.** Dev, staging, and prod accounts per product from a single request block. This is the small-scale version of the account vending pattern platform teams run internally.
3. **MSPs, client onboarding.** "New client, day one": a fresh account lands inside guardrails with logging, budgets, and access already wired. This is a recurring billable workflow, not a one-time script.

## Architecture

```
Management account
├── AWS Organizations (all features)
│   ├── OU: Security
│   │   └── log-archive account        (org CloudTrail bucket lives here)
│   ├── OU: Workloads
│   │   ├── OU: Prod
│   │   └── OU: NonProd
│   │       └── vended demo account(s)  (created by the vending module)
│   └── OU: Sandbox                     (loose guardrails, spend cap)
├── Service control policies (attached per OU)
│   ├── deny-root-user            root user API actions blocked in member accounts
│   ├── deny-leave-org            member accounts cannot detach themselves
│   ├── region-allowlist          us-east-1 + us-west-2 only (global services exempted)
│   └── protect-audit-trail       CloudTrail/logging resources cannot be altered or deleted
├── IAM Identity Center
│   ├── Permission set: PlatformAdmin   (AdministratorAccess, 4h session)
│   ├── Permission set: Developer       (PowerUserAccess minus IAM, 8h session)
│   └── Permission set: ReadOnly        (ViewOnlyAccess, auditors live here)
├── Organization CloudTrail ──▶ S3 bucket in log-archive (SSE-KMS, versioned,
│                                object lock governance mode, access logging)
└── AWS Budgets                 org-level cap + per-vended-account budget alarm ──▶ SNS email
```

### Account vending module (the core)

`modules/account-vending` takes a map of account requests:

```hcl
accounts = {
  "acme-nonprod" = {
    email       = "you+lz-acme-nonprod@example.com"
    ou          = "nonprod"
    budget_usd  = 10
    environment = "nonprod"
  }
}
```

For each entry it:

1. Creates the member account via `aws_organizations_account` in the target OU.
2. Assumes `OrganizationAccountAccessRole` into the new account (provider alias per account) and applies the baseline:
   - deletes the default VPC (no accidental 0.0.0.0/0 workloads)
   - sets an IAM account alias and a strict IAM password policy
   - creates an `ec2:DescribeInstances`-scoped smoke-test role used by the validation step
   - tags the account with owner, environment, and cost-center (feeds the tag compliance story)
3. Creates a per-account AWS Budget with an email alarm at 80% of the cap.
4. Assigns the Identity Center groups to the account (Developer on nonprod, ReadOnly everywhere).

`close_on_deletion = true` is set on the org account resource so `terraform destroy` closes vended accounts rather than orphaning them.

### Module layout

```
landing-zone-automator/
├── main.tf / providers.tf / variables.tf / outputs.tf
├── modules/
│   ├── organization/        org, OUs, SCP documents + attachments
│   ├── identity-center/     permission sets, groups, assignments
│   ├── log-archive/         CloudTrail org trail, KMS key, S3 bucket policies
│   └── account-vending/     account creation + in-account baseline
├── envs/
│   └── demo.tfvars          the demo account requests
├── .github/workflows/ci.yml security gates (see below)
├── diagram.py
└── README.md
```

## Security gates (CI)

Per the standing DevSecOps baseline, the GitHub Actions pipeline runs on every push:

- `terraform fmt -check` and `terraform validate`
- `tflint` with the AWS ruleset
- `checkov` against the full module tree (fails the build on HIGH+)
- `gitleaks` secret scan across history
- Plan job authenticates to AWS via **GitHub OIDC**, no static keys, role scoped to plan-only permissions

## Cost estimate

Roughly **$0.10 to $0.50 total** for a build-demo-destroy cycle over a day or two:

| Item | Cost |
|---|---|
| AWS Organizations, OUs, SCPs, Identity Center, Budgets | Free |
| Organization CloudTrail (first copy of management events) | Free |
| S3 log storage for the demo window | Pennies |
| KMS key for the trail | $1/mo prorated, ~$0.03/day |
| Vended member accounts | Free (nothing deployed in them beyond IAM) |

No compute, no NAT gateways, no databases. Nothing here bills meaningfully while idle.

## Teardown risks (stated up front)

1. **Closed accounts linger for 90 days.** AWS closes, not deletes, member accounts. They sit in SUSPENDED state (unbillable, but visible in the org) for 90 days before purging. The demo therefore vends at most 2 throwaway accounts. This is a documented AWS constraint and goes in the case study, not a bug.
2. **Account closure rate limit.** AWS allows closing only 10% of member accounts (min 10) per rolling 30 days. Irrelevant at demo scale, worth documenting for the MSP framing.
3. **IAM Identity Center enablement is manual.** Enabling the Identity Center instance is a one-time console action in the management account; Terraform manages everything inside it (permission sets, assignments) but cannot create or destroy the instance itself. Destroy leaves the empty instance enabled, which costs nothing.
4. **Organization deletion is manual and last.** `terraform destroy` removes SCPs, OUs (after member accounts close), the trail, and Identity Center config. Deleting the Organization itself is a final console/CLI step once no member accounts remain.
5. **Unique account emails.** Each vended account needs a globally unique email; the demo uses `you+lz-<name>@example.com` plus-aliasing. A closed account's email cannot be reused for 90 days, so demo names include a date suffix.

## Validation checks (demo script)

1. Vended account exists in the right OU with tags applied (`aws organizations list-accounts-for-parent`).
2. SCP enforcement: from the vended account, attempt an API call in a denied region and as root-style action, confirm `AccessDenied` with an explicit SCP denial.
3. Identity Center: log in through the SSO portal as a Developer, confirm access to nonprod and denial on the management account.
4. CloudTrail: confirm events from the vended account land in the log-archive bucket within minutes.
5. Budget alarm: confirm the budget object and SNS subscription exist (triggering real spend is not worth it; show the configuration).
6. Default VPC gone: `aws ec2 describe-vpcs` in the vended account returns empty.

## Deliverables (kickoff workflow order)

1. Architecture overview — this document
2. Terraform code, modular and destroy-safe, remote state in S3
3. Deployment steps
4. Validation checks (above, scripted where possible)
5. Clean destroy steps, including the manual org-deletion tail

## Azure flavor (phase 2, separate effort)

The Azure Landing Zone (Z1) already exists in the portfolio, so the Azure version of this project is a thinner "subscription vending" module (management group placement, Azure Policy assignment, budget, RBAC) that reuses Z1 patterns. Not in scope for this build; noted so the case study can mention the multi-cloud path.
