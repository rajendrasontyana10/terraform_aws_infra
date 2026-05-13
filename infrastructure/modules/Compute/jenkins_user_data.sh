#!/bin/bash
set -e

# Log output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


#Sleep 120
sleep 120

# Update system
yum update -y

# Tools
yum install -y curl unzip

# ----------------------------
# Install Java 21 (Amazon Corretto)
# ----------------------------
cd /opt
curl -LO https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz
tar -xzf amazon-corretto-21-x64-linux-jdk.tar.gz
mv amazon-corretto-21.* /opt/java21

# ----------------------------
# Install Jenkins
# ----------------------------
cat <<EOF > /etc/yum.repos.d/jenkins.repo
[jenkins]
name=Jenkins LTS
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io.key
enabled=1
EOF

rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum install -y jenkins

# ----------------------------
# Force Jenkins to use Java 21
# ----------------------------
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
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins