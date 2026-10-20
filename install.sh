#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    printf "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║     WireGuard VPN Server Installer         ║"
    echo "╚════════════════════════════════════════════╝"
    printf "${NC}\n"
}

print_success() {
    printf "${GREEN}✓ %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}✗ %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}! %s${NC}\n" "$1"
}

print_info() {
    printf "${BLUE}→ %s${NC}\n" "$1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check requirements
check_requirements() {
    print_info "Checking requirements..."

    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        echo "  Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"

    if ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        echo "  Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose is available"

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    print_success "Docker daemon is running"

    if ! command_exists curl; then
        print_error "curl is not installed. Please install curl."
        exit 1
    fi
    print_success "curl is installed"

    echo ""
}

# Get server IP
get_server_ip() {
    # Try to detect public IP
    local detected_ip=""
    if command_exists curl; then
        detected_ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "")
    fi

    printf "${BLUE}Enter your server's public IP address${NC}\n"
    if [ -n "$detected_ip" ]; then
        printf "  Detected: ${GREEN}%s${NC}\n" "$detected_ip"
        read -p "  Press Enter to use detected IP or enter a different one: " SERVER_IP
        SERVER_IP=${SERVER_IP:-$detected_ip}
    else
        read -p "  IP Address: " SERVER_IP
    fi

    if [ -z "$SERVER_IP" ]; then
        print_error "Server IP is required"
        exit 1
    fi

    print_success "Server IP: $SERVER_IP"
    echo ""
}

# Get admin credentials
get_credentials() {
    printf "${BLUE}Enter a username for the admin panel${NC}\n"
    read -p "  Username [admin]: " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
    print_success "Username: $ADMIN_USERNAME"
    echo ""

    printf "${BLUE}Enter a password for the admin panel${NC}\n"
    while true; do
        read -s -p "  Password: " PASSWORD
        echo ""
        read -s -p "  Confirm password: " PASSWORD_CONFIRM
        echo ""

        if [ -z "$PASSWORD" ]; then
            print_error "Password cannot be empty"
            continue
        fi

        if [ ${#PASSWORD} -lt 12 ]; then
            print_error "Password must be at least 12 characters"
            continue
        fi

        if [[ "$PASSWORD" == *"'"* ]]; then
            print_error "Password cannot contain single quotes"
            continue
        fi

        if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            print_error "Passwords do not match. Please try again."
            continue
        fi

        break
    done
    print_success "Password set"
    echo ""
}

# Check for an existing installation
check_existing_install() {
    if docker volume inspect my_wireguard_data >/dev/null 2>&1; then
        print_warning "Existing data volume 'my_wireguard_data' found."
        print_warning "Unattended setup only runs on a fresh volume, so your existing config will be kept."
        print_warning "Data from wg-easy v14 is not migrated automatically, see README for migration steps."
        read -p "  Continue? [y/N]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        echo ""
    fi
}

# Create .env file
create_env_file() {
    print_info "Creating .env file..."

    umask 077
    cat > .env << EOF
# Docker Compose
COMPOSE_PROJECT_NAME=my_vpn

# wg-easy image tag (major version pin)
WG_EASY_VERSION=15

# Wireguard
SERVER_IP=$SERVER_IP

# Allow the web UI over plain http (set false behind an https reverse proxy)
INSECURE=true

# Unattended setup, only read on the first start
INIT_ENABLED=true
ADMIN_USERNAME='$ADMIN_USERNAME'
ADMIN_PASSWORD='$PASSWORD'
EOF

    print_success ".env file created"
}

# Start the server
start_server() {
    print_info "Pulling image and starting WireGuard VPN server..."
    docker compose pull
    docker compose up -d
    print_success "Server started"
}

# Wait until the web UI responds
wait_for_server() {
    print_info "Waiting for the web UI to come up..."
    for _ in $(seq 1 30); do
        if curl -s -o /dev/null --connect-timeout 2 "http://127.0.0.1:51821"; then
            print_success "Web UI is up"
            return 0
        fi
        sleep 2
    done
    print_error "Web UI did not respond in 60s. Check: docker compose logs"
    exit 1
}

# Remove the plain text password from .env once setup is done
scrub_env() {
    print_info "Removing admin password from .env..."
    local tmp
    tmp=$(mktemp)
    sed -e "s/^INIT_ENABLED=.*/INIT_ENABLED=false/" \
        -e "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=/" .env > "$tmp"
    cat "$tmp" > .env
    rm -f "$tmp"

    # Recreate the container so the password is gone from its environment too
    docker compose up -d >/dev/null 2>&1
    print_success "Password removed from .env and container environment"
    wait_for_server
}

# Print completion message
print_completion() {
    echo ""
    printf "${GREEN}╔════════════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║     Installation Complete!                 ║${NC}\n"
    printf "${GREEN}╚════════════════════════════════════════════╝${NC}\n"
    echo ""
    printf "  ${BLUE}Admin Panel:${NC} http://%s:51821\n" "$SERVER_IP"
    printf "  ${BLUE}Login:${NC} %s / the password you just set\n" "$ADMIN_USERNAME"
    echo ""
    printf "  ${YELLOW}Next steps:${NC}\n"
    echo "  1. Open the admin panel in your browser"
    echo "  2. Login with your password"
    echo "  3. Click '+ New Client' to add a client"
    echo "  4. Scan QR code or download config file"
    echo "  5. Install WireGuard client app: https://www.wireguard.com/install/"
    echo ""
    printf "  ${YELLOW}Useful commands:${NC}\n"
    echo "  docker compose logs -f    # View logs"
    echo "  docker compose stop       # Stop server"
    echo "  docker compose restart    # Restart server"
    echo ""
    print_warning "This VPN is for development purposes only!"
    print_warning "Do not use this VPN for daily jobs to prevent security issues and unnecessary server load."
    echo ""
}

# Main installation flow
main() {
    print_banner
    check_requirements
    check_existing_install
    get_server_ip
    get_credentials
    create_env_file
    start_server
    wait_for_server
    scrub_env
    print_completion
}

# Run main function
main
