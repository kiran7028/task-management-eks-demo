# Task Management System - EKS Microservices Demo


A complete microservices-based task management system built with Node.js, React, and designed for deployment on Amazon EKS. This application demonstrates modern microservices architecture, containerization, and cloud-native deployment patterns.

## 🚀 Quick Deployment

Follow the step-by-step guide in **[POC_DEPLOYMENT_GUIDE.md](POC_DEPLOYMENT_GUIDE.md)**

### Quick Start Commands
```bash
# 1. Set environment variables
export AWS_REGION=ap-south-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 2. Update the K8s manifest with your values
sed -i '' "s/<ACCOUNT_ID>/$ACCOUNT_ID/g; s/<REGION>/$AWS_REGION/g" k8s-deployment.yaml

# 3. Deploy to EKS
kubectl apply -f k8s-deployment.yaml

# 4. Create Route53 record pointing to ALB (see POC_DEPLOYMENT_GUIDE.md Step 8)

# 5. Access the application
# https://learnaws.today
```

## 📁 Project Structure

```
task-management-eks-demo/
├── frontend/                 # React frontend application
├── user-service/             # User authentication service (Node.js + MongoDB)
├── task-service/             # Task management service (Node.js + PostgreSQL)
├── notification-service/     # Email notification service (Node.js + Redis + SES)
├── k8s/                      # Individual K8s manifests (alternative)
├── k8s-deployment.yaml       # All-in-one K8s manifest (MAIN)
├── POC_DEPLOYMENT_GUIDE.md   # Step-by-step deployment guide
├── ARCHITECTURE.md           # System architecture details
└── README.md                 # This file
```

## 📋 Files to Update Before Deployment

In `k8s-deployment.yaml`, replace these placeholders:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<ACCOUNT_ID>` | Your AWS Account ID | `982424467695` |
| `<REGION>` | Your AWS Region | `ap-south-1` |

**Domain**: `https://learnaws.today` (ACM certificate already configured)

## 🏗️ Architecture Overview

This application consists of the following microservices:

- **Frontend** (React + Material-UI + Nginx) - Port 80
- **User Service** (Node.js + MongoDB + JWT Auth) - Port 3001
- **Task Service** (Node.js + PostgreSQL + Auth Middleware) - Port 3002
- **Notification Service** (Node.js + Redis + AWS SES/SMTP) - Port 3003

### Architecture Diagram
```
                              ┌─────────────────────────────────────────────────────────────┐
                              │                        AWS Cloud                             │
                              │  ┌─────────────────────────────────────────────────────────┐ │
                              │  │                    Amazon EKS Cluster                    │ │
┌──────────────┐              │  │                                                         │ │
│   Internet   │              │  │  ┌─────────────────────────────────────────────────┐   │ │
│    Users     │──────────────┼──┼─►│            AWS Application Load Balancer        │   │ │
└──────────────┘              │  │  │                    (Ingress)                     │   │ │
                              │  │  └─────────────────────────────────────────────────┘   │ │
                              │  │                          │                              │ │
                              │  │         ┌────────────────┼────────────────┐            │ │
                              │  │         ▼                ▼                ▼            │ │
                              │  │  ┌────────────┐  ┌────────────┐  ┌────────────────┐   │ │
                              │  │  │  Frontend  │  │   User     │  │     Task       │   │ │
                              │  │  │  (React)   │  │  Service   │  │    Service     │   │ │
                              │  │  │  Port 80   │  │  Port 3001 │  │   Port 3002    │   │ │
                              │  │  └────────────┘  └─────┬──────┘  └───────┬────────┘   │ │
                              │  │                        │                  │            │ │
                              │  │                        ▼                  ▼            │ │
                              │  │                 ┌────────────┐    ┌────────────┐      │ │
                              │  │                 │  MongoDB   │    │ PostgreSQL │      │ │
                              │  │                 │ (Users DB) │    │ (Tasks DB) │      │ │
                              │  │                 └────────────┘    └────────────┘      │ │
                              │  │                                                         │ │
                              │  │  ┌────────────────────┐    ┌────────────┐              │ │
                              │  │  │   Notification     │───►│   Redis    │              │ │
                              │  │  │     Service        │    │  (Cache)   │              │ │
                              │  │  │    Port 3003       │    └────────────┘              │ │
                              │  │  └─────────┬──────────┘                                │ │
                              │  │            │ IAM Role (IRSA)                           │ │
                              │  └────────────┼───────────────────────────────────────────┘ │
                              │               ▼                                             │
                              │       ┌────────────────┐                                    │
                              │       │   Amazon SES   │                                    │
                              │       │ (Email Service)│                                    │
                              │       └────────────────┘                                    │
                              └─────────────────────────────────────────────────────────────┘
```

### AWS Services Used
| Service | Purpose |
|---------|---------|
| **Amazon EKS** | Kubernetes cluster for container orchestration |
| **Amazon ECR** | Container registry for Docker images |
| **Amazon SES** | Email delivery service for notifications |
| **AWS ALB** | Application Load Balancer for ingress traffic |
| **IAM Roles** | Service account authentication (IRSA) |

## 📋 Prerequisites

### For Docker Compose Development:
- Docker 20.10+ and Docker Compose V2
- Git
- 8GB+ RAM recommended
- Ports 3000-3003, 5432, 27017, 6379 available

### For EKS Deployment:
- AWS CLI configured with appropriate permissions
- kubectl installed
- eksctl or Terraform for EKS cluster creation
- Docker for building and pushing images
- AWS ECR or Docker Hub account

## 🚀 Complete Application Workflow

### 1. User Registration & Authentication Flow
```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant US as User Service
    participant DB as MongoDB
    
    U->>F: Access /register
    F->>F: Display registration form
    U->>F: Submit registration data
    F->>US: POST /api/auth/register
    US->>DB: Store user data
    DB-->>US: User created
    US-->>F: Success response
    F-->>U: Registration successful
```

**Step-by-step process:**
1. User navigates to `http://localhost:3000`
2. Clicks "Register" if new user
3. Fills registration form (username, email, password, firstName, lastName)
4. Frontend sends POST request to User Service
5. User Service validates data and stores in MongoDB
6. JWT token generated and returned
7. User automatically logged in and redirected to Dashboard

### 2. Task Management Flow
```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant TS as Task Service
    participant US as User Service
    participant DB as PostgreSQL
    
    U->>F: Navigate to Tasks
    F->>TS: GET /api/tasks (with JWT)
    TS->>US: Validate JWT token
    US-->>TS: Token valid
    TS->>DB: Query user tasks
    DB-->>TS: Return tasks
    TS-->>F: Tasks data
    F-->>U: Display tasks list
    
    U->>F: Create new task
    F->>TS: POST /api/tasks (with JWT)
    TS->>DB: Insert new task
    DB-->>TS: Task created
    TS-->>F: Success response
    F-->>U: Task added to list
```

**Task Operations Available:**
- **Create Task**: Title, description, priority (low/medium/high), status
- **Edit Task**: Update any task field
- **Delete Task**: Remove task permanently
- **Toggle Status**: Mark as pending/in-progress/completed
- **Filter Tasks**: By status, priority, or search term
- **Task Statistics**: View counts on dashboard

### 3. Notification System Flow (AWS SES)
```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant NS as Notification Service
    participant R as Redis
    participant SES as AWS SES
    
    U->>F: Navigate to Notifications
    F->>F: Display notification center
    U->>F: Send email notification
    F->>NS: POST /api/notifications/email
    NS->>SES: SendEmail (via IAM Role)
    SES-->>NS: MessageId returned
    NS->>R: Store notification history
    R-->>NS: Stored successfully
    NS-->>F: Success response
    F-->>U: Email sent confirmation
    U->>F: Send email notification
    F->>NS: POST /api/notifications/email
    NS->>SMTP: Send email via SMTP
    SMTP-->>NS: Email sent confirmation
    NS->>R: Store notification history
    R-->>NS: Stored successfully
    NS-->>F: Success response
    F-->>U: Email sent confirmation
```

**Notification Features:**
- **Manual Emails**: Send custom emails to any recipient
- **Task Reminders**: Automated reminders for specific tasks
- **Email History**: Track all sent notifications with timestamps
- **Test Emails**: Verify SMTP configuration
- **Professional Templates**: HTML formatted emails with fallback text

### 4. Complete User Journey

#### First-Time User Experience:
1. **Landing**: Access `http://localhost:3000` → Redirected to login
2. **Registration**: Click "Register" → Fill form → Account created
3. **Dashboard**: View welcome message and task statistics (initially 0)
4. **Create Tasks**: Click "Manage Tasks" → Add first task
5. **Task Management**: Edit, complete, or delete tasks
6. **Notifications**: Send task reminders or custom emails
7. **Navigation**: Seamless movement between Dashboard, Tasks, and Notifications

#### Returning User Experience:
1. **Login**: Enter credentials → JWT token stored
2. **Dashboard**: View updated task statistics and recent activity
3. **Task Updates**: Manage existing tasks, create new ones
4. **Notifications**: Check notification history, send new notifications
5. **Logout**: Secure session termination

## 🐳 Docker Compose Development Setup

### Complete Setup Process

#### 1. Clone and Prepare
```bash
# Clone the repository
git clone <repository-url>
cd task-management-eks-demo

# Verify Docker installation
docker --version
docker compose version
```

#### 2. Configure Email Notifications (Optional but Recommended)
Edit `docker-compose.yml` to configure SMTP:

```yaml
notification-service:
  environment:
    # Gmail configuration (recommended for testing)
    SMTP_HOST: smtp.gmail.com
    SMTP_PORT: 587
    SMTP_USER: your-email@gmail.com
    SMTP_PASS: your-16-character-app-password
    
    # Or use other providers:
    # Outlook: smtp-mail.outlook.com
    # Yahoo: smtp.mail.yahoo.com
```

**Gmail Setup Steps:**
1. Enable 2-Factor Authentication on Gmail
2. Go to Google Account → Security → 2-Step Verification → App passwords
3. Generate app password for "Mail"
4. Use the 16-character password in SMTP_PASS

#### 3. Start All Services
```bash
# Build and start all services in detached mode
docker compose up --build -d

# Monitor startup logs
docker compose logs -f

# Check service status
docker compose ps
```

#### 4. Verify Service Health
```bash
# Check individual service health
curl http://localhost:3001/health  # User Service
curl http://localhost:3002/health  # Task Service
curl http://localhost:3003/health  # Notification Service

# Check database connections
docker compose exec postgres pg_isready -U taskuser
docker compose exec mongodb mongosh --eval "db.adminCommand('ping')"
docker compose exec redis redis-cli ping
```

#### 5. Access the Application
- **Frontend**: http://localhost:3000
- **User Service API**: http://localhost:3001
- **Task Service API**: http://localhost:3002
- **Notification Service API**: http://localhost:3003

### Development Commands

#### Service Management
```bash
# Stop all services
docker compose down

# Stop and remove volumes (fresh start)
docker compose down -v

# Restart specific service
docker compose restart user-service

# Rebuild specific service
docker compose up --build user-service -d

# View logs for specific service
docker compose logs -f task-service
```

#### Database Access
```bash
# MongoDB (User Service)
docker compose exec mongodb mongosh taskmanager

# PostgreSQL (Task Service)
docker compose exec postgres psql -U taskuser -d taskmanager

# Redis (Notification Service)
docker compose exec redis redis-cli
```

#### Troubleshooting
```bash
# Check resource usage
docker stats

# Inspect service configuration
docker compose config

# Check network connectivity
docker compose exec frontend ping user-service
docker compose exec task-service ping postgres

# View detailed service info
docker inspect task-management-eks-demo-user-service-1
```

## ☸️ Amazon EKS Deployment

### Prerequisites Setup

#### 1. AWS CLI Configuration
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region (e.g., us-west-2), Output format (json)

# Verify configuration
aws sts get-caller-identity
```

#### 2. Install kubectl
```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl

# Verify installation
kubectl version --client
```

#### 3. Install eksctl
```bash
# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Verify installation
eksctl version
```

### EKS Cluster Creation

#### 1. Create EKS Cluster
```bash
# Create cluster with eksctl (takes 15-20 minutes)
eksctl create cluster \
  --name task-management-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Verify cluster creation
kubectl get nodes
kubectl get namespaces
```

#### 2. Configure kubectl Context
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name task-management-cluster

# Verify connection
kubectl cluster-info
kubectl get svc
```

### Container Registry Setup

#### 1. Create ECR Repositories
```bash
# Create repositories for each service
aws ecr create-repository --repository-name task-management/frontend --region us-west-2
aws ecr create-repository --repository-name task-management/user-service --region us-west-2
aws ecr create-repository --repository-name task-management/task-service --region us-west-2
aws ecr create-repository --repository-name task-management/notification-service --region us-west-2

# Get login token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com
```

#### 2. Build and Push Images
```bash
# Set variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-west-2
REGISTRY=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# Build and push frontend
docker build -t task-management/frontend ./frontend
docker tag task-management/frontend:latest ${REGISTRY}/task-management/frontend:latest
docker push ${REGISTRY}/task-management/frontend:latest

# Build and push user-service
docker build -t task-management/user-service ./user-service
docker tag task-management/user-service:latest ${REGISTRY}/task-management/user-service:latest
docker push ${REGISTRY}/task-management/user-service:latest

# Build and push task-service
docker build -t task-management/task-service ./task-service
docker tag task-management/task-service:latest ${REGISTRY}/task-management/task-service:latest
docker push ${REGISTRY}/task-management/task-service:latest

# Build and push notification-service
docker build -t task-management/notification-service ./notification-service
docker tag task-management/notification-service:latest ${REGISTRY}/task-management/notification-service:latest
docker push ${REGISTRY}/task-management/notification-service:latest
```

### Kubernetes Deployment

#### 1. Create Kubernetes Manifests
Create `k8s/` directory with the following files:

**Namespace and ConfigMap:**
```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: task-management

---
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: task-management
data:
  JWT_SECRET: "supersecretjwttokenfortaskmanagement"
  USER_SERVICE_URL: "http://user-service:3001"
  SMTP_HOST: "smtp.gmail.com"
  SMTP_PORT: "587"
```

**Database Services:**
```yaml
# k8s/databases.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: task-management
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:7-jammy
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_DATABASE
          value: taskmanager
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
  volumeClaimTemplates:
  - metadata:
      name: mongodb-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi

---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: task-management
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
  clusterIP: None
```

**Application Services:**
```yaml
# k8s/user-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: task-management
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/task-management/user-service:latest
        ports:
        - containerPort: 3001
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3001"
        - name: MONGODB_URI
          value: "mongodb://mongodb:27017/taskmanager"
        - name: JWT_SECRET
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: JWT_SECRET

---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: task-management
spec:
  selector:
    app: user-service
  ports:
  - port: 3001
    targetPort: 3001
```

#### 2. Deploy to EKS
```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n task-management
kubectl get services -n task-management

# Check logs
kubectl logs -f deployment/user-service -n task-management
```

#### 3. Setup Ingress Controller
```bash
# Install AWS Load Balancer Controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=task-management-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=task-management-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

#### 4. Create Ingress
```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: task-management-ingress
  namespace: task-management
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api/auth
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      - path: /api/users
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 3001
      - path: /api/tasks
        pathType: Prefix
        backend:
          service:
            name: task-service
            port:
              number: 3002
      - path: /api/notifications
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 3003
```

### Monitoring and Maintenance

#### 1. Setup Monitoring
```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Default login: admin/prom-operator
```

#### 2. Scaling and Updates
```bash
# Scale services
kubectl scale deployment user-service --replicas=3 -n task-management

# Rolling update
kubectl set image deployment/user-service user-service=<new-image> -n task-management

# Check rollout status
kubectl rollout status deployment/user-service -n task-management
```

#### 3. Cleanup
```bash
# Delete application
kubectl delete namespace task-management

# Delete cluster
eksctl delete cluster --name task-management-cluster --region us-west-2
```

## 🧪 API Testing and Validation

### Complete API Testing Suite

#### 1. User Registration and Authentication
```bash
# Register new user
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "testpass123",
    "firstName": "Test",
    "lastName": "User"
  }'

# Expected Response:
# {
#   "message": "User registered successfully",
#   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "user": {
#     "id": "...",
#     "username": "testuser",
#     "email": "test@example.com",
#     "firstName": "Test",
#     "lastName": "User"
#   }
# }

# Login existing user
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpass123"
  }'

# Get current user profile (requires token)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3001/api/auth/me
```

#### 2. Task Management Operations
```bash
# Create new task
curl -X POST http://localhost:3002/api/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "title": "Complete project documentation",
    "description": "Write comprehensive README and API documentation",
    "priority": "high",
    "status": "pending"
  }'

# Get all tasks for user
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3002/api/tasks

# Get specific task
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3002/api/tasks/TASK_ID

# Update task
curl -X PUT http://localhost:3002/api/tasks/TASK_ID \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "title": "Updated task title",
    "status": "in-progress"
  }'

# Delete task
curl -X DELETE http://localhost:3002/api/tasks/TASK_ID \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Get task statistics
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3002/api/tasks/stats
```

#### 3. Notification System Testing
```bash
# Send custom email notification
curl -X POST http://localhost:3003/api/notifications/email \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "to": "recipient@example.com",
    "subject": "Task Management System Notification",
    "text": "This is a test notification from the task management system.",
    "html": "<h2>Task Notification</h2><p>This is a <strong>test notification</strong> from the task management system.</p>"
  }'

# Send task reminder
curl -X POST http://localhost:3003/api/notifications/task-reminder \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "userId": "USER_ID",
    "taskId": "TASK_ID",
    "taskTitle": "Complete project documentation",
    "dueDate": "2024-12-31"
  }'

# Get notification history
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:3003/api/notifications/history/USER_ID?page=1&limit=10"

# Send test email
curl -X POST http://localhost:3003/api/notifications/test-email \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "to": "test@example.com"
  }'

# Check notification status
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3003/api/notifications/status/NOTIFICATION_ID
```

## 📊 Services Overview

### User Service (Port 3001)
- **Database**: MongoDB
- **Features**: 
  - User registration with validation
  - JWT-based authentication
  - Profile management
  - Password hashing with bcrypt
  - Email uniqueness validation
- **Endpoints**: 
  - `POST /api/auth/register` - User registration
  - `POST /api/auth/login` - User login
  - `GET /api/auth/me` - Get current user profile
  - `GET /api/users/:id` - Get user by ID
  - `PUT /api/users/:id` - Update user profile
- **Security**: JWT tokens, password hashing, input validation

### Task Service (Port 3002)
- **Database**: PostgreSQL with Sequelize ORM
- **Features**: 
  - Complete CRUD operations for tasks
  - Task filtering by status, priority
  - Task search functionality
  - User-specific task isolation
  - Task statistics and analytics
- **Endpoints**: 
  - `GET /api/tasks` - Get user tasks with filtering
  - `POST /api/tasks` - Create new task
  - `GET /api/tasks/:id` - Get specific task
  - `PUT /api/tasks/:id` - Update task
  - `DELETE /api/tasks/:id` - Delete task
  - `GET /api/tasks/stats` - Get task statistics
- **Authentication**: JWT middleware validation

### Notification Service (Port 3003)
- **Database**: Redis for notification history and caching
- **Email Provider**: AWS SES (production) or SMTP (development)
- **Features**: 
  - AWS SES integration with IAM roles (IRSA)
  - Fallback SMTP support for development
  - Professional HTML email templates
  - Task reminder automation
  - Notification history tracking
  - Email delivery status monitoring
  - Test email functionality
- **Endpoints**: 
  - `POST /api/notifications/email` - Send custom email
  - `POST /api/notifications/task-reminder` - Send task reminder
  - `GET /api/notifications/history/:userId` - Get notification history
  - `GET /api/notifications/status/:id` - Check notification status
  - `POST /api/notifications/test-email` - Send test email
  - `GET /api/notifications/provider` - Check current email provider config
- **Integration**: AWS SES via SDK, Redis storage, IAM roles for authentication

### Frontend Service (Port 3000)
- **Framework**: React 18 with Material-UI v5
- **Features**: 
  - Responsive design for all screen sizes
  - Complete user authentication flow
  - Real-time task management interface
  - Comprehensive notification center
  - Professional navigation and UX
  - Form validation and error handling
- **Pages**: 
  - `/login` - Authentication page
  - `/dashboard` - Main dashboard with statistics
  - `/tasks` - Task management interface
  - `/notifications` - Notification center
- **API Gateway**: Nginx proxy for seamless API routing

## 🔧 Environment Configuration

### User Service Environment Variables
```bash
NODE_ENV=development                    # Environment mode
PORT=3001                              # Service port
MONGODB_URI=mongodb://mongodb:27017/taskmanager  # MongoDB connection
JWT_SECRET=supersecretjwttokenfortaskmanagement   # JWT signing secret
```

### Task Service Environment Variables
```bash
NODE_ENV=development                    # Environment mode
PORT=3002                              # Service port
POSTGRES_URI=postgresql://taskuser:taskpassword@postgres:5432/taskmanager  # PostgreSQL connection
JWT_SECRET=supersecretjwttokenfortaskmanagement   # JWT validation secret
USER_SERVICE_URL=http://user-service:3001         # User service endpoint
```

### Notification Service Environment Variables
```bash
NODE_ENV=production                     # Environment mode
PORT=3003                              # Service port
REDIS_HOST=redis-service               # Redis host
REDIS_PORT=6379                        # Redis port
USER_SERVICE_URL=http://user-service:3001  # User service endpoint

# Email Provider Selection
EMAIL_PROVIDER=ses                     # 'ses' for AWS SES, 'smtp' for SMTP/Gmail

# AWS SES Configuration (Production - Recommended)
AWS_REGION=ap-south-1                  # AWS region for SES
SES_FROM_EMAIL=noreply@yourdomain.com  # Verified sender email

# SMTP Configuration (Development - Alternative)
SMTP_HOST=smtp.gmail.com               # SMTP server host
SMTP_PORT=587                          # SMTP server port
SMTP_USER=your-email@gmail.com         # SMTP username
SMTP_PASS=your-app-password            # SMTP password (use app password for Gmail)
```

### Frontend Environment Variables
```bash
REACT_APP_API_URL=""                   # API base URL (empty for proxy routing)
```

## 📧 Email Notification Configuration

The notification service supports two email providers:
- **AWS SES** (Recommended for Production/EKS)
- **SMTP/Gmail** (For Development)

### AWS SES Setup (Recommended for EKS)

AWS SES provides better deliverability, scalability, and native AWS integration using IAM roles.

#### Step 1: Verify Email Identity in SES
```bash
# Verify your sender email address
aws ses verify-email-identity --email-address your-email@domain.com --region ap-south-1

# Check verification status (click the link in verification email first)
aws ses get-identity-verification-attributes --identities your-email@domain.com --region ap-south-1
```

#### Step 2: Create IAM Policy for SES
```bash
# Create SES policy
cat > ses-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy --policy-name TaskManagementSESPolicy --policy-document file://ses-policy.json
```

#### Step 3: Create IAM Role for Service Account (IRSA)
```bash
# Get your cluster OIDC provider
CLUSTER_NAME="your-cluster-name"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

# Create trust policy and IAM role
# See setup-ses.sh for complete script
```

#### Step 4: Configure Notification Service for SES
```bash
# Create service account with IAM role annotation
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: notification-service-sa
  namespace: task-management-docker
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/TaskManagementSESRole
EOF

# Update notification service environment
kubectl set env deployment/notification-service -n task-management-docker \
  EMAIL_PROVIDER=ses \
  AWS_REGION=ap-south-1 \
  SES_FROM_EMAIL=your-verified-email@domain.com

# Patch deployment to use service account
kubectl patch deployment notification-service -n task-management-docker \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"notification-service-sa"}}}}'
```

#### Step 5: Test SES Email
```bash
# Check provider configuration
curl http://YOUR_APP_URL/api/notifications/provider

# Send test email
curl -X POST http://YOUR_APP_URL/api/notifications/test-email \
  -H "Content-Type: application/json" \
  -d '{"to": "your-verified-email@domain.com"}'
```

> **Note**: SES sandbox mode only allows sending to verified email addresses. Request production access in AWS Console for unrestricted sending.

---

### Gmail/SMTP Setup (For Development)

#### Step 1: Enable 2-Factor Authentication
1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable "2-Step Verification"

#### Step 2: Generate App Password
1. Go to Google Account → Security → 2-Step Verification → App passwords
2. Generate password for "Mail" application
3. Copy the 16-character app password

#### Step 3: Configure Application
```bash
kubectl set env deployment/notification-service -n task-management-docker \
  EMAIL_PROVIDER=smtp \
  SMTP_HOST=smtp.gmail.com \
  SMTP_PORT=587 \
  SMTP_USER=your-email@gmail.com \
  SMTP_PASS=your-app-password
```

### Email Provider Comparison

| Feature | AWS SES | Gmail SMTP |
|---------|---------|------------|
| **Best For** | Production | Development |
| **Authentication** | IAM Roles (IRSA) | Username/Password |
| **Scalability** | High | Limited (500/day) |
| **Cost** | $0.10/1000 emails | Free |
| **Setup Complexity** | Medium | Easy |
| **Deliverability** | Excellent | Good |

### Notification Features Overview

#### Email Types Available
- **Custom Emails**: Send personalized emails to any recipient
- **Task Reminders**: Automated reminders with task details and due dates
- **System Notifications**: Account-related notifications
- **Test Emails**: Configuration verification emails

#### Email Templates
- **Professional HTML formatting** with company branding
- **Plain text fallback** for email clients that don't support HTML
- **Responsive design** that works on desktop and mobile
- **Task-specific templates** with priority indicators and due dates

#### Notification Tracking
- **Delivery Status**: Track sent, delivered, failed status
- **Timestamp Logging**: Precise send time recording
- **Recipient Tracking**: Monitor who received notifications
- **History Export**: Download notification logs for reporting

#### Frontend Notification Center Features
Access via Dashboard → Notifications:

**Send Email Tab:**
- Recipient email address input with validation
- Subject line customization
- Rich text message composition
- Send and test functionality

**History Tab:**
- Chronological list of all sent notifications
- Status indicators (sent, delivered, failed)
- Recipient and timestamp information
- Searchable and filterable interface

**Task Reminders Tab:**
- Dropdown selection of user's tasks
- Automatic task detail inclusion
- One-click reminder sending
- Task priority and due date integration

## Development

### Stop all services
```bash
docker compose down
```

### View logs
```bash
docker compose logs -f [service-name]
```

### Rebuild specific service
```bash
docker compose up --build [service-name] -d
```

## Database Access

### MongoDB (User Service)
```bash
docker exec -it task-management-eks-demo-mongodb-1 mongosh taskmanager
```

### PostgreSQL (Task Service)
```bash
docker exec -it task-management-eks-demo-postgres-1 psql -U taskuser -d taskmanager
```

### Redis (Notification Service)
```bash
docker exec -it task-management-eks-demo-redis-1 redis-cli
```

## Features Implemented

✅ User registration and authentication  
✅ JWT-based authorization  
✅ Task CRUD operations  
✅ Task filtering and pagination  
✅ Email notification system (requires SMTP config)  
✅ Task reminder notifications  
✅ Notification history and tracking  
✅ Microservices architecture  
✅ Docker containerization  
✅ API gateway (nginx proxy)  
✅ Health check endpoints  
✅ Database integration (MongoDB, PostgreSQL, Redis)  

## Next Steps for EKS Deployment

1. Create Kubernetes manifests for each service
2. Set up Helm charts for easier deployment
3. Configure ingress controller for external access
4. Set up monitoring and logging (Prometheus, Grafana, ELK stack)
5. Implement service mesh (Istio) for advanced traffic management
6. Add CI/CD pipeline for automated deployments

## Troubleshooting

### Services not starting
- Check Docker logs: `docker compose logs [service-name]`
- Ensure all required ports are available
- Verify environment variables are set correctly

### Database connection issues
- Wait for databases to be healthy: `docker compose ps`
- Check database logs for connection errors

### MongoDB readiness probe issues (Kubernetes)
```bash
# If MongoDB pods show as "Not Ready", remove readiness probe:
kubectl patch deployment mongodb -n task-management -p '{"spec":{"template":{"spec":{"containers":[{"name":"mongodb","readinessProbe":null}]}}}}'
```

### API calls failing
- Verify JWT tokens are valid and not expired
- Check service-to-service communication
- Ensure nginx proxy configuration is correct

## License

This project is for demonstration purposes as part of an EKS microservices architecture, designed and implemented by "Avinash Reddy Thipparthi".
