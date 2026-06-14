# CloudFormation Stacks

## Stack Overview

| # | Template | Stack Name | Region | Description |
|---|---|---|---|---|
| 010 | `010-iam.yaml` | `root-access-{env}-iam` | eu-west-1 | GitHub Actions OIDC provider + deployment IAM role |
| 020 | `020-storage.yaml` | `root-access-{env}-storage` | eu-west-1 | Private S3 bucket (UI assets) + access logs bucket |
| 030 | `030-certificate.yaml` | `root-access-{env}-certificate` | **us-east-1** | ACM TLS certificate (CloudFront requirement) |
| 040 | `040-cdn.yaml` | `root-access-{env}-cdn` | eu-west-1 | CloudFront distribution with OAC + SPA routing |
| 050 | `050-dns.yaml` | `root-access-{env}-dns` | eu-west-1 | Route 53 A/AAAA/CNAME records (optional) |

## Deployment Order

Stacks must be deployed in numerical order due to cross-stack dependencies.
Stack 030 must be deployed to **us-east-1** separately before Stack 040.

## Quick Deploy (first time)

```bash
# 1. Deploy foundation stacks to eu-west-1
./scripts/deploy.sh prod root-access eu-west-1

# 2. (If using a custom domain) Deploy certificate to us-east-1
DOMAIN_NAME=root-access.example.com \
HOSTED_ZONE_ID=ZXXXXXXXXXXXXX \
./scripts/deploy-certificate.sh prod root-access

# 3. Re-deploy CDN stack with certificate ARN
aws cloudformation deploy \
  --template-file cloudformation/040-cdn.yaml \
  --stack-name root-access-prod-cdn \
  --region eu-west-1 \
  --profile root-access \
  --parameter-overrides \
    Environment=prod \
    AcmCertificateArn=arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID \
    DomainName=root-access.example.com
```

## Cross-Stack References

Stacks share values via CloudFormation Exports and SSM Parameter Store:

| SSM Path | Set by | Read by |
|---|---|---|
| `/root-access/{env}/ui-bucket-name` | 020 | CI/CD (deploy workflow) |
| `/root-access/{env}/cloudfront-distribution-id` | 040 | CI/CD (invalidation step) |
| `/root-access/{env}/certificate-arn` | 030 | 040 (manual parameter) |
