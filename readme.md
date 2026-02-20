# Three-Tier Web Application on AWS

A production-grade three-tier web application deployed on AWS using **Terraform**, featuring physically separated presentation, application, and database tiers with load balancing, auto scaling, and defense-in-depth security.

## Architecture

![System Architecture](system_arch.png)

## Traffic Flow

```
User → External ALB → Nginx (serves HTML, proxies /api/) → Internal ALB → Flask (REST API) → RDS MySQL
```

## AWS Services Used

| Service | Purpose |
|---------|---------|
| **VPC** | Isolated network with 8 subnets across 2 AZs |
| **EC2** | Nginx web servers + Flask API servers |
| **ALB** | External (internet-facing) + Internal (private) load balancers |
| **Auto Scaling** | Maintains 2 instances per tier, scales to 4 on CPU threshold |
| **RDS MySQL** | Managed database in isolated private subnets |
| **NAT Gateway** | Outbound internet for private instances |
| **IAM** | EC2 role for Systems Manager access |
| **Security Groups** | 5 chained SGs enforcing defense-in-depth |

## Security Design

```
Internet → [ext-alb-sg: 80/443] → External ALB
  → [web-sg: 80 from ext-alb-sg] → Nginx
    → [int-alb-sg: 80 from web-sg] → Internal ALB
      → [app-sg: 5000 from int-alb-sg] → Flask
        → [db-sg: 3306 from app-sg] → RDS MySQL
```

- All EC2 instances in **private subnets** — no public IPs
- Each tier communicates **only with its adjacent tier**
- Database accessible **only from the app tier**

## Tech Stack

| Tier | Technology |
|------|-----------|
| Presentation | Nginx, HTML/CSS/JavaScript |
| Application | Python Flask, Gunicorn |
| Database | Amazon RDS MySQL 8.0 |
| Infrastructure | Terraform |

## Project Structure

```
three-tier-terraform/
├── main.tf              # Provider config, data sources
├── variables.tf         # Input variables
├── terraform.tfvars     # Variable values (gitignored — contains secrets)
├── vpc.tf               # VPC, subnets, routing, NAT gateway
├── security.tf          # Security groups, IAM role
├── rds.tf               # RDS MySQL instance
├── loadbalancers.tf     # External + Internal ALBs, target groups
├── app-tier.tf          # Flask launch template + ASG
├── web-tier.tf          # Nginx launch template + ASG
├── outputs.tf           # Output values (URLs, endpoints)
├── .gitignore           # Excludes state files and secrets
└── README.md            # This file
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- AWS account with permissions for VPC, EC2, RDS, ELB, IAM

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/three-tier-terraform.git
cd three-tier-terraform
```

### 2. Create your variables file

```bash
cat <<EOF > terraform.tfvars
db_password = "your-secure-password"
EOF
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (type "yes" when prompted)
terraform apply
```

### 4. Access the application

After deployment completes (~10 minutes), Terraform outputs the URL:

```
Outputs:

app_url = "http://three-tier-ext-alb-xxxxx.us-east-1.elb.amazonaws.com"
```

Open the URL in your browser to use the Task Manager.

### 5. Destroy

```bash
# Delete all resources (type "yes" when prompted)
terraform destroy
```

## Application Features

- **Create** tasks with the input form
- **Read** all tasks with timestamps
- **Update** task status (mark as complete)
- **Delete** tasks
- Data persists in RDS — refresh and tasks remain
- Refresh page to see different web instance IDs (load balancing proof)

## Key Design Decisions

- **Separate Web & App Tiers**: Enables independent scaling — web tier scales for static content, app tier scales for API compute
- **Dual Load Balancers**: Internal ALB isolates the app tier completely — never directly exposed
- **Private Subnets**: Zero public exposure for EC2 instances — inbound only through ALB
- **Security Group Chaining**: Each SG references the previous tier's SG as source, not CIDR blocks
- **Stateless Instances**: All state in RDS — instances can be replaced without data loss

## Production Improvements

- [ ] HTTPS with ACM certificates
- [ ] Multi-AZ RDS for automatic failover
- [ ] CloudFront CDN for edge caching
- [ ] S3 for static asset hosting
- [ ] ElastiCache (Redis) for API caching
- [ ] AWS WAF on external ALB
- [ ] Secrets Manager for database credentials
- [ ] CloudWatch alarms + SNS notifications
- [ ] CI/CD pipeline with CodePipeline
- [ ] Terraform remote state in S3 with DynamoDB locking

## Cost Estimate

Running this architecture costs approximately **$3-5/hour** (mainly NAT Gateway + RDS + EC2 instances). Always run `terraform destroy` when not in use.

## Author

**Srinivasa Rithik Ghantasala**  
MS Information Systems, Northeastern University  
[LinkedIn](https://linkedin.com/in/yourprofile) | [GitHub](https://github.com/yourusername)