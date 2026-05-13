#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "===== Starting Jenkins setup at $(date) ====="

# ----------------------------
# Wait for network
# ----------------------------
sleep 120

echo "Updating system..."

# Retry yum update (important for cloud-init timing)
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
# Install Java 21
# ----------------------------
echo "Installing Java 21..."

cd /opt
curl -LO https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz
tar -xzf amazon-corretto-21-x64-linux-jdk.tar.gz
mv amazon-corretto-21.* /opt/java21

echo "✅ Java installed at /opt/java21"

# ----------------------------
# Install Jenkins
# ----------------------------
echo "Installing Jenkins..."

# Clean old repo (important)
rm -f /etc/yum.repos.d/jenkins.repo

# Correct repo config
cat <<EOF > /etc/yum.repos.d/jenkins.repo
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
enabled=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
EOF

# Import correct GPG key
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins with retry + fallback
for i in {1..3}; do
  yum install -y jenkins && break || sleep 20
done

# Fallback if needed (ensures install always succeeds)
if ! rpm -qa | grep -q jenkins; then
  echo "Retrying Jenkins install without GPG check..."
  yum install -y jenkins --nogpgcheck
fi

# Verify installation
if rpm -qa | grep -q jenkins; then
  echo "✅ Jenkins installed successfully"
else
  echo "❌ Jenkins installation FAILED"
  exit 1
fi

# ----------------------------
# Configure Jenkins to use Java 21
# ----------------------------
echo "Configuring Jenkins..."

cat <<EOF > /etc/sysconfig/jenkins
JAVA_HOME=/opt/java21
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true"
EOF

mkdir -p /etc/systemd/system/jenkins.service.d

cat <<EOF > /etc/systemd/system/jenkins.service.d/override.conf
[Service]
Environment="JAVA_HOME=/opt/java21"
EOF

# ----------------------------
# Start Jenkins
# ----------------------------
echo "Starting Jenkins..."

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
sleep 20

# Verify service
if systemctl is-active --quiet jenkins; then
