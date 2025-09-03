#!/bin/bash
yum update -y

# Install Java 17
yum install -y java-17-amazon-corretto-devel

# Install Maven
yum install -y maven

# Install Git
yum install -y git

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Create application directory
mkdir -p /home/ec2-user/sagemaker-async-app
chown ec2-user:ec2-user /home/ec2-user/sagemaker-async-app

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto' >> /home/ec2-user/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /home/ec2-user/.bashrc

# Create systemd service for Spring Boot
cat > /etc/systemd/system/sagemaker-app.service << 'EOF'
[Unit]
Description=SageMaker Async Spring Boot App
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/sagemaker-async-app
ExecStart=/usr/bin/java -jar target/sagemaker-async-app-1.0.0.jar
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sagemaker-app
