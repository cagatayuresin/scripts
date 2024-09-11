# Project Setup Scripts

## Overview

This project contains three important shell scripts for setting up and configuring environments, aliases, and necessary tools for Python developers.

---

## `after.sh`

This script is used to configure and optimize an Ubuntu server after initial installation. It includes tasks such as updating packages, installing common utilities, configuring OpenSSH, and setting up the Uncomplicated Firewall (UFW). Additionally, it installs Python and related tools.

**Key Features:**

- Updates package lists and upgrades installed packages.
- Removes unnecessary packages and performs system cleanup.
- Installs common utilities such as `curl`, `wget`, `git`, and `build-essential`.
- Configures OpenSSH for remote access.
- Sets up UFW to allow OpenSSH and enables it.
- Installs Python3 and `pip`.
- Performs final cleanup of unnecessary files.

**Usage:**

```bash
chmod +x after.sh
sudo ./after.sh
```

---

## `py-developer.sh`

This script sets up a Python development environment on a freshly installed Ubuntu system. It installs Python, pip, virtualenv, Git, and other essential development tools.

**Key Features:**

- Updates and upgrades system packages.
- Installs Python3 and pip3.
- Installs `virtualenv` for creating isolated Python environments.
- Installs Git and `build-essential` for compiling Python packages.
- Cleans up unnecessary packages and performs final system cleanup.

**Usage:**

```bash
chmod +x py-developer.sh
sudo ./py-developer.sh
```

---

## `bashrc-aliases.sh`

This script provides a collection of useful aliases for managing the terminal more efficiently. It includes aliases for managing system packages, working with Git, Docker, Kubernetes, Terraform, and Python development.

**Key Aliases:**

- **System Management:**
  - `get`: Installs packages via apt.
  - `upgrade`: Updates and upgrades all installed packages.
  - `clr`: Clears the terminal screen.
- **Git Shortcuts:**
  - `g`: Alias for `git`.
  - `gs`: Shows git status.
  - `ga`: Adds files to staging.
  - `gp`: Git pull.
  - `gpp`: Git pull and push.
- **Docker Shortcuts:**
  - `d`: Alias for `docker`.
  - `dc`: Alias for `docker-compose`.
- **Python Shortcuts:**
  - `py`: Runs Python3.
  - `pipi`: Installs a package via pip3.

**Usage:**

1. Add the aliases to your `~/.bashrc` file:

   ```bash
   source ~/.bashrc
   ```

2. Or run the script directly:

   ```bash
   chmod +x bashrc-aliases.sh
   ./bashrc-aliases.sh
   ```

## Ubuntu Server Security Setup Script

This script automates the process of securing an Ubuntu server after installation. It includes essential security practices such as configuring firewalls, setting up SSH key-based login, and preventing brute-force attacks using Fail2Ban.

---

### Key Features

1. **System Update and Upgrade:**

   - The script automatically updates and upgrades all installed packages to ensure the server is running the latest versions.

2. **Install Necessary Security Tools:**

   - `UFW`: A simple firewall to manage incoming and outgoing traffic.
   - `Fail2Ban`: Prevent brute-force attacks on SSH and other services.
   - `unattended-upgrades`: Automatically install security updates.

3. **Configure UFW Firewall:**

   - All incoming connections are denied by default, except for SSH (port 22). Outgoing connections are allowed.

4. **SSH Hardening:**

   - Password-based login is disabled, and only SSH key-based login is allowed.
   - Root login over SSH is also disabled to further harden the security of the server.

5. **Fail2Ban Configuration:**

   - Protects SSH from brute-force attacks by banning IP addresses after multiple failed login attempts.

6. **Automatic Security Updates:**

   - The script configures automatic security updates to ensure the server always has the latest security patches.

7. **Disable Unused Services:**

   - Optional but highly recommended to disable unused services such as `avahi-daemon`.

8. **Create a New User with Sudo Privileges:**

   - A new non-root user is created with sudo privileges to perform administrative tasks securely.

9. **SSH Key-based Authentication Setup:**

   - The script sets up SSH key-based authentication for the newly created user.

10. **Disable ICMP (Ping) Responses:**
    - To make the server less detectable, the script disables ICMP echo requests (ping responses).

---

### SSH Key-based Authentication Setup

For enhanced security, this script disables password-based SSH login and requires key-based authentication. Below are the steps to generate and set up the SSH keys from your **local machine**:

#### Local Machine Steps

1. **Generate SSH Key Pair:**
   On your local machine, open the terminal and run:

   ```bash
   ssh-keygen -t rsa -b 4096
   ```

   This will create a private key (`~/.ssh/id_rsa`) and a public key (`~/.ssh/id_rsa.pub`). The private key should be kept safe and never shared.

2. **Copy Public Key to the Server:**
   To copy the public key to the server, run the following command:

   ```bash
   ssh-copy-id username@your_server_ip
   ```

   If `ssh-copy-id` is not available, manually copy the public key using:

   ```bash
   cat ~/.ssh/id_rsa.pub | ssh username@your_server_ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
   ```

3. **Test SSH Key Authentication:**
   After copying the public key, you should be able to log in to the server without a password:

   ```bash
   ssh username@your_server_ip
   ```

   If successful, you will not be prompted for a password.

#### Script Execution Steps

1. **SSH Hardening on the Server (Performed by the Script):**

   - The script disables password-based SSH login by modifying `/etc/ssh/sshd_config`.
   - It disables root login over SSH.
   - It sets up the public SSH key for the new user.

2. **Server Configuration for SSH Key-based Authentication:**
   - The public key provided during script execution will be placed in the new user's `~/.ssh/authorized_keys` file.
   - Proper permissions for the `.ssh` directory and `authorized_keys` file will be set.

---

### Usage

1. Make the script executable:

   ```bash
   chmod +x security_setup.sh
   ```

2. Run the script with sudo:

   ```bash
   sudo ./security_setup.sh
   ```

The script will guide you through the necessary steps, such as entering the new username and providing the public SSH key.

---

This setup ensures that your server is protected against common security threats and uses best practices for SSH access.

---

## License

This project is licensed under the MIT License.
