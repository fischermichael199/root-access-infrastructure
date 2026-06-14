# root-access-infrastructure

> AWS CloudFormation Infrastructure as Code for the Root Access narrative RPG.

## Overview

This repository contains all AWS infrastructure for the Root Access project, managed exclusively via CloudFormation. It provisions the hosting, CDN, and CI/CD identity resources required to serve the `root-access-ui` Progressive Web App globally with low latency, HTTPS, and automatic cache invalidation on each deployment.

The infrastructure follows a **static hosting** architecture: the compiled PWA artefacts are synced to a private S3 bucket and served through CloudFront. No server-side compute is required for the current single-player game.

This repository is intentionally decoupled from application code. Infrastructure changes go through their own review and deployment pipeline.

## Architecture

```
GitHub Actions (root-access-ui)
        │  OIDC AssumeRole
        ▼
┌─────────────────────────────────────────────────────┐
│ AWS Account                                         │
│                                                     │
│  IAM OIDC Provider + Deployment Role (010)          │
│                                                     │
│  S3 Bucket — root-access-prod-ui (020)              │
│  ├── index.html          (no-cache)                 │
│  ├── sw.js               (no-cache)                 │
│  └── assets/*.js|css     (1-year cache, hashed)     │
│           │ OAC (SigV4)                             │
│           ▼                                         │
│  CloudFront Distribution (040)                      │
│  ├── SPA routing (403/404 → index.html)             │
│  ├── HTTPS enforce + TLSv1.2_2021                   │
│  └── HTTP/2 + HTTP/3 + IPv6                         │
│           │                                         │
│  Route 53 DNS Records (050) — aoptional             │
│                                                     │
│  ACM Certificate (030) — us-east-1                  │
└─────────────────────────────────────────────────────┘
        │
        ▼
   Players worldwide
```

## Repository Structure

```
root-access-infrastructure/
├── cloudformation/
│   ├── 010-iam.yaml            # GitHub OIDC provider + deployment role
│   ├── 020-storage.yaml        # S3 buckets (assets + access logs)
│   ├── 030-certificate.yaml    # ACM TLS cert — deploy to us-east-1
│  #├── 040-cdn.yaml            # CloudFront distribution + OAC
│  #├── 050-dns.yaml            # Route 53 records (optional)
│   └── README.md               # Stack-by-stack deployment guide
├── scripts/
│   ├── deploy.sh               # Deploy all stacks (eu-west-1)
│   └── deploy-certificate.sh   # Deploy certificate stack (us-east-1)
├── .github/
│   └── CODEOWNERS
├── CONTRIBUTING.md             # Project-wide coding and documentation guidelines
└── README.md                   # This file
```

## Prerequisites

- AWS CLI configured with a profile named `root-access`
- Sufficient IAM permissions to create CloudFormation stacks and the resources within
- (Optional) A domain registered in Route 53 for custom domain setup

Verify your AWS identity before deploying:

```bash
aws sts get-caller-identity --profile root-access
```

## Getting Started

### 1. Clone

```bash
git clone https://github.com/fischermichael199/root-access-infrastructure.git
cd root-access-infrastructure
```

### 2. Deploy foundation stacks

```bash
./scripts/deploy.sh prod root-access eu-west-1
```

This deploys stacks **010**, **020**, **040** in order. Stack **050** (DNS) is skipped unless `DOMAIN_NAME` and `HOSTED_ZONE_ID` are set.

### 3. (Optional) Add a custom domain

```bash
# Deploy the certificate to us-east-1 first
DOMAIN_NAME=root-access.example.com \
HOSTED_ZONE_ID=ZXXXXXXXXXXXXX \
./scripts/deploy-certificate.sh prod root-access

# Then re-deploy the CDN stack with the certificate ARN
aws cloudformation deploy \
  --template-file cloudformation/040-cdn.yaml \
  --stack-name root-access-prod-cdn \
  --region eu-west-1 --profile root-access \
  --parameter-overrides \
    Environment=prod \
    AcmCertificateArn=<ARN from above> \
    DomainName=root-access.example.com
```

## Development

There is no local development environment for infrastructure. Changes are validated by deploying to a `staging` environment first:

```bash
./scripts/deploy.sh staging root-access eu-west-1
```

To validate a template locally without deploying:

```bash
aws cloudformation validate-template \
  --template-body file://cloudformation/010-iam.yaml
```

## Deployment

All stacks are deployed via `./scripts/deploy.sh`. See `cloudformation/README.md` for the full per-stack deployment guide including cross-stack parameter passing.

The `root-access-ui` repository's GitHub Actions workflow automatically syncs assets to S3 and invalidates CloudFront on every merge to `main` — cyo manual re-deployment of infrastructure is required for application updates.

## Stack Naming Convention

`root-access-{environment}-{component}`

| Environment | Usage |
|---|---|
| `prod` | Production — live players |
| `staging` | Pre-production validation |
| `dev` | Local / developer testing (optional) |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for project-wide coding, documentation, and CloudFormation guidelines.
