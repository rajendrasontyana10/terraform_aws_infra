#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Jenkins setup at $(date)"

# Wait for network stabilization
sleep 120

echo "Updating system and installing dependencies..."

# Retry yum update (fix cloud-init timing issue)
for i in {1..5}; do
  yum clean all
  yum update -y && break || sleep 20
done

# Tools
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
echo "Terraform installed successfully"

# ----------------------------
# Install Java 21 (Amazon Corretto)
# ----------------------------
echo "Installing Java 21..."

cd /opt
curl -LO https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz
tar -xzf amazon-corretto-21-x64-linux-jdk.tar.gz
mv amazon-corretto-21.* /opt/java21

echo "Java 21 installed at /opt/java21"

# ----------------------------
# Install Jenkins (FIXED)
# ----------------------------
echo "Installing Jenkins..."

# Remove old repo if exists
rm -f /etc/yum.repos.d/jenkins.repo

# ✅ FIXED: Correct key
cat <<EOF > /etc/yum.repos.d/jenkins.repo
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
enabled=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
EOF

# ✅ Import correct key
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Retry install
for i in {1..3}; do
  yum install -y jenkins && break || sleep 20
done

echo "Jenkins installed successfully"

# ----------------------------
# Configure Jenkins to use Java 21
# ----------------------------
echo "Configuring Jenkins with Java 21..."

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

echo "Jenkins setup completed at $(date)"
``