#!/usr/bin/env python3
"""Architecture diagram for the Landing Zone Automator.

Requires: pip install diagrams (and graphviz on the system).
Outputs docs/architecture.png.
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import Users
from diagrams.aws.management import Cloudtrail, Organizations, OrganizationsAccount
from diagrams.aws.security import IAMPermissions, KMS, SingleSignOn
from diagrams.aws.storage import S3
from diagrams.aws.cost import Budgets

graph_attr = {
    "pad": "0.4",
    "nodesep": "0.7",
    "ranksep": "0.9",
    "splines": "ortho",
}

with Diagram(
    "Landing Zone Automator",
    filename="docs/architecture",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
):
    admins = Users("Platform admins")

    with Cluster("Management account"):
        sso = SingleSignOn("IAM Identity Center\n3 permission sets")
        org = Organizations("AWS Organizations")
        scps = IAMPermissions("SCPs\n4 guardrails")
        budgets = Budgets("Per-account\nbudgets")
        trail = Cloudtrail("Org CloudTrail")
        kms = KMS("Trail KMS key")

    with Cluster("Security OU"):
        log_archive = OrganizationsAccount("log-archive")
        bucket = S3("Trail bucket\nSSE-KMS, object lock")

    with Cluster("Workloads OU / NonProd"):
        nonprod = OrganizationsAccount("demo-nonprod")

    with Cluster("Sandbox OU"):
        sandbox = OrganizationsAccount("demo-sandbox")

    admins >> sso
    sso >> Edge(style="dashed") >> nonprod
    org >> Edge(label="vends") >> log_archive
    org >> Edge(label="vends") >> nonprod
    org >> Edge(label="vends") >> sandbox
    scps >> Edge(style="dashed", label="deny") >> sandbox
    budgets >> Edge(style="dashed") >> nonprod
    kms - trail
    trail >> bucket
    log_archive - bucket
