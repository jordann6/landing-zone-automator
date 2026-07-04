#!/usr/bin/env python3
"""Architecture diagram for the Landing Zone Automator.

Requires: pip install diagrams (and graphviz on the system).
Outputs landing-zone-automator.png in the repo root.
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import Users
from diagrams.aws.management import Cloudtrail, Organizations, OrganizationsAccount
from diagrams.aws.security import IAMPermissions, KMS, SingleSignOn
from diagrams.aws.storage import S3
from diagrams.aws.cost import Budgets

with Diagram(
    "Landing Zone Automator",
    filename="landing-zone-automator",
    show=False,
    direction="TB",
):
    admins = Users("Platform admins\n(SSO portal)")

    with Cluster("Management account"):
        org = Organizations("AWS Organizations")
        scps = IAMPermissions("SCPs\nroot deny / region\nallowlist / trail guard")
        sso = SingleSignOn("IAM Identity Center\nPlatformAdmin / Developer / ReadOnly")
        trail = Cloudtrail("Org CloudTrail")
        kms = KMS("Trail KMS key")
        budgets = Budgets("Per-account budgets")

    with Cluster("Security OU"):
        log_archive = OrganizationsAccount("log-archive")
        bucket = S3("Trail bucket\nSSE-KMS, versioned,\nobject lock")

    with Cluster("Workloads OU"):
        with Cluster("NonProd OU"):
            nonprod = OrganizationsAccount("vended: demo-nonprod")

    with Cluster("Sandbox OU"):
        sandbox = OrganizationsAccount("vended: demo-sandbox")

    admins >> sso
    sso >> Edge(label="assignments") >> [nonprod, sandbox]
    org >> Edge(label="vends") >> [log_archive, nonprod, sandbox]
    scps >> Edge(style="dashed", label="guardrails") >> [nonprod, sandbox, log_archive]
    trail >> kms
    trail >> bucket
    budgets >> Edge(style="dashed") >> [nonprod, sandbox]
    log_archive - bucket
