#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "===== Starting Jenkins setup at $(date) ====="

# ----------------------------
# Add swap (CRITICAL for Jenkins)
# ----------------------------
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# ----------------------------
# Wait for network
# ----------------------------
sleep 120

echo "Updating system..."

# Retry yum update
for i in {1..5}; do
  yum clean all
  yum update -y && break || sleep 20
done

# Install tools
yum install -y curl unzip wget

# ----------------------------
# Install Terraform
# ----------------------------
echo "Installing Terraform..."

cd /tmp
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip -o terraform_1.6.6_linux_amd64.zip
mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform

terraform -version
echo "✅ Terraform installed"

# ----------------------------
# Install Java 21 (✅ FIXED)
# ----------------------------
echo "Installing Java 21..."

cd /opt
wget https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz
tar -xzf amazon-corretto-21-x64-linux-jdk.tar.gz
mv amazon-corretto-21.* /opt/java21

# Set Java 21 as default (IMPORTANT)
alternatives --install /usr/bin/java java /opt/java21/bin/java 1
alternatives --set java /opt/java21/bin/java

java -version
echo "✅ Java 21 installed"

# ----------------------------
# Install Jenkins
# ----------------------------
echo "Installing Jenkins..."

rm -f /etc/yum.repos.d/jenkins.repo

cat <<EOF > /etc/yum.repos.d/jenkins.repo
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
enabled=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
EOF

rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins (retry)
for i in {1..3}; do
  yum install -y jenkins && break || sleep 20
done

# Fallback
if ! rpm -qa | grep -q jenkins; then
  echo "Retrying Jenkins install without GPG check..."
  yum install -y jenkins --nogpgcheck
fi

# Verify
if rpm -qa | grep -q jenkins; then
  echo "✅ Jenkins installed"
else
  echo "❌ Jenkins install failed"
  exit 1
fi

# ----------------------------
# Start Jenkins
# ----------------------------
echo "Starting Jenkins..."

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait until Jenkins is ready
echo "Waiting for Jenkins to become available..."

for i in {1..30}; do
  if nc -z localhost 8080; then
    echo "✅ Jenkins is up on port 8080"
    break
  fi
  echo "Waiting for Jenkins..."
  sleep 10
done

# Final verification
if systemctl is-active --quiet jenkins; then
  echo "✅ Jenkins service is running"
else
  echo "❌ Jenkins service failed"
  exit 1
fi

echo "===== Jenkins setup completed at $(date) ====="