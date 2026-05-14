#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "===== Starting Jenkins setup at $(date) ====="

# Wait for network
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
# Install Java 17 (✅ FIXED)
# ----------------------------
echo "Installing Java 17..."

yum install -y java-17-amazon-corretto

java -version
echo "✅ Java 17 installed"

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

# Install Jenkins (with retry)
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

# Wait until port opens
echo "Waiting for Jenkins to become available..."

for i in {1..20}; do
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