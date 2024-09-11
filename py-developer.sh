#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timestamp for log file
LOG_FILE="/var/log/py-developer.log"
echo -e "${BLUE}Python developer setup script started at: $(date)${NC}" | tee -a $LOG_FILE

# Update and upgrade system packages
echo -e "${YELLOW}Updating and upgrading system packages...${NC}" | tee -a $LOG_FILE
sudo apt update -y && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}System updated successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to update the system.${NC}" | tee -a $LOG_FILE
    exit 1
fi

# Install Python3 and pip3
echo -e "${YELLOW}Installing Python3 and pip3...${NC}" | tee -a $LOG_FILE
sudo apt install -y python3 python3-pip
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Python3 and pip3 installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install Python3 or pip3.${NC}" | tee -a $LOG_FILE
    exit 1
fi

# Install virtualenv for Python environments
echo -e "${YELLOW}Installing virtualenv...${NC}" | tee -a $LOG_FILE
pip3 install virtualenv
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Virtualenv installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install virtualenv.${NC}" | tee -a $LOG_FILE
    exit 1
fi

# Install Git
echo -e "${YELLOW}Installing Git...${NC}" | tee -a $LOG_FILE
sudo apt install -y git
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Git installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install Git.${NC}" | tee -a $LOG_FILE
    exit 1
fi

# Install build-essential for compiling Python packages
echo -e "${YELLOW}Installing build-essential...${NC}" | tee -a $LOG_FILE
sudo apt install -y build-essential
if [ $? -eq 0 ]; then
    echo -e "${GREEN}build-essential installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install build-essential.${NC}" | tee -a $LOG_FILE
    exit 1
fi

# Install curl for downloading tools
echo -e "${YELLOW}Installing curl...${NC}" | tee -a $LOG_FILE
sudo apt install -y curl
if [ $? -eq 0 ]; then
    echo -e "${GREEN}curl installed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to install curl.${NC}" | tee -a $LOG_FILE
    exit 1
fi

# Final Cleanup
echo -e "${YELLOW}Performing system cleanup...${NC}" | tee -a $LOG_FILE
sudo apt autoremove -y && sudo apt autoclean -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}System cleanup completed successfully.${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}Failed to clean up the system.${NC}" | tee -a $LOG_FILE
fi

echo -e "${GREEN}Python development environment setup completed!${NC}" | tee -a $LOG_FILE
