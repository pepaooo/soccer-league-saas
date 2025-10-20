# DEPLOYMENT_GUIDE.md - AWS Production Deployment

## 🎯 Deployment Overview

This guide covers the complete production deployment of your SaaS platform to AWS.

**Timeline**: 4-6 hours for initial setup  
**Cost Estimate**: ~$130-180 USD/month  
**Target Region**: `us-east-1` (N. Virginia) or `sa-east-1` (São Paulo for Latin America)

---

## 📋 Prerequisites

- [ ] AWS Account created
- [ ] Domain purchased (e.g., ligamanager.com)
- [ ] Code pushed to GitHub/GitLab
- [ ] Local testing completed
- [ ] Database migrations tested
- [ ] Environment variables documented

---

## 🏗️ Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────┬────────────────────────────────────────────────┘
             │
    ┌────────▼─────────┐
    │   Route 53 DNS   │
    │  ligamanager.com │
    └────────┬─────────┘
             │
    ┌────────▼─────────┐
    │  CloudFront CDN  │ (Frontend - Static Assets)
    └────────┬─────────┘
             │
    ┌────────▼─────────┐           ┌──────────────┐
    │  S3 Bucket       │◄──────────┤ GitHub       │
    │  (Next.js Build) │           │ Actions CI   │
    └──────────────────┘           └──────────────┘
    
    ┌────────────────────────────────────────────┐
    │         Application Load Balancer          │
    │       api.ligamanager.com                  │
    │       *.api.ligamanager.com (wildcard)     │
    └─────┬────────────────────┬─────────────────┘
          │                    │
    ┌─────▼─────┐        ┌─────▼─────┐
    │  EC2      │        │  EC2      │
    │  Instance │        │  Instance │
    │  (Primary)│        │  (Standby)│
    │  Spring   │        │  Spring   │
    │  Boot App │        │  Boot App │
    └─────┬─────┘        └─────┬─────┘
          │                    │
          └────────┬───────────┘
                   │
          ┌────────▼─────────┐
          │  RDS PostgreSQL  │
          │  (Multi-AZ)      │
          └────────┬─────────┘
                   │
          ┌────────▼─────────┐
          │ ElastiCache Redis│
          │  (Standings)     │
          └──────────────────┘
```

---

## 🚀 Step-by-Step Deployment

### Phase 1: AWS Account Setup (30 minutes)

#### 1.1 Create AWS Account

```bash
# Sign up at: https://aws.amazon.com/
# Enable MFA (Multi-Factor Authentication) for root account
# Create IAM user for deployments
```

#### 1.2 Create IAM User for Deployment

```bash
# AWS Console → IAM → Users → Create User

User Name: deployment-user
Access Type: Programmatic access

Permissions:
- AmazonEC2FullAccess
- AmazonRDSFullAccess
- AmazonS3FullAccess
- AmazonVPCFullAccess
- ElastiCacheFullAccess
- CloudFrontFullAccess
- Route53FullAccess
- IAMFullAccess (for creating service roles)

# Download credentials.csv (contains Access Key ID and Secret)
```

#### 1.3 Configure AWS CLI Locally

```bash
# Install AWS CLI
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure
aws configure
# AWS Access Key ID: [from credentials.csv]
# AWS Secret Access Key: [from credentials.csv]
# Default region name: us-east-1
# Default output format: json

# Test
aws sts get-caller-identity
```

---

### Phase 2: Database Setup (RDS PostgreSQL) (45 minutes)

#### 2.1 Create VPC Security Group

```bash
# AWS Console → EC2 → Security Groups → Create Security Group

Name: ligamanager-db-sg
VPC: default (or custom)

Inbound Rules:
- Type: PostgreSQL
  Protocol: TCP
  Port: 5432
  Source: ligamanager-app-sg (will create next)
  Description: Allow from application servers

Outbound Rules:
- All traffic (default)
```

#### 2.2 Create RDS PostgreSQL Instance

```bash
# AWS Console → RDS → Create Database

Database Creation Method: Standard create

Engine Options:
- Engine: PostgreSQL
- Version: PostgreSQL 15.4

Templates: Production (or Free tier for testing)

Settings:
- DB instance identifier: ligamanager-db
- Master username: ligaadmin
- Master password: [Strong password - save in password manager]

Instance Configuration:
- DB instance class: db.t3.small (2 vCPU, 2GB RAM) - $50/month
- For dev/staging: db.t3.micro

Storage:
- Storage type: General Purpose SSD (gp3)
- Allocated storage: 20 GB
- Storage autoscaling: Enabled (max 100 GB)

Availability & durability:
- Multi-AZ deployment: Yes (for production)

Connectivity:
- VPC: default
- Subnet group: default
- Public access: No (access via EC2 only)
- VPC security group: ligamanager-db-sg
- Availability Zone: No preference

Database Authentication:
- Password authentication

Additional Configuration:
- Initial database name: ligamanager
- DB parameter group: default.postgres15
- Backup retention: 7 days
- Monitoring: Enable Enhanced Monitoring

# Wait 10-15 minutes for creation

# Note the endpoint: ligamanager-db.xxxxxxxxx.us-east-1.rds.amazonaws.com
```

#### 2.3 Connect and Initialize Database

```bash
# From your local machine (with psql installed)
# First, create SSH tunnel via EC2 bastion (skip if RDS is public)

# Or use AWS Systems Manager Session Manager
# Install session manager plugin first

# Direct connection (if public access enabled temporarily)
psql -h ligamanager-db.xxxxxxxxx.us-east-1.rds.amazonaws.com \
     -U ligaadmin \
     -d ligamanager

# Run initial setup
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For full-text search

# Create application role
CREATE ROLE app_role WITH LOGIN PASSWORD 'app_secure_password';
GRANT CREATE ON DATABASE ligamanager TO app_role;
GRANT USAGE ON SCHEMA public TO app_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_role;

\q
```

---

### Phase 3: ElastiCache Redis Setup (20 minutes)

#### 3.1 Create Redis Cluster

```bash
# AWS Console → ElastiCache → Redis → Create

Cluster Engine: Redis
Location: AWS Cloud

Cluster Info:
- Name: ligamanager-cache
- Engine version: 7.0
- Port: 6379
- Node type: cache.t3.micro (0.5GB) - $15/month
- Number of replicas: 0 (for MVP)

Subnet Group Settings:
- Create new subnet group
- VPC: default
- Subnets: Select 2+ subnets

Security:
- Security groups: Create new "ligamanager-redis-sg"
  Inbound: Port 6379 from ligamanager-app-sg
- Encryption at rest: Enabled
- Encryption in transit: Enabled

Backup:
- Enable automatic backups
- Retention: 1 day

# Wait 5-10 minutes for creation

# Note the endpoint: ligamanager-cache.xxxxxx.ng.0001.use1.cache.amazonaws.com
```

---

### Phase 4: EC2 Application Servers (60 minutes)

#### 4.1 Create Application Security Group

```bash
# AWS Console → EC2 → Security Groups → Create

Name: ligamanager-app-sg

Inbound Rules:
- Type: HTTP
  Port: 80
  Source: 0.0.0.0/0 (from ALB only - will restrict later)
  
- Type: HTTPS
  Port: 443
  Source: 0.0.0.0/0
  
- Type: Custom TCP
  Port: 8080
  Source: ALB security group
  Description: Spring Boot application

- Type: SSH
  Port: 22
  Source: My IP
  Description: SSH access

Outbound Rules:
- All traffic (allows connection to RDS, Redis, Internet)
```

#### 4.2 Create EC2 Key Pair

```bash
# AWS Console → EC2 → Key Pairs → Create Key Pair

Name: ligamanager-key
Type: RSA
Format: .pem

# Download ligamanager-key.pem
chmod 400 ~/Downloads/ligamanager-key.pem
```

#### 4.3 Launch EC2 Instance

```bash
# AWS Console → EC2 → Launch Instance

Name: ligamanager-app-1

AMI: Amazon Linux 2023 (free tier eligible)

Instance type: t3.medium (2 vCPU, 4GB RAM) - $30/month
For dev: t3.small

Key pair: ligamanager-key

Network settings:
- VPC: default
- Subnet: Same as RDS
- Auto-assign public IP: Enable
- Security group: ligamanager-app-sg

Storage: 20 GB gp3

Advanced details:
- IAM instance profile: (will create next)
- User data: (skip for now, configure manually)

# Launch instance
```

#### 4.4 Connect to EC2 and Install Dependencies

```bash
# Connect via SSH
ssh -i ~/Downloads/ligamanager-key.pem ec2-user@<public-ip>

# Update system
sudo yum update -y

# Install Java 21
sudo amazon-linux-extras enable corretto21
sudo yum install -y java-21-amazon-corretto-devel

# Verify
java -version

# Install Docker (for future containerization)
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Git
sudo yum install -y git

# Install Maven (for building if needed)
sudo wget https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo \
  -O /etc/yum.repos.d/epel-apache-maven.repo
sudo yum install -y apache-maven

# Create application directory
sudo mkdir -p /opt/ligamanager
sudo chown ec2-user:ec2-user /opt/ligamanager
```

---

### Phase 5: Application Deployment (45 minutes)

#### 5.1 Build Application Locally

```bash
# On your local machine
cd ~/projects/soccer-league-saas/backend

# Build JAR
mvn clean package -DskipTests

# JAR location: target/backend-0.0.1-SNAPSHOT.jar
```

#### 5.2 Upload to EC2

```bash
# Transfer JAR file
scp -i ~/Downloads/ligamanager-key.pem \
    target/backend-0.0.1-SNAPSHOT.jar \
    ec2-user@<public-ip>:/opt/ligamanager/app.jar
```

#### 5.3 Create Environment Configuration

```bash
# On EC2 instance
cat > /opt/ligamanager/.env << 'EOF'
# Database
DB_HOST=ligamanager-db.xxxxxxxxx.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=ligamanager
DB_USERNAME=app_role
DB_PASSWORD=app_secure_password

# Redis
REDIS_HOST=ligamanager-cache.xxxxxx.use1.cache.amazonaws.com
REDIS_PORT=6379

# JWT
JWT_SECRET=your-256-bit-secret-key-here-change-this

# AWS S3 (for file uploads)
AWS_S3_BUCKET=ligamanager-uploads
AWS_REGION=us-east-1

# Application
SPRING_PROFILES_ACTIVE=production
SERVER_PORT=8080
EOF

# Secure the file
chmod 600 /opt/ligamanager/.env
```

#### 5.4 Create Systemd Service

```bash
# Create service file
sudo nano /etc/systemd/system/ligamanager.service
```

```ini
[Unit]
Description=Liga Manager Spring Boot Application
After=syslog.target network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/ligamanager
EnvironmentFile=/opt/ligamanager/.env
ExecStart=/usr/bin/java \
  -Xms512m \
  -Xmx1024m \
  -Dspring.profiles.active=production \
  -jar /opt/ligamanager/app.jar

SuccessExitStatus=143
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ligamanager
sudo systemctl start ligamanager

# Check status
sudo systemctl status ligamanager

# View logs
sudo journalctl -u ligamanager -f
```

#### 5.5 Verify Application

```bash
# Test health endpoint
curl http://localhost:8080/api/v1/actuator/health

# Expected response:
# {"status":"UP"}
```

---

### Phase 6: Load Balancer & SSL (45 minutes)

#### 6.1 Request SSL Certificate (AWS Certificate Manager)

```bash
# AWS Console → Certificate Manager → Request Certificate

Certificate type: Public certificate

Domain names:
- api.ligamanager.com
- *.api.ligamanager.com  (wildcard for multi-tenancy)

Validation method: DNS validation

# ACM will provide CNAME records
# Add these records to Route 53 (or your DNS provider)

# Wait for validation (5-30 minutes)
```

#### 6.2 Create Target Group

```bash
# AWS Console → EC2 → Target Groups → Create Target Group

Target type: Instances

Target group name: ligamanager-tg

Protocol: HTTP
Port: 8080
VPC: default

Health check:
- Protocol: HTTP
- Path: /api/v1/actuator/health
- Port: 8080
- Healthy threshold: 2
- Unhealthy threshold: 3
- Timeout: 5 seconds
- Interval: 30 seconds

# Register targets: Select ligamanager-app-1
# Create target group
```

#### 6.3 Create Application Load Balancer

```bash
# AWS Console → EC2 → Load Balancers → Create Load Balancer

Type: Application Load Balancer

Name: ligamanager-alb

Scheme: Internet-facing
IP address type: IPv4

Network mapping:
- VPC: default
- Availability Zones: Select 2+ zones

Security groups:
- Create new: ligamanager-alb-sg
  Inbound: HTTP (80), HTTPS (443) from 0.0.0.0/0

Listeners:
1. HTTP:80 → Redirect to HTTPS
2. HTTPS:443 → Forward to ligamanager-tg
   - SSL certificate: Select from ACM

# Create load balancer

# Wait 5 minutes for provisioning
# Note the DNS name: ligamanager-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com
```

---

### Phase 7: DNS Configuration (Route 53) (30 minutes)

#### 7.1 Create Hosted Zone

```bash
# AWS Console → Route 53 → Hosted Zones → Create Hosted Zone

Domain name: ligamanager.com
Type: Public hosted zone

# Create hosted zone
# Note the 4 NS (nameserver) records

# Go to your domain registrar (GoDaddy, Namecheap, etc.)
# Update nameservers to AWS Route 53 NS records
# Wait 24-48 hours for DNS propagation (usually faster)
```

#### 7.2 Create DNS Records

```bash
# AWS Console → Route 53 → Hosted Zones → ligamanager.com

# Create Record for API subdomain
Record name: api
Record type: A - IPv4 address
Value: Alias to Application Load Balancer
  - Select ligamanager-alb
Routing policy: Simple routing

# Create wildcard record for multi-tenancy
Record name: *.api
Record type: A - IPv4 address
Value: Alias to Application Load Balancer
  - Select ligamanager-alb

# Test DNS
dig api.ligamanager.com
dig canchas-xyz.api.ligamanager.com
```

---

### Phase 8: S3 & CloudFront (Frontend) (45 minutes)

#### 8.1 Create S3 Bucket for Frontend

```bash
# AWS Console → S3 → Create Bucket

Bucket name: ligamanager-frontend
Region: us-east-1

Block all public access: UNCHECKED (we'll use CloudFront)

Bucket versioning: Enable
Default encryption: Enable (SSE-S3)

# Create bucket
```

#### 8.2 Enable Static Website Hosting

```bash
# Bucket → Properties → Static website hosting → Edit

Enable: Yes
Hosting type: Host a static website
Index document: index.html
Error document: index.html  (for SPA routing)

# Save
```

#### 8.3 Create Bucket Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::ligamanager-frontend/*"
    }
  ]
}
```

#### 8.4 Create CloudFront Distribution

```bash
# AWS Console → CloudFront → Create Distribution

Origin:
- Origin domain: ligamanager-frontend.s3.us-east-1.amazonaws.com
- Origin path: (leave empty)
- S3 bucket access: Yes, use OAI (create new)

Default cache behavior:
- Viewer protocol policy: Redirect HTTP to HTTPS
- Allowed HTTP methods: GET, HEAD, OPTIONS
- Cache policy: CachingOptimized

Settings:
- Alternate domain names (CNAMEs): app.ligamanager.com
- Custom SSL certificate: Select from ACM
- Default root object: index.html

# Create distribution
# Wait 10-15 minutes for deployment

# Note CloudFront domain: d1234abcd.cloudfront.net
```

**Note**: Next.js 15 builds are optimized for static export. Make sure to configure `next.config.js` for static export if not using Next.js server features.

#### 8.5 Update Route 53 for Frontend

```bash
# Route 53 → ligamanager.com → Create Record

Record name: app
Type: A - IPv4 address
Value: Alias to CloudFront distribution
  - Select d1234abcd.cloudfront.net

# Create record
```

---

### Phase 9: CI/CD Pipeline (GitHub Actions) (30 minutes)

#### 9.1 Store AWS Credentials in GitHub Secrets

```bash
# GitHub → Repository → Settings → Secrets → Actions

Add secrets:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION (us-east-1)
- EC2_HOST (public IP or DNS)
- EC2_USERNAME (ec2-user)
- EC2_SSH_KEY (contents of ligamanager-key.pem)
- S3_BUCKET (ligamanager-frontend)
```

#### 9.2 Create GitHub Actions Workflow

```yaml
# .github/workflows/deploy-backend.yml
name: Deploy Backend to AWS EC2

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 21
        uses: actions/setup-java@v3
        with:
          java-version: '21'
          distribution: 'corretto'
      
      - name: Build with Maven
        working-directory: ./backend
        run: mvn clean package -DskipTests
      
      - name: Deploy to EC2
        env:
          PRIVATE_KEY: ${{ secrets.EC2_SSH_KEY }}
          HOST: ${{ secrets.EC2_HOST }}
          USER: ${{ secrets.EC2_USERNAME }}
        run: |
          echo "$PRIVATE_KEY" > private_key.pem
          chmod 600 private_key.pem
          
          scp -i private_key.pem -o StrictHostKeyChecking=no \
            backend/target/*.jar $USER@$HOST:/opt/ligamanager/app.jar
          
          ssh -i private_key.pem -o StrictHostKeyChecking=no $USER@$HOST \
            'sudo systemctl restart ligamanager'
          
          rm private_key.pem
```

```yaml
# .github/workflows/deploy-frontend.yml
name: Deploy Frontend to S3/CloudFront

on:
  push:
    branches: [main]
    paths:
      - 'frontend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci
      
      - name: Build
        working-directory: ./frontend
        run: npm run build
        env:
          NEXT_PUBLIC_API_URL: https://api.ligamanager.com/v1
      
      - name: Deploy to S3
        uses: jakejarvis/s3-sync-action@master
        with:
          args: --delete
        env:
          AWS_S3_BUCKET: ${{ secrets.S3_BUCKET }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ secrets.AWS_REGION }}
          SOURCE_DIR: 'frontend/out'
      
      - name: Invalidate CloudFront Cache
        run: |
          aws cloudfront create-invalidation \
            --distribution-id E1234ABCD \
            --paths "/*"
```

---

### Phase 10: Monitoring & Alerts (30 minutes)

#### 10.1 Configure CloudWatch Alarms

```bash
# AWS Console → CloudWatch → Alarms → Create Alarm

Alarm 1: High CPU Usage
- Metric: EC2 → CPUUtilization
- Instance: ligamanager-app-1
- Threshold: > 80% for 5 minutes
- Action: Send SNS notification

Alarm 2: RDS Storage
- Metric: RDS → FreeStorageSpace
- Instance: ligamanager-db
- Threshold: < 5 GB
- Action: Send SNS notification

Alarm 3: Application Errors
- Metric: ALB → HTTPCode_Target_5XX_Count
- Threshold: > 10 in 5 minutes
- Action: Send SNS notification
```

#### 10.2 Set Up Log Aggregation

```bash
# Install CloudWatch Agent on EC2
sudo yum install -y amazon-cloudwatch-agent

# Configure agent
sudo nano /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/ligamanager/application.log",
            "log_group_name": "/aws/ec2/ligamanager",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

---

## ✅ Post-Deployment Checklist

- [ ] Application accessible at https://api.ligamanager.com/v1/actuator/health
- [ ] Frontend accessible at https://app.ligamanager.com
- [ ] SSL certificates valid (no browser warnings)
- [ ] Can create tenant account via signup
- [ ] Database migrations applied successfully
- [ ] Redis cache working (check with test key)
- [ ] CloudWatch alarms configured
- [ ] Backup retention policies set
- [ ] Security groups properly restricted
- [ ] IAM roles follow least privilege
- [ ] Cost explorer enabled (monitor spending)

---

## 💰 Monthly Cost Breakdown

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| EC2 (t3.medium) | 2 vCPU, 4GB RAM | $30 |
| RDS PostgreSQL (db.t3.small) | Multi-AZ | $50 |
| ElastiCache Redis (t3.micro) | Single node | $15 |
| S3 | Storage + transfer | $5 |
| CloudFront | CDN | $10 |
| Route 53 | Hosted zone + queries | $5 |
| Application Load Balancer | 24/7 | $25 |
| Data Transfer | ~100GB/month | $10 |
| **Total** | | **~$150/month** |

**Scaling Costs (100+ tenants):**
- EC2: t3.large (2 instances) = $120
- RDS: db.t3.medium = $130
- ElastiCache: t3.small (replica) = $50
- **Total: ~$450/month**

---

## 🔧 Maintenance Tasks

### Weekly
- [ ] Check CloudWatch alarms
- [ ] Review error logs
- [ ] Monitor disk usage

### Monthly
- [ ] Update OS packages: `sudo yum update -y`
- [ ] Review AWS costs
- [ ] Test backups (restore to staging)
- [ ] Rotate database passwords

### Quarterly
- [ ] Update Java version
- [ ] Review security groups
- [ ] Optimize database (VACUUM)
- [ ] Archive old data

---

## 🆘 Troubleshooting

### Application Won't Start

```bash
# Check logs
sudo journalctl -u ligamanager -n 50

# Common issues:
# 1. Wrong database credentials → Check .env file
# 2. Can't connect to RDS → Check security groups
# 3. Port 8080 in use → killall java; systemctl restart ligamanager
```

### High Latency

```bash
# Check database connections
psql -h <RDS-endpoint> -U ligaadmin -d ligamanager -c "SELECT count(*) FROM pg_stat_activity;"

# Check Redis
redis-cli -h <redis-endpoint> PING

# Check ALB target health
# AWS Console → EC2 → Target Groups → ligamanager-tg
```

### SSL Certificate Issues

```bash
# Verify certificate
openssl s_client -connect api.ligamanager.com:443

# Check DNS
dig api.ligamanager.com

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id E1234 --paths "/*"
```

---

## 📚 Additional Resources

- **AWS Well-Architected Framework**: https://aws.amazon.com/architecture/well-architected/
- **Spring Boot on AWS**: https://spring.io/guides/gs/spring-boot-aws/
- **AWS Free Tier**: https://aws.amazon.com/free/

---

*Deployment Guide Last Updated: January 2025*
