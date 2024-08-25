#!/bin/bash

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        # Source the os-release file to get distribution information
        . /etc/os-release
        DISTRO=$ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/redhat-release ]; then
        DISTRO="redhat"
    else
        DISTRO=$(uname -s)
    fi
}

# Function to update the system based on the package manager
update_system() {
    case $DISTRO in
        ubuntu|debian)
            sudo apt update && sudo apt upgrade -y
            ;;
        fedora)
            sudo dnf upgrade --refresh -y
            ;;
        redhat|centos)
            sudo yum update -y
            ;;
        arch)
            sudo pacman -Syu --noconfirm
            ;;
        opensuse)
            sudo zypper refresh && sudo zypper update -y
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Function to disable SELinux
disable_selinux() {
    if [ -f /etc/selinux/config ]; then
        sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        sudo setenforce 0
        echo "SELinux has been disabled."
    else
        echo "SELinux configuration file not found. Skipping SELinux disabling."
    fi
}

# Function to get the last group of digits from the IP address
get_last_octet() {
    IP_ADDR=$(hostname -I | awk '{print $1}')
    LAST_OCTET=$(echo $IP_ADDR | awk -F. '{print $NF}')
    SSH_PORT=$(printf "7%03d" $LAST_OCTET)  # Pad last octet to ensure 3 digits
}

# Function to update the sshd_config file to use the new SSH port
update_sshd_config() {
    sudo sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
    echo "sshd_config updated to use port $SSH_PORT."
}

# Function to open the SSH port based on the last octet
open_ssh_port() {
    if command -v ufw &> /dev/null; then
        sudo ufw allow $SSH_PORT/tcp
        sudo ufw reload
        echo "Firewall rule added for SSH port $SSH_PORT using UFW."
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=$SSH_PORT/tcp
        sudo firewall-cmd --reload
        echo "Firewall rule added for SSH port $SSH_PORT using firewall-cmd."
    else
        echo "Firewall not found. Please open port $SSH_PORT manually."
    fi
}

# Function to restart SSH and firewall services
restart_services() {
    if systemctl is-active --quiet sshd; then
        sudo systemctl restart sshd
        echo "SSHD service restarted."
    elif systemctl is-active --quiet ssh; then
        sudo systemctl restart ssh
        echo "SSH service restarted."
    else
        echo "SSH service not found. Please restart SSH manually."
    fi

    if command -v ufw &> /dev/null; then
        sudo ufw reload
        echo "UFW firewall reloaded."
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --reload
        echo "Firewall reloaded."
    fi
}

# Main execution
echo "Detecting Linux distribution..."
detect_distro
echo "Detected distribution: $DISTRO"

echo "Updating the system..."
update_system
echo "System updated."

echo "Disabling SELinux..."
disable_selinux

echo "Configuring SSH port..."
get_last_octet
update_sshd_config
open_ssh_port

echo "Restarting SSH and firewall services..."
restart_services

echo "Post-installation tasks completed."