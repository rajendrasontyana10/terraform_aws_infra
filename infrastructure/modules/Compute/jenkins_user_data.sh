#!/bin/bash
set -euo pipefail

# Log everything
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "===== Starting Jenkins setup at $(date) ====="

# ----------------------------
# Add swap (CRITICAL)
# ----------------------------
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Make swap permanent
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

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

# ----------------------------
# Install required tools + fonts
# ----------------------------
yum install -y curl unzip wget fontconfig dejavu-sans-fonts nc

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
wget https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz
tar -xzf amazon-corretto-21-x64-linux-jdk.tar.gz
mv amazon-corretto-21.* /opt/java21

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
name=Jenkins
baseurl=https://pkg.jenkins.io/redhat-stable
enabled=1
gpgcheck=0
EOF

yum install -y jenkins

if rpm -qa | grep -q jenkins; then
  echo "✅ Jenkins installed"
else
  echo "❌ Jenkins install failed"
  exit 1
fi

# ----------------------------
# Prepare Jenkins home
# ----------------------------
mkdir -p /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins

# Disable setup wizard (no plugin hang)
echo "2.0" > /var/lib/jenkins/jenkins.install.UpgradeWizard.state

mkdir -p /var/lib/jenkins/init.groovy.d

cat <<EOF > /var/lib/jenkins/init.groovy.d/basic-security.groovy
import jenkins.model.*
Jenkins.instance.setInstallState(jenkins.install.InstallState.INITIAL_SETUP_COMPLETED)
EOF

chown -R jenkins:jenkins /var/lib/jenkins

# ----------------------------
# SYSTEMD FIXES (🔥 IMPORTANT)
# ----------------------------
mkdir -p /etc/systemd/system/jenkins.service.d

cat <<EOF > /etc/systemd/system/jenkins.service.d/override.conf
[Service]
TimeoutStartSec=600
Environment="JENKINS_OPTS=--httpPort=8080 --httpListenAddress=0.0.0.0"
EOF

# ----------------------------
# Start Jenkins
# ----------------------------
echo "Starting Jenkins..."

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# ----------------------------
# Wait for Jenkins to be ready
# ----------------------------
echo "Waiting for Jenkins to become available..."

for i in {1..40}; do
  if nc -z localhost 8080; then
    echo "✅ Jenkins is up on port 8080"
    break
  fi
  echo "Waiting for Jenkins..."
  sleep 10
done

# ----------------------------
# Final verification
# ----------------------------
if systemctl is-active --quiet jenkins; then
  echo "✅ Jenkins service is running"
else
  echo "❌ Jenkins service failed"
  exit 1
fi

echo "===== Jenkins setup completed at $(date) ====="