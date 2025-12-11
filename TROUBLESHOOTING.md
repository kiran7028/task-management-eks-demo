# Task Management EKS Demo - Troubleshooting Guide

## 1. Docker Build and Push Issues

### Error: Variable Concatenation in Shell Script
```bash
Error response from daemon: No such image: task-management/frontendatest:latest
tag does not exist: 150965600049.dkr.ecr.ap-south-1.amazonaws.com/task-management/frontendatest:latest
```

**Root Cause**: Improper variable expansion in shell script
- `$SERVICEatest` instead of `$SERVICE`
- Missing quotes around variables

**Original Problematic Code**:
```bash
docker tag task-management/$SERVICE:latest $REGISTRY/task-management/$SERVICE:latest
```

**Solution**:
```bash
# Proper variable quoting
docker tag "task-management/${SERVICE}:latest" "${REGISTRY}/task-management/${SERVICE}:latest"

# Complete fixed script
#!/bin/bash
set -e
export REGISTRY="150965600049.dkr.ecr.ap-south-1.amazonaws.com"

for SERVICE in frontend user-service task-service notification-service; do
  echo "Building $SERVICE..."
  docker buildx build --platform linux/amd64 --load -t "task-management/${SERVICE}" "./${SERVICE}"
  docker tag "task-management/${SERVICE}:latest" "${REGISTRY}/task-management/${SERVICE}:latest"
  docker push "${REGISTRY}/task-management/${SERVICE}:latest"
done
```

**Commands to Clean Up**:
```bash
# Delete all pushed images from ECR
for repo in frontend user-service task-service notification-service; do
  aws ecr batch-delete-image --repository-name "task-management/$repo" --region ap-south-1 --image-ids imageTag=latest
done
```

---

## 2. ALB/Ingress SSL Certificate Issues

### Error: Certificate Not Found
```bash
Warning  FailedDeployModel  Failed deploy model due to operation error Elastic Load Balancing v2: CreateListener, 
https response error StatusCode: 400, RequestID: xxx, 
CertificateNotFound: Certificate 'arn:aws:acm:ap-south-1:150965600049:certificate/3bd1885f-1ece-472c-9abf-a2d263ae5cbb' not found
```

**Root Cause**: 
- Ingress configured with non-existent certificate ARN
- ALB creates HTTP listener but fails to create HTTPS listener
- HTTP traffic redirects to HTTPS but HTTPS is unavailable

**Symptoms**:
```bash
# HTTP returns 301 redirect
curl http://task-management-alb-421739480.ap-south-1.elb.amazonaws.com
# Returns: 301 Moved Permanently to HTTPS

# HTTPS connection refused
curl https://task-management-alb-421739480.ap-south-1.elb.amazonaws.com
# Returns: Connection refused
```

**Investigation Commands**:
```bash
# Check ALB listeners
aws elbv2 describe-listeners --load-balancer-arn "arn:aws:elasticloadbalancing:ap-south-1:150965600049:loadbalancer/app/task-management-alb/b467ad418e707b12" --region ap-south-1

# Check ingress status
kubectl describe ingress task-management-ingress -n task-management

# List available certificates
aws acm list-certificates --region ap-south-1
```

**Solution 1: Remove SSL (Quick Fix)**:
```bash
# Remove SSL certificate and redirect
kubectl annotate ingress task-management-ingress -n task-management \
  alb.ingress.kubernetes.io/certificate-arn- \
  alb.ingress.kubernetes.io/ssl-redirect- \
  alb.ingress.kubernetes.io/listen-ports='[{"HTTP": 80}]' \
  --overwrite
```

**Solution 2: Use Correct Certificate**:
```bash
# Find correct certificate
aws acm list-certificates --region ap-south-1

# Update ingress with correct certificate ARN
kubectl annotate ingress task-management-ingress -n task-management \
  alb.ingress.kubernetes.io/certificate-arn='arn:aws:acm:ap-south-1:150965600049:certificate/57483fa6-cafa-445f-971f-86b2de206959' \
  alb.ingress.kubernetes.io/ssl-redirect='443' \
  alb.ingress.kubernetes.io/listen-ports='[{"HTTP": 80}, {"HTTPS": 443}]' \
  --overwrite
```

---

## 3. ALB Access Issues

### Error: Direct ALB Access Not Working
```bash
# Direct access fails
curl http://task-management-alb-421739480.ap-south-1.elb.amazonaws.com
# May return 404 or default backend
```

**Root Cause**: 
- Ingress configured with specific host rules (`devopscloudai.com`)
- ALB requires proper Host header to route traffic

**Solution**:
```bash
# Access with proper Host header
curl -H "Host: devopscloudai.com" http://task-management-alb-421739480.ap-south-1.elb.amazonaws.com

# For HTTPS (with certificate verification skip)
curl -k -H "Host: devopscloudai.com" https://task-management-alb-421739480.ap-south-1.elb.amazonaws.com
```

---

## 4. SSL Certificate Validation Issues

### Error: Certificate Subject Name Mismatch
```bash
curl: (60) SSL: no alternative certificate subject name matches target host name 'task-management-alb-421739480.ap-south-1.elb.amazonaws.com'
```

**Root Cause**: 
- Certificate issued for `*.devopscloudai.com`
- Accessing via ALB DNS name instead of domain name

**Solutions**:
```bash
# Option 1: Skip certificate verification (testing only)
curl -k https://task-management-alb-421739480.ap-south-1.elb.amazonaws.com

# Option 2: Use proper domain with Host header
curl -k -H "Host: devopscloudai.com" https://task-management-alb-421739480.ap-south-1.elb.amazonaws.com

# Option 3: Set up DNS record (production)
# Create DNS record: devopscloudai.com -> task-management-alb-421739480.ap-south-1.elb.amazonaws.com
# Then access: https://devopscloudai.com
```

---

## 5. Common Debugging Commands

### Check ALB Status
```bash
# List load balancers
aws elbv2 describe-load-balancers --region ap-south-1

# Check specific ALB
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `task-management-alb-421739480`)]'

# Check listeners
aws elbv2 describe-listeners --load-balancer-arn "ALB_ARN" --region ap-south-1

# Check target groups
aws elbv2 describe-target-groups --region ap-south-1
```

### Check Kubernetes Resources
```bash
# Check ingress
kubectl get ingress -A
kubectl describe ingress task-management-ingress -n task-management

# Check services
kubectl get svc -n task-management

# Check pods
kubectl get pods -n task-management

# Check events
kubectl get events -n task-management --sort-by='.lastTimestamp'
```

### Check SSL Certificates
```bash
# List all certificates
aws acm list-certificates --region ap-south-1

# Check specific certificate
aws acm describe-certificate --certificate-arn "CERT_ARN" --region ap-south-1
```

---

## 6. Prevention Best Practices

### Shell Scripting
- Always quote variables: `"${VARIABLE}"`
- Use `set -e` for error handling
- Test scripts with `bash -x script.sh` for debugging

### Kubernetes Ingress
- Verify certificate ARNs exist before applying
- Use `kubectl describe` to check for events and errors
- Test ingress rules with proper Host headers

### ALB Configuration
- Always check ALB listeners after ingress changes
- Monitor CloudWatch logs for ALB access patterns
- Use health checks to verify backend connectivity

### SSL/TLS
- Verify certificate domains match your ingress hosts
- Use wildcard certificates for multiple subdomains
- Test certificate validation before production deployment

---

## 7. Quick Reference Commands

### Emergency Fixes
```bash
# Remove SSL from ingress (quick HTTP access)
kubectl annotate ingress task-management-ingress -n task-management alb.ingress.kubernetes.io/certificate-arn- alb.ingress.kubernetes.io/ssl-redirect- --overwrite

# Test ALB connectivity
curl -v -H "Host: devopscloudai.com" http://ALB_DNS_NAME

# Check ingress controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Cleanup Commands
```bash
# Delete ECR images
aws ecr batch-delete-image --repository-name "task-management/SERVICE_NAME" --region ap-south-1 --image-ids imageTag=latest

# Delete ingress
kubectl delete ingress task-management-ingress -n task-management

# Delete ALB (if needed)
aws elbv2 delete-load-balancer --load-balancer-arn "ALB_ARN"
```

This troubleshooting guide covers all the major issues encountered during the EKS deployment and their proven solutions.
