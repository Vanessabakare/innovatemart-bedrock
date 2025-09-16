# InnovateMart Bedrock – EKS Deployment

This document is my submission for **AltSchool Cloud Engineering – Tinyuka 2024 (Third Semester, Month 2 Assessment)**.  
It details how I built a production-ready EKS cluster with Terraform, deployed the AWS Retail Store Sample App, and automated the setup with GitHub Actions.  
All deliverables are included here.

---

## 1) Company & Project Background

**Company:** InnovateMart Inc.  
**Role:** Cloud DevOps Engineer  
**Mission:** *Project Bedrock* – Deploy our new microservices retail-store application on AWS Elastic Kubernetes Service (EKS).

InnovateMart is scaling globally after raising Series A funding. The legacy monolith has been broken down into microservices, and my role is to lay the infrastructure foundation. This deployment demonstrates automation, scalability, and security — the core pillars of modern cloud engineering.

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
## 2) Architecture

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
│           ├── providers.tf   # AWS provider
│           ├── eks.tf         # VPC + EKS + node group modules
│           └── outputs.tf     # Cluster outputs
├── apps/                      # Application manifests applied directly
├── .gitignore
└── README.md
```

## 3) How I deployed the application

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

## 4) How to access the app

**Public URL (LoadBalancer DNS):**
http://a19766570af3c4048bed59e5ea04fbb1-492203156.us-east-1.elb.amazonaws.com

**Local port-forward alternative:**

```bash
kubectl port-forward deploy/ui 8080:80
# open http://localhost:8080
```

5) Developer read-only access

I created a dedicated IAM user project-bedrock-Dev-user and mapped it into the cluster with view-only rights.

AWS permissions

Attached AWS managed policy: ReadOnlyAccess

EKS access entry (view-only)

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

 ``` bash

# set the dev user's programmatic credentials
export AWS_ACCESS_KEY_ID="<ACCESS_KEY_FROM_ME>"
export AWS_SECRET_ACCESS_KEY="<SECRET_KEY_FROM_ME>"
export AWS_DEFAULT_REGION="us-east-1"

# sanity
aws sts get-caller-identity

# build a kubeconfig context named innovatemart-dev
aws eks update-kubeconfig \
  --name innovatemart-eks \
  --region us-east-1 \
  --alias innovatemart-dev

# read-only checks
kubectl config use-context innovatemart-dev
kubectl get nodes
kubectl get pods -A
kubectl get svc -n default
kubectl logs deploy/ui --tail=50
```

6) CI/CD: GitHub Actions for Terraform

I automated provisioning using a single workflow at .github/workflows/terraform.yml.
Branching behavior

Pull Requests to main: run fmt, init, validate, plan

Pushes to main: run init + apply

Backend

I reference my backend file instead of inline flags:

- name: Terraform Init
  run: terraform init -input=false -backend-config=backend.hcl -reconfigure

