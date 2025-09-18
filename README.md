# InnovateMart Bedrock

It details how I built a production-ready EKS cluster with Terraform, deployed the AWS Retail Store Sample App, and automated the setup with GitHub Actions.  

---

## 1) Company & Project Background

**Company:** InnovateMart Inc.  
**Role:** Cloud DevOps Engineer  
**Mission:** *Project Bedrock* – Deploy our new microservices retail-store application on AWS Elastic Kubernetes Service (EKS).

InnovateMart is scaling globally after raising Series A funding. The legacy monolith has been broken down into microservices, and my role is to lay the infrastructure foundation. This deployment demonstrates automation, scalability, and security, the core pillars of modern cloud engineering.

---

## 2) Overview

Here’s the high-level setup I provisioned:

- **Region:** `us-east-1`
- **Cluster:** `innovatemart-eks` (Kubernetes v1.32.x)
- **IaC Tool:** Terraform with remote state (S3 + DynamoDB)
- **Workloads:** AWS retail-store sample app  
  - ui, catalog, carts, orders, checkout  
  - all in-cluster dependencies: MySQL, PostgreSQL, Redis, RabbitMQ, DynamoDB Local
- **CI/CD:** GitHub Actions
  - PR → `fmt`, `init`, `validate`, `plan`
  - Push to `main` → `init` + `apply`
- **Developer Access:** Dedicated IAM user with **read-only** rights, mapped into EKS via access entries (AmazonEKSViewPolicy)

---
## 3) Architecture

I provisioned the baseline infrastructure entirely with Terraform.

- **VPC**
  - 2 public subnets and 2 private subnets across 2 AZs
  - Internet gateway and route tables
- **EKS**
  - 1 managed node group, instance type `t3.medium`
  - Scaling: `min=1`, `desired=2`, `max=2`
  - Core add-ons: VPC CNI, kube-proxy, CoreDNS (managed by EKS)
- **Networking**
  - The `ui` service is exposed publicly with `type: LoadBalancer` (AWS-managed LB)
  - All backend services are `ClusterIP` for internal traffic
- **Terraform state**
  - S3 bucket: `innovatemart-tf-state-project2025`
  - DynamoDB lock table: `innovatemart-tf-locks`

 ## 4) Repository Layout

```text
innovatemart-bedrock/
├── .github/
│   └── workflows/
│       └── terraform.yml      # GitHub Actions workflow for IaC
├── terraform/
│   └── envs/
│       └── prod/
│           ├── backend.hcl    # Remote state config (S3 + DynamoDB)
            ├── kubeconfig-project-bedrock-dev.yaml  # Kubeconfig file for accessing the Bedrock dev cluster
            ├── main.tf        # Main entry point for Terraform configuration
│           ├── providers.tf   # AWS provider
│           ├── eks.tf         # VPC + EKS + node group modules
│           └── outputs.tf     # Cluster outputs
├── apps/                      # Application manifests applied directly
├── .gitignore
└── README.md
```

## 5) How I deployed the application

I used the upstream release manifest for the **retail-store sample app** and waited for rollouts to complete.

```bash
# context already pointed at innovatemart-eks
kubectl apply -f https://github.com/aws-containers/retail-store-sample-app/releases/latest/download/kubernetes.yaml
kubectl wait --for=condition=available deployments --all --timeout=10m
```

I verified with:

```bash
kubectl get pods -A
kubectl get svc -n default
```
You should see the microservices and their data stores Running, and a ui service of type LoadBalancer. 
The ui service exposes an external load balancer. Access the app with this URL:

```bash
http://a19766570af3c4048bed59e5ea04fbb1-492203156.us-east-1.elb.amazonaws.com
```


## 6) How to access the app

**Public URL (LoadBalancer DNS):**
http://a19766570af3c4048bed59e5ea04fbb1-492203156.us-east-1.elb.amazonaws.com

**Local port-forward alternative:**

```bash
kubectl port-forward deploy/ui 8080:80
# open http://localhost:8080
```

## 7) Developer read-only access
I created a dedicated IAM user project-bedrock-Dev-user and mapped it into the cluster with view-only rights.
- AWS permissions
- Attached AWS managed policy: ReadOnlyAccess
- EKS access entry (view-only) that I associated:

``` bash
aws eks create-access-entry \
  --cluster-name innovatemart-eks \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:user/project-bedrock-Dev-user \
  --type STANDARD

aws eks associate-access-policy \
  --cluster-name innovatemart-eks \
  --principal-arn arn:aws:iam::<ACCOUNT_ID>:user/project-bedrock-Dev-user \
  --access-scope type=cluster \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy
```
I will share this user’s Access Key and Secret Key privately as requested.
On your machine;
```bash 
export AWS_ACCESS_KEY_ID="<provided_access_key>"
export AWS_SECRET_ACCESS_KEY="<provided_secret_key>"
export AWS_DEFAULT_REGION="us-east-1"

aws sts get-caller-identity   # confirm you are using the dev user

# Build a kubeconfig that uses those credentials
aws eks update-kubeconfig \
  --name innovatemart-eks \
  --region us-east-1 \
  --alias innovatemart-dev

# Validate read access
kubectl config use-context innovatemart-dev
kubectl get nodes
kubectl get pods -A
kubectl get svc -n default
```
This user can describe resources, view logs, and list objects. It cannot mutate cluster resources.

### Developer read-only AWS Console access
I created a console login profile for the dev user and added a minimal inline policy so the EKS console can read Kubernetes objects via EKS AccessKubernetesApi.
- IAM user: project-bedrock-Dev-user
- Console: https://xxxxxxxxx.signin.aws.amazon.com/console
- Account: xxxxxxxxxxxx
- Temporary password: I set a temporary password and require reset at first login. I will share it privately.

## 8) CI/CD: GitHub Actions for Terraform

I automated provisioning using a single workflow at `.github/workflows/terraform.yml`.

### Branching behavior

- **Pull Requests to main**: run fmt, init, validate, plan  
- **Pushes to main**: run init + apply  

### Backend

I reference my backend file instead of inline flags:

```yaml
- name: Terraform Init
  run: terraform init -input=false -backend-config=backend.hcl -reconfigure
```
### Secrets used by the workflow

- `AWS_ACCESS_KEY_ID`  
- `AWS_SECRET_ACCESS_KEY`  
- `AWS_REGION = us-east-1`  
- `TF_STATE_BUCKET = innovatemart-tf-state-project2025`  
- `TF_STATE_TABLE = innovatemart-tf-locks`

### Minimal workflow outline
```yaml
name: Terraform

on:
  pull_request:
    branches: [ "main" ]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform.yml'
  push:
    branches: [ "main" ]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform.yml'

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform/envs/prod
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: false
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.13.2
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ secrets.AWS_REGION }}
      - run: terraform fmt -check
      - run: terraform init -input=false -backend-config=backend.hcl -reconfigure
      - run: terraform validate
      - run: terraform plan -input=false

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform/envs/prod
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: false
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.13.2
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            ${{ secrets.AWS_REGION }}
      - run: terraform init -input=false -backend-config=backend.hcl -reconfigure
      - run: terraform apply -input=false -auto-approve
```

## 9) Local provisioning commands

```bash
# set my local profile once
export AWS_PROFILE=InnovateMart
export AWS_DEFAULT_REGION=us-east-1

cd terraform/envs/prod

# one-time or when backend changes
terraform init -backend-config=backend.hcl -reconfigure

# create/update
terraform apply -auto-approve

# helpful outputs
terraform output

```

### backend.hcl:
```hcl
bucket         = "innovatemart-tf-state-project2025"
key            = "envs/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "innovatemart-tf-locks"
encrypt        = true
```

## 10) Security notes

- I used a separate read-only IAM user for developer access and mapped it into EKS with `AmazonEKSViewPolicy` via access entries.  
- CI secrets are stored in GitHub Actions repository secrets (no keys hardcoded).  
- All resources are in a single region (`us-east-1`).  
- The cluster runs on a current, supported Kubernetes version (`1.32`).  


