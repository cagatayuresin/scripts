#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/security-setup.log"
echo -e "${BLUE}Ubuntu Server Security Setup Script Started at: $(date)${NC}" | tee -a $LOG_FILE

# Function to check if the last command was successful
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$1 completed successfully.${NC}" | tee -a $LOG_FILE
    else
        echo -e "${RED}$1 failed.${NC}" | tee -a $LOG_FILE
        exit 1
    fi
}

# 1. Update and upgrade system packages
echo -e "${YELLOW}Updating and upgrading system packages...${NC}" | tee -a $LOG_FILE
sudo apt update -y && sudo apt upgrade -y
check_success "System update and upgrade"

# 2. Install necessary security tools and packages
echo -e "${YELLOW}Installing necessary packages (UFW, Fail2Ban, unattended-upgrades, curl)...${NC}" | tee -a $LOG_FILE
sudo apt install -y ufw fail2ban unattended-upgrades curl
check_success "Package installation"

# 3. Configure Uncomplicated Firewall (UFW)
echo -e "${YELLOW}Configuring UFW...${NC}" | tee -a $LOG_FILE
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw --force enable
check_success "UFW configuration"

# 4. SSH Hardening: Disable password authentication and enable key-based login
echo -e "${YELLOW}Hardening SSH configuration...${NC}" | tee -a $LOG_FILE
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload sshd
check_success "SSH hardening"

# 5. Fail2Ban configuration: Protect SSH and common services from brute-force attacks
echo -e "${YELLOW}Configuring Fail2Ban...${NC}" | tee -a $LOG_FILE
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOL
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 3600
EOL
sudo systemctl restart fail2ban
check_success "Fail2Ban configuration"

# 6. Enable automatic security updates (unattended-upgrades)
echo -e "${YELLOW}Enabling automatic security updates...${NC}" | tee -a $LOG_FILE
sudo dpkg-reconfigure --priority=low unattended-upgrades
check_success "Automatic security updates"

# 7. Disable unused services and ports (optional, but highly recommended)
echo -e "${YELLOW}Disabling unused services...${NC}" | tee -a $LOG_FILE
sudo systemctl disable avahi-daemon
sudo systemctl stop avahi-daemon
check_success "Unused services disabled"

# 8. Install and configure Fail2Ban (prevent brute-force attacks)
echo -e "${YELLOW}Securing Fail2Ban for SSH...${NC}" | tee -a $LOG_FILE
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOL
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 600
EOL
sudo systemctl restart fail2ban
check_success "Fail2Ban configuration"

# 9. Disable root login over SSH
echo -e "${YELLOW}Disabling root login over SSH...${NC}" | tee -a $LOG_FILE
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload sshd
check_success "Root login disabled over SSH"

# 10. Create a new non-root user with sudo privileges
echo -e "${YELLOW}Creating a new user with sudo privileges...${NC}" | tee -a $LOG_FILE
read -p "Enter the username for the new user: " username
sudo adduser $username
sudo usermod -aG sudo $username
check_success "New user $username created"

# 11. Set up SSH key-based login for the new user
echo -e "${YELLOW}Setting up SSH key-based login for the new user...${NC}" | tee -a $LOG_FILE

## Step 1: Generate SSH key pair on the client side (this step should be done on your local machine)
## ssh-keygen -t rsa -b 4096

## Step 2: Copy the public key to the server
read -p "Please provide the public SSH key to set up for the new user: " public_key
sudo mkdir -p /home/$username/.ssh
echo $public_key | sudo tee -a /home/$username/.ssh/authorized_keys
sudo chown -R $username:$username /home/$username/.ssh
sudo chmod 700 /home/$username/.ssh
sudo chmod 600 /home/$username/.ssh/authorized_keys
check_success "SSH key-based login setup for user $username"


# 12. Final cleanup
echo -e "${YELLOW}Performing final cleanup...${NC}" | tee -a $LOG_FILE
sudo apt autoremove -y && sudo apt autoclean -y
check_success "Final cleanup"

# 13. Disable ICMP (ping) responses
echo -e "${YELLOW}Disabling ICMP (ping) responses...${NC}" | tee -a $LOG_FILE
sudo sysctl -w net.ipv4.icmp_echo_ignore_all=1
echo "net.ipv4.icmp_echo_ignore_all = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
check_success "Ping responses disabled"

# Completion message
echo -e "${GREEN}Security setup completed successfully at: $(date)${NC}" | tee -a $LOG_FILE
