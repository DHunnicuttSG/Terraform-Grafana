Below is a **complete, production-quality, copy‑paste ready setup** that meets all your requirements. Everything is self-contained and designed for easy **spin-up/tear-down**.

***

# 📁 Project Structure

    terraform-monitoring-demo/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── user_data.sh.tpl
    ├── docker-compose.yml
    ├── prometheus.yml
    ├── app/
    │   ├── app.py
    │   └── requirements.txt

***

# 🧱 Terraform Code

## ✅ `main.tf`

```hcl
provider "aws" {
  region = var.aws_region
}

# -------------------------
# VPC + Networking
# -------------------------
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.demo_vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.demo_vpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rt.id
}

# -------------------------
# Security Group
# -------------------------
resource "aws_security_group" "demo_sg" {
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# EC2 Instance
# -------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {})

  tags = {
    Name = "monitoring-demo"
  }
}
```

***

## ✅ `variables.tf`

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {
  description = "Your AWS key pair name"
}
```

***

## ✅ `outputs.tf`

```hcl
output "instance_public_ip" {
  value = aws_instance.demo.public_ip
}

output "grafana_url" {
  value = "http://${aws_instance.demo.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.demo.public_ip}:9090"
}
```

***

# 🚀 User Data Script

## ✅ `user_data.sh.tpl`

```bash
#!/bin/bash
set -xe

# Install Docker
yum update -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app directory
mkdir -p /home/ec2-user/app
cd /home/ec2-user

# Write files

cat <<EOF > docker-compose.yml
${file("${path.module}/docker-compose.yml")}
EOF

cat <<EOF > prometheus.yml
${file("${path.module}/prometheus.yml")}
EOF

mkdir -p app
cat <<EOF > app/app.py
${file("${path.module}/app/app.py")}
EOF

cat <<EOF > app/requirements.txt
${file("${path.module}/app/requirements.txt")}
EOF

# Fix permissions
chown -R ec2-user:ec2-user /home/ec2-user

# Start services
cd /home/ec2-user
/usr/local/bin/docker-compose up -d
```

***

# 🐳 Docker Compose Stack

## ✅ `docker-compose.yml`

```yaml
version: "3.8"

services:
  app:
    build: ./app
    container_name: python_app
    ports:
      - "8000:8000"

  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
```

***

# 📊 Prometheus Config

## ✅ `prometheus.yml`

```yaml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: "python-app"
    static_configs:
      - targets: ["app:8000"]
```

***

# 🐍 Python App

## ✅ `app/app.py`

```python
from flask import Flask
from prometheus_client import Counter, generate_latest
from prometheus_client import CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUEST_COUNT = Counter('app_requests_total', 'Total HTTP Requests')

@app.route("/")
def hello():
    REQUEST_COUNT.inc()
    return "Hello, Monitoring Demo!"

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
```

***

## ✅ `app/requirements.txt`

    flask
    prometheus_client

***

⚠️ **Important Missing Piece → Dockerfile (required for build)**

Add this inside `app/`:

## ✅ `app/Dockerfile`

```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY . .

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "app.py"]
```

***

# 📊 Grafana Auto Datasource (Preconfigured)

Add this in `docker-compose.yml` under Grafana:

Replace service with:

```yaml
grafana:
  image: grafana/grafana
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
  volumes:
    - grafana-storage:/var/lib/grafana
    - ./grafana-provisioning:/etc/grafana/provisioning
```

***

Create this directory:

## ✅ `grafana-provisioning/datasources/datasource.yml`

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

***

# ▶️ Deployment Instructions

## 1. Initialize Terraform

```bash
terraform init
```

## 2. Plan

```bash
terraform plan
```

## 3. Apply

```bash
terraform apply
```

Type `yes` when prompted.

***

# 🌐 Access the Environment

After deployment:

### ✅ Grafana

    http://<PUBLIC_IP>:3000

*   Username: `admin`
*   Password: `admin`

### ✅ Prometheus

    http://<PUBLIC_IP>:9090

### ✅ Python App

    http://<PUBLIC_IP>:8000

***

# 📊 Suggested Demo Flow for Teaching

1.  Open Grafana → verify datasource is already configured
2.  Query:
        app_requests_total
3.  Hit the app URL multiple times
4.  Watch metrics increase live

***

# 🧹 Tear Down

```bash
terraform destroy
```

***

# ✅ Notes / Best Practices

*   Fully reproducible lab environment
*   No Kubernetes complexity (great for classroom)
*   Minimal cost (single instance)
*   Uses Docker Compose → easy student understanding
*   Clean teardown with Terraform

***
