#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timestamp for log file
LOG_FILE="/var/log/after.log"
echo -e "${BLUE}Setup script started at: $(date)${NC}" | tee -a $LOG_FILE

# Update package list and upgrade packages
echo -e "${YELLOW}Updating package list and upgrading packages...${NC}" | tee -a $LOG_FILE
sudo apt update -y && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Package list updated and packages upgraded successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to update or upgrade packages.${NC}" | tee -a $LOG_FILE
fi

# Remove unnecessary packages
echo -e "${YELLOW}Removing unnecessary packages...${NC}" | tee -a $LOG_FILE
sudo apt autoremove -y
sudo apt autoclean -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Unnecessary packages removed.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to remove unnecessary packages.${NC}" | tee -a $LOG_FILE
fi

# Install necessary packages
echo -e "${YELLOW}Installing necessary packages...${NC}" | tee -a $LOG_FILE
sudo apt install -y curl wget git build-essential ufw
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Necessary packages installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install necessary packages.${NC}" | tee -a $LOG_FILE
fi

# OpenSSH installation and configuration
echo -e "${YELLOW}Installing and configuring OpenSSH...${NC}" | tee -a $LOG_FILE
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OpenSSH installed and configured successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install or configure OpenSSH.${NC}" | tee -a $LOG_FILE
fi

# Configure UFW
echo -e "${YELLOW}Configuring UFW (Uncomplicated Firewall)...${NC}" | tee -a $LOG_FILE
sudo ufw allow OpenSSH
sudo ufw --force enable
if [ $? -eq 0 ]; then
    echo -e "${GREEN}UFW configured successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to configure UFW.${NC}" | tee -a $LOG_FILE
fi

# Install Python3 and pip
echo -e "${YELLOW}Installing Python3 and pip...${NC}" | tee -a $LOG_FILE
sudo apt install -y python3 python3-pip
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Python3 and pip installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install Python3 or pip.${NC}" | tee -a $LOG_FILE
fi

# Final cleanup
echo -e "${YELLOW}Performing final cleanup...${NC}" | tee -a $LOG_FILE
sudo apt autoremove -y
sudo apt autoclean -y
sudo apt clean -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Cleanup completed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to perform cleanup.${NC}" | tee -a $LOG_FILE
fi

# Completion message
echo -e "${BLUE}Setup completed at: $(date)${NC}" | tee -a $LOG_FILE
echo -e "${YELLOW}Reboot the server for changes to take full effect.${NC}"
