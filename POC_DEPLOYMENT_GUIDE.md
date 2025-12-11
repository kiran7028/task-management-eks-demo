# Task Management System - POC Deployment Guide

Complete step-by-step guide to deploy the Task Management System on a fresh EKS cluster.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Route53 (learnaws.today)                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              Application Load Balancer (ALB) + ACM SSL              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Amazon EKS Cluster                                │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                    task-management namespace                 │   │   │
│  │  │                                                              │   │   │
│  │  │  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐    │   │   │
│  │  │  │ Frontend │  │ User Service │  │ Notification Svc   │    │   │   │
│  │  │  │ (React)  │  │   (Node.js)  │  │ (Node.js + IRSA)   │    │   │   │
│  │  │  └──────────┘  └──────────────┘  └────────────────────┘    │   │   │
│  │  │                       │                    │                │   │   │
│  │  │  ┌──────────────┐    │                    │                │   │   │
│  │  │  │ Task Service │────┼────────────────────┘                │   │   │
│  │  │  │  (Node.js)   │    │    (sends task notifications)       │   │   │
│  │  │  └──────────────┘    │                                      │   │   │
│  │  │         │            │                                      │   │   │
│  │  │  ┌──────┴─────┐  ┌───┴────┐  ┌───────┐                    │   │   │
│  │  │  │ PostgreSQL │  │MongoDB │  │ Redis │                    │   │   │
│  │  │  └────────────┘  └────────┘  └───────┘                    │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│  ┌─────────────────┐    ┌─────────┴─────────┐                              │
│  │   Amazon ECR    │    │    Amazon SES     │                              │
│  │ (Container Imgs)│    │ (Email via IRSA)  │                              │
│  └─────────────────┘    └───────────────────┘                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **User Authentication**: Register, login, JWT-based auth
- **Task Management**: Create, update, delete, list tasks with filtering
- **Email Notifications**: Automatic email when tasks are created (via AWS SES)
- **HTTPS**: SSL/TLS via ACM certificate
- **Custom Domain**: Route53 integration (learnaws.today)

## Prerequisites

Ensure you have these tools installed:
```bash
# Check AWS CLI
aws --version

# Check kubectl
kubectl version --client

# Check eksctl
eksctl version

# Check Docker
docker --version

# Check Helm (for ALB controller)
helm version
```

## Step 1: Set Environment Variables

```bash
# IMPORTANT: Set these variables - they're used throughout the guide
export AWS_REGION=ap-south-1
export CLUSTER_NAME=your-cluster-name
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export SES_EMAIL="your-verified-email@example.com"
export DOMAIN_NAME="your-domain.com"

echo "Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Account: $ACCOUNT_ID"
echo "SES Email: $SES_EMAIL"
echo "Domain: $DOMAIN_NAME"
```

## Step 2: Create EKS Cluster (15-20 minutes)

```bash
# Create EKS cluster with 2 nodes (cost-effective for POC)
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --version 1.33 \
  --zones=ap-south-1a,ap-south-1b \
  --nodegroup-name workers \
  --node-type t3.small \
  --node-ami-family=AmazonLinux2023 \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed

# Verify cluster is ready
kubectl get nodes
kubectl cluster-info
```

> **Note:** If using an existing cluster:
> ```bash
> aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
> ```

## Step 3: Create ECR Repositories

```bash
# Create repositories for each service
aws ecr create-repository --repository-name task-management/frontend --region $AWS_REGION
aws ecr create-repository --repository-name task-management/user-service --region $AWS_REGION
aws ecr create-repository --repository-name task-management/task-service --region $AWS_REGION
aws ecr create-repository --repository-name task-management/notification-service --region $AWS_REGION

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

## Step 4: Build and Push Docker Images

```bash
export REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Build and push all services (use --platform linux/amd64 for ARM Macs)
for SERVICE in frontend user-service task-service notification-service; do
  docker buildx build --platform linux/amd64 --load -t "task-management/${SERVICE}" "./${SERVICE}" && \
  docker tag "task-management/${SERVICE}:latest" "${REGISTRY}/task-management/${SERVICE}:latest" && \
  docker push "${REGISTRY}/task-management/${SERVICE}:latest"
done

echo "All images pushed to ECR!"
```

## Step 5: Install AWS Load Balancer Controller

```bash
# Associate OIDC provider with cluster
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve

# Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json

# Create IAM policy (ignore error if already exists)
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json 2>/dev/null || echo "Policy already exists"

# Create service account for ALB controller
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts

# Install ALB controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify ALB controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## Step 6: Configure AWS SES for Email Notifications

### 6.1 Verify Email Identity
```bash
# Verify your email address in SES
aws ses verify-email-identity --email-address $SES_EMAIL --region $AWS_REGION

echo "Check your inbox ($SES_EMAIL) and click the verification link!"

# Verify status (wait for verification - check your registered email)
aws ses get-identity-verification-attributes --identities $SES_EMAIL --region $AWS_REGION
```

### 6.2 Create IAM Policy for SES
```bash
cat > ses-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail", "ses:GetSendQuota"],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy --policy-name TaskManagementSESPolicy --policy-document file://ses-policy.json 2>/dev/null || echo "Policy already exists"
```

### 6.3 Create IAM Role for Service Account (IRSA)

> **CRITICAL:** The OIDC provider ID is unique per cluster. You MUST use your cluster's OIDC provider.

```bash
# Get your cluster's OIDC provider
export OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

echo "OIDC Provider: $OIDC_PROVIDER"

# Create trust policy with YOUR cluster's OIDC provider
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:task-management:notification-service-sa"
        }
      }
    }
  ]
}
EOF

# Create or update IAM role
aws iam create-role --role-name TaskManagementSESRole \
  --assume-role-policy-document file://trust-policy.json 2>/dev/null || \
aws iam update-assume-role-policy --role-name TaskManagementSESRole \
  --policy-document file://trust-policy.json

# Attach SES policy to role
aws iam attach-role-policy --role-name TaskManagementSESRole \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/TaskManagementSESPolicy

echo "IAM Role created: arn:aws:iam::${ACCOUNT_ID}:role/TaskManagementSESRole"
```

## Step 7: Update Kubernetes Manifest

### 7.1 Update Account ID and Region
```bash
# Replace placeholders in the manifest
sed -i '' "s/982424467695/$ACCOUNT_ID/g" k8s-deployment.yaml
sed -i '' "s/ap-south-1/$AWS_REGION/g" k8s-deployment.yaml

# For Linux:
# sed -i "s/982424467695/$ACCOUNT_ID/g" k8s-deployment.yaml
# sed -i "s/ap-south-1/$AWS_REGION/g" k8s-deployment.yaml
```

### 7.2 Update SES Email Configuration
```bash
# Update the SES email addresses in the manifest
sed -i '' "s/avizway@gmail.com/$SES_EMAIL/g" k8s-deployment.yaml

# For Linux:
# sed -i "s/avizway@gmail.com/$SES_EMAIL/g" k8s-deployment.yaml
```

### 7.3 Update ACM Certificate ARN
```bash
# List your ACM certificates
aws acm list-certificates --region $AWS_REGION

# Get your certificate ARN and update the manifest
export ACM_ARN="arn:aws:acm:$AWS_REGION:$ACCOUNT_ID:certificate/YOUR-CERT-ID"
sed -i '' "s|arn:aws:acm:ap-south-1:982424467695:certificate/3bd1885f-1ece-472c-9abf-a2d263ae5cbb|$ACM_ARN|g" k8s-deployment.yaml
```

### 7.4 Update Domain Name
```bash
# Update domain in ingress
sed -i '' "s/learnaws.today/$DOMAIN_NAME/g" k8s-deployment.yaml
```

### 7.5 Verify Changes
```bash
# Check image URLs
grep "image:" k8s-deployment.yaml

# Check SES configuration
grep -A2 "SES_FROM_EMAIL\|TASK_OWNER_EMAIL" k8s-deployment.yaml

# Check certificate ARN
grep "certificate-arn" k8s-deployment.yaml

# Check domain
grep "host:" k8s-deployment.yaml
```

## Step 8: Deploy the Application

```bash
# Apply the manifest
kubectl apply -f k8s-deployment.yaml

# Watch pods come up
kubectl get pods -n task-management -w

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n task-management --timeout=300s

# Check all resources
kubectl get all -n task-management
```

## Step 9: Configure Route53 DNS

```bash
# Wait for ALB to be provisioned (2-3 minutes)
echo "Waiting for ALB to be provisioned..."
sleep 120

# Get the ALB DNS name
export ALB_DNS=$(kubectl get ingress task-management-ingress -n task-management \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"

# Get your Route53 Hosted Zone ID
export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name $DOMAIN_NAME \
  --query "HostedZones[0].Id" --output text | cut -d'/' -f3)
echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Get ALB Hosted Zone ID (for alias record)
export ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$ALB_DNS'].CanonicalHostedZoneId" \
  --output text)
echo "ALB Zone ID: $ALB_ZONE_ID"

# Create Route53 A record (Alias to ALB)
cat > route53-record.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$DOMAIN_NAME",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "dualstack.$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "www.$DOMAIN_NAME",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_ZONE_ID",
          "DNSName": "dualstack.$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://route53-record.json

echo "Route53 records created!"
echo "Application URL: https://$DOMAIN_NAME"
```

## Step 10: Verify Deployment

### 10.1 Check All Pods Are Running
```bash
kubectl get pods -n task-management

# Expected output - all pods should be Running with 0 restarts:
# NAME                                    READY   STATUS    RESTARTS   AGE
# frontend-xxx                            1/1     Running   0          5m
# mongodb-xxx                             1/1     Running   0          5m
# notification-service-xxx                1/1     Running   0          5m
# postgres-xxx                            1/1     Running   0          5m
# redis-xxx                               1/1     Running   0          5m
# task-service-xxx                        1/1     Running   0          5m
# user-service-xxx                        1/1     Running   0          5m
```

### 10.2 Verify Service Account (IRSA)
```bash
# Check notification service is using the correct service account
kubectl get pod -n task-management -l app=notification-service \
  -o jsonpath='{.items[0].spec.serviceAccountName}'
# Expected: notification-service-sa

# Check service account has IAM role annotation
kubectl describe serviceaccount notification-service-sa -n task-management
# Should show: eks.amazonaws.com/role-arn: arn:aws:iam::xxx:role/TaskManagementSESRole
```

### 10.3 Test Health Endpoints
```bash
export APP_URL="https://$DOMAIN_NAME"

# Test frontend
curl -I $APP_URL

# Test notification provider (should show "ses")
curl -s $APP_URL/api/notifications/provider
```

### 10.4 Test Email Notification
```bash
# Send a test email directly
kubectl exec -it deployment/notification-service -n task-management -- \
  wget -qO- --post-data='{"taskTitle":"Test Task","taskDescription":"Testing email","taskPriority":"high","notificationType":"created"}' \
  --header='Content-Type: application/json' \
  http://localhost:3003/api/notifications/task-event

# Check logs
kubectl logs deployment/notification-service -n task-management --tail=10
```

## Step 11: Test the Application

### 11.1 Register a User
```bash
curl -X POST $APP_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### 11.2 Login and Get Token
```bash
TOKEN=$(curl -s -X POST $APP_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123"}' | jq -r '.token')

echo "JWT Token: $TOKEN"
```

### 11.3 Create a Task (Triggers Email Notification!)
```bash
curl -X POST $APP_URL/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title": "My First Task",
    "description": "Testing the task management system",
    "priority": "high"
  }'

# Check your email - you should receive a task creation notification!
```

### 11.4 Access via Browser
Open your browser and navigate to:
- **Main App**: https://your-domain.com
- **WWW**: https://www.your-domain.com

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n task-management
kubectl describe pod <pod-name> -n task-management
```

### Check Logs
```bash
# All services
kubectl logs -l app=user-service -n task-management
kubectl logs -l app=task-service -n task-management
kubectl logs -l app=notification-service -n task-management
kubectl logs -l app=frontend -n task-management
```

### Check Ingress Status
```bash
kubectl describe ingress task-management-ingress -n task-management
```

### Common Issues

**Pods stuck in Pending:**
```bash
kubectl describe nodes
kubectl scale deployment --all --replicas=1 -n task-management
```

**Image pull errors:**
```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr describe-images --repository-name task-management/frontend --region $AWS_REGION
```

**ALB not provisioning:**
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**SES Email not working (AccessDenied: sts:AssumeRoleWithWebIdentity):**
```bash
# This error means the IAM trust policy doesn't match your cluster's OIDC provider

# 1. Get your cluster's OIDC provider ID
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
echo "Your OIDC Provider: $OIDC_PROVIDER"

# 2. Check current trust policy
aws iam get-role --role-name TaskManagementSESRole --query 'Role.AssumeRolePolicyDocument'

# 3. Update trust policy with correct OIDC provider (re-run Step 6.3)

# 4. Restart notification service
kubectl rollout restart deployment/notification-service -n task-management
```

**Notification service using Node Instance Role instead of IRSA:**
```bash
# Verify service account is configured
kubectl get deployment notification-service -n task-management \
  -o jsonpath='{.spec.template.spec.serviceAccountName}'
# Should output: notification-service-sa

# If empty, patch the deployment:
kubectl patch deployment notification-service -n task-management \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"notification-service-sa"}}}}'
```

## Cleanup

```bash
# Delete the application
kubectl delete namespace task-management

# Delete the EKS cluster (10-15 minutes)
eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION

# Delete ECR repositories
for SERVICE in frontend user-service task-service notification-service; do
  aws ecr delete-repository --repository-name task-management/$SERVICE --region $AWS_REGION --force
done

# Delete IAM resources
aws iam detach-role-policy --role-name TaskManagementSESRole \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/TaskManagementSESPolicy
aws iam delete-role --role-name TaskManagementSESRole
aws iam delete-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/TaskManagementSESPolicy

# Delete Route53 records (optional - do manually in console)
```

## Cost Estimate (POC)

| Resource | Estimated Cost |
|----------|---------------|
| EKS Cluster | $0.10/hour (~$72/month) |
| 2x t3.medium nodes | ~$0.08/hour (~$60/month) |
| ALB | ~$0.025/hour (~$18/month) |
| SES | Free tier: 62,000 emails/month |
| **Total** | **~$150/month** |

> **Tip**: Delete the cluster when not in use to save costs!

## Quick Reference

```bash
# Get application URL
kubectl get ingress -n task-management

# Check all pods
kubectl get pods -n task-management

# View logs
kubectl logs -f deployment/<service-name> -n task-management

# Restart a service
kubectl rollout restart deployment/<service-name> -n task-management

# Scale a service
kubectl scale deployment/<service-name> --replicas=2 -n task-management

# Test email notification
kubectl exec -it deployment/notification-service -n task-management -- \
  wget -qO- --post-data='{"taskTitle":"Test","taskDescription":"Test","taskPriority":"high","notificationType":"created"}' \
  --header='Content-Type: application/json' http://localhost:3003/api/notifications/task-event
```

## Key Configuration Files

| File | Purpose |
|------|---------|
| `k8s-deployment.yaml` | Main Kubernetes manifest with all resources |
| `ses-policy.json` | IAM policy for SES access |
| `trust-policy.json` | IAM trust policy for IRSA |
| `route53-record.json` | Route53 DNS record configuration |

## What's Included

- ✅ EKS cluster setup
- ✅ ECR repositories for container images
- ✅ AWS Load Balancer Controller (ALB Ingress)
- ✅ HTTPS with ACM certificate
- ✅ Route53 DNS configuration
- ✅ AWS SES email integration with IRSA
- ✅ Automatic email notifications on task creation
- ✅ MongoDB, PostgreSQL, Redis databases
- ✅ React frontend with Material UI
- ✅ Node.js microservices (user, task, notification)


## After running the kubectl apply -f k8s-deployment.yml 
kirankumar@Kirans-MacBook-Air-2 task-management-eks-demo % kubectl apply -f k8s-deployment.yaml
namespace/task-management created
configmap/app-config created
secret/app-secrets created
deployment.apps/mongodb created
service/mongodb-service created
deployment.apps/postgres created
service/postgres-service created
deployment.apps/redis created
service/redis-service created
deployment.apps/user-service created
service/user-service created
deployment.apps/task-service created
service/task-service created
serviceaccount/notification-service-sa created
deployment.apps/notification-service created
service/notification-service created
deployment.apps/frontend created
service/frontend-service created
ingress.networking.k8s.io/task-management-ingress created

## kubectl get all -n task-management 
kirankumar@Kirans-MacBook-Air-2 task-management-eks-demo % kubectl get all -n task-management  
NAME                                       READY   STATUS             RESTARTS   AGE
pod/frontend-b555bdff8-j8nns               0/1     ImagePullBackOff   0          3m5s
pod/mongodb-69777fff56-r8mkn               1/1     Running            0          3m7s
pod/notification-service-7bd4b74c6-r92x4   0/1     ImagePullBackOff   0          3m6s
pod/postgres-74f74549fc-s4vgd              1/1     Running            0          3m7s
pod/redis-77496c6479-hhd29                 1/1     Running            0          3m6s
pod/task-service-7596f9f9c5-zpqf9          0/1     ImagePullBackOff   0          3m6s
pod/user-service-857c59fd55-c8r6z          0/1     ImagePullBackOff   0          3m6s

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/frontend-service       ClusterIP   10.100.55.113    <none>        80/TCP      3m5s
service/mongodb-service        ClusterIP   10.100.132.35    <none>        27017/TCP   3m7s
service/notification-service   ClusterIP   10.100.238.105   <none>        3003/TCP    3m6s
service/postgres-service       ClusterIP   10.100.75.170    <none>        5432/TCP    3m7s
service/redis-service          ClusterIP   10.100.217.161   <none>        6379/TCP    3m6s
service/task-service           ClusterIP   10.100.171.99    <none>        3002/TCP    3m6s
service/user-service           ClusterIP   10.100.164.35    <none>        3001/TCP    3m6s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/frontend               0/1     1            0           3m5s
deployment.apps/mongodb                1/1     1            1           3m7s
deployment.apps/notification-service   0/1     1            0           3m6s
deployment.apps/postgres               1/1     1            1           3m7s
deployment.apps/redis                  1/1     1            1           3m6s
deployment.apps/task-service           0/1     1            0           3m6s
deployment.apps/user-service           0/1     1            0           3m6s

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/frontend-b555bdff8               1         1         0       3m5s
replicaset.apps/mongodb-69777fff56               1         1         1       3m7s
replicaset.apps/notification-service-7bd4b74c6   1         1         0       3m6s
replicaset.apps/postgres-74f74549fc              1         1         1       3m7s
replicaset.apps/redis-77496c6479                 1         1         1       3m6s
replicaset.apps/task-service-7596f9f9c5          1         1         0       3m6s
replicaset.apps/user-service-857c59fd55          1         1         0       3m6s
kirankumar@Kirans-MacBook-Air-2 task-management-eks-demo % kubectl get all -n task-management
