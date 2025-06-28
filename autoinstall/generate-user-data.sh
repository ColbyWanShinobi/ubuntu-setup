#!/bin/bash

# Function to generate password hash
generate_password_hash() {
    local password="$1"
    if command -v mkpasswd >/dev/null 2>&1; then
        echo "$password" | mkpasswd -m sha-512 -s
    elif command -v openssl >/dev/null 2>&1; then
        local salt=$(openssl rand -base64 16)
        echo "$password" | openssl passwd -6 -stdin -salt "$salt"
    else
        echo "Error: Neither mkpasswd nor openssl found."
        echo "Please install one of the following:"
        echo "  - whois package (for mkpasswd): sudo apt install whois"
        echo "  - openssl package: sudo apt install openssl"
        exit 1
    fi
}

# Path to template and output files
TEMPLATE_FILE="$(dirname "$0")/www/user-data.template"
OUTPUT_FILE="$(dirname "$0")/www/user-data"

# Check if template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template file $TEMPLATE_FILE not found!"
    exit 1
fi

echo "=== Ubuntu Autoinstall Configuration Generator ==="
echo

# Check if all environment variables are set (for non-interactive mode)
if [[ -n "$TEMPLATE_HOSTNAME" && -n "$TEMPLATE_USERNAME" && -n "$TEMPLATE_PASSWORD_HASH" && -n "$TEMPLATE_DISK_SERIAL" ]]; then
    echo "Using environment variables:"
    echo "  HOSTNAME: $TEMPLATE_HOSTNAME"
    echo "  USERNAME: $TEMPLATE_USERNAME"
    echo "  PASSWORD_HASH: ${TEMPLATE_PASSWORD_HASH:0:20}..." # Only show first 20 chars for security
    echo "  DISK_SERIAL: $TEMPLATE_DISK_SERIAL"
    echo
else
    # Interactive mode - prompt for any missing values
    
    # Get hostname
    if [[ -z "$TEMPLATE_HOSTNAME" ]]; then
        read -p "Enter hostname [ubuntu-btrfs]: " TEMPLATE_HOSTNAME
        TEMPLATE_HOSTNAME="${TEMPLATE_HOSTNAME:-ubuntu-btrfs}"
    fi
    
    # Get username  
    if [[ -z "$TEMPLATE_USERNAME" ]]; then
        read -p "Enter username [picard]: " TEMPLATE_USERNAME
        TEMPLATE_USERNAME="${TEMPLATE_USERNAME:-picard}"
    fi
    
    # Get password and generate hash if not set
    if [[ -z "$TEMPLATE_PASSWORD_HASH" ]]; then
        echo
        echo "Enter password for user '$TEMPLATE_USERNAME':"
        read -s TEMPLATE_PASSWORD
        echo "Confirm password:"
        read -s TEMPLATE_PASSWORD_CONFIRM
        
        if [[ "$TEMPLATE_PASSWORD" != "$TEMPLATE_PASSWORD_CONFIRM" ]]; then
            echo "Error: Passwords do not match!"
            exit 1
        fi
        
        if [[ -z "$TEMPLATE_PASSWORD" ]]; then
            echo "Error: Password cannot be empty!"
            exit 1
        fi
        
        echo "Generating password hash..."
        TEMPLATE_PASSWORD_HASH=$(generate_password_hash "$TEMPLATE_PASSWORD")
        
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to generate password hash!"
            exit 1
        fi
        echo "Password hash generated successfully."
    fi

    # Get disk serial number
    if [[ -z "$TEMPLATE_DISK_SERIAL" ]]; then
        echo
        echo "Available disks on this system and their serial numbers:"
        if command -v lsblk >/dev/null 2>&1; then
            lsblk -o NAME,SIZE,SERIAL,MODEL | grep -E "^(sd|nvme|vd)" || echo "No disks found with lsblk"
        fi
        echo
        echo "You can also check disk serial numbers with:"
        echo "  sudo lshw -class disk | grep -A 3 'serial:'"
        echo "  or: sudo fdisk -l | grep -E 'Disk /dev/'"
        echo
        read -p "Enter target disk serial number: " TEMPLATE_DISK_SERIAL
        
        if [[ -z "$TEMPLATE_DISK_SERIAL" ]]; then
            echo "Error: Disk serial number cannot be empty!"
            exit 1
        fi
    fi
    
    echo
    echo "Configuration summary:"
    echo "  TEMPLATE_HOSTNAME: $TEMPLATE_HOSTNAME"
    echo "  TEMPLATE_USERNAME: $TEMPLATE_USERNAME"
    echo "  TEMPLATE_PASSWORD_HASH: ${TEMPLATE_PASSWORD_HASH:0:20}..." # Only show first 20 chars for security
    echo "  TEMPLATE_DISK_SERIAL: $TEMPLATE_DISK_SERIAL"
    echo
fi

# Export variables for envsubst
export TEMPLATE_HOSTNAME
export TEMPLATE_USERNAME
export TEMPLATE_PASSWORD_HASH
export TEMPLATE_DISK_SERIAL

# Use envsubst to substitute variables
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE successfully!"
echo
echo "You can now use this file for Ubuntu autoinstall."
