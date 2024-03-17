#!/bin/bash

# Default IP address 
DEFAULT_IP_ADDRESS=""

## DO NOT MODIFY FROM HERE ## 
IP_ADDRESS="$DEFAULT_IP_ADDRESS"
IP_VERSION=""

# Function to display usage
usage() {
    echo "Usage: $0 {block|unblock} [-i <ip_address>]"
    echo "Example to block default IP: $0 block"
    echo "Example to block specific IP: $0 block -i 2001:db8::1"
    echo "Example to unblock default IP: $0 unblock"
    echo "Example to unblock specific IP: $0 unblock -i 192.0.2.1"
    exit 1
}

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use 'sudo' or log in as the root user."
    exit 1
fi

# Function to validate IP address and determine its version
validate_ip() {
    local ip=$1
    local valid_ipv4="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    local valid_ipv6="^([0-9a-fA-F]{1,4}:){7}([0-9a-fA-F]{1,4})$"

    if [[ $ip =~ $valid_ipv4 ]]; then
        IP_VERSION="IPv4"
    elif [[ $ip =~ $valid_ipv6 ]]; then
        IP_VERSION="IPv6"
    else
        echo "Invalid IP address format."
        exit 7
    fi
}

# Function to find the first position for an IPv6 rule
get_first_ipv6_rule_position() {
    ufw status numbered | grep -m 1 'v6' | cut -d '[' -f2 | cut -d ']' -f1
}

# Function to block IP
block_ip() {
    echo "Blocking IP address: $IP_ADDRESS"
    # For IPv4, insert the rule at position 1
    if [ "$IP_VERSION" == "IPv4" ]; then
        ufw insert 1 deny from "$IP_ADDRESS"
    else  # For IPv6, find the appropriate position to insert the rule
        local position=$(get_first_ipv6_rule_position)
        ufw insert $position deny from "$IP_ADDRESS"
    fi
    
    # Check the return code of the ufw command
    if [ $? -eq 0 ]; then
        echo "IP address $IP_ADDRESS has been successfully blocked."
    else
        echo "Failed to block IP address $IP_ADDRESS."
        exit 3
    fi
}

# Function to unblock IP
unblock_ip() {
    echo "Unblocking IP address: $IP_ADDRESS"
    ufw delete deny from "$IP_ADDRESS"
    # Check the return code of the ufw command
    if [ $? -eq 0 ]; then
        echo "IP address $IP_ADDRESS has been successfully unblocked."
    else
        echo "Failed to unblock IP address $IP_ADDRESS."
        exit 4
    fi
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        block|unblock) OPERATION="$1"; ;;
        -i|--ip) IP_ADDRESS="$2"; shift ;;
        *) usage ;;
    esac
    shift
done

# Validate IP and determine its version
validate_ip "$IP_ADDRESS"

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
    echo "UFW not found. Please install UFW and try again."
    exit 2
fi

# Check if UFW is active
ufw status | grep -qw active
if [ $? -ne 0 ]; then
    echo "UFW is not active. Please enable UFW and try again."
    exit 5
fi

# Main logic based on the operation
case "$OPERATION" in
    block)
        block_ip
        ;;
    unblock)
        unblock_ip
        ;;
    *) usage ;;
esac
