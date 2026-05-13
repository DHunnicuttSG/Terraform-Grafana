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
