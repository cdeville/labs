#!/usr/bin/env bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Temporary files tracking for cleanup
TEMP_FILES=()

#############################################
# Helper Functions
#############################################

# Print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        log_info "Cleaning up temporary files..."
        for file in "${TEMP_FILES[@]}"; do
            if [[ -e "$file" ]]; then
                rm -rf "$file"
                log_info "Removed: $file"
            fi
        done
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if package is already installed
package_installed() {
    dnf list installed "$1" &> /dev/null
}

# Verify required dependencies
check_dependencies() {
    local deps=("sudo" "dnf" "wget" "curl" "unzip")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install them before running this script."
        exit 1
    fi
    
    log_info "All required dependencies are available."
}

#############################################
### Microsoft Edge & VS Code Install
#############################################
install_microsoft_apps() {
    log_info "Starting Microsoft Edge and VS Code installation..."
    
    # Check if already installed
    if package_installed "microsoft-edge-stable" && package_installed "code"; then
        log_warn "Microsoft Edge and VS Code are already installed. Skipping..."
        return 0
    fi
    
    # Import Microsoft's GPG key
    log_info "Importing Microsoft GPG key..."
    if ! sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc; then
        log_error "Failed to import Microsoft GPG key"
        return 1
    fi
    
    # Download the appropriate repo files
    log_info "Downloading Microsoft repository configurations..."
    if ! wget -O ./edge-config.repo https://packages.microsoft.com/yumrepos/edge/config.repo; then
        log_error "Failed to download Edge repository configuration"
        return 1
    fi
    TEMP_FILES+=("./edge-config.repo")
    
    if ! wget -O ./vscode-config.repo https://packages.microsoft.com/yumrepos/vscode/config.repo; then
        log_error "Failed to download VS Code repository configuration"
        return 1
    fi
    TEMP_FILES+=("./vscode-config.repo")
    
    # Move repo files to yum repos folder
    log_info "Installing repository configurations..."
    sudo mv edge-config.repo /etc/yum.repos.d/microsoft-edge.repo
    sudo mv vscode-config.repo /etc/yum.repos.d/microsoft-vscode.repo
    
    # Remove from temp tracking as they've been moved
    TEMP_FILES=()
    
    # Install Microsoft Edge browser and VS Code
    log_info "Installing Microsoft Edge and VS Code..."
    if ! sudo dnf -y install microsoft-edge-stable code; then
        log_error "Failed to install Microsoft applications"
        return 1
    fi
    
    log_info "Microsoft Edge and VS Code installed successfully."
    return 0
}

#############################################
### Docker Engine Install
#############################################
install_docker() {
    log_info "Starting Docker Engine installation..."
    
    # Check if Docker is already installed
    if command_exists docker && systemctl is-active --quiet docker; then
        log_warn "Docker is already installed and running. Skipping..."
        return 0
    fi
    
    # Uninstall conflicting packages
    log_info "Removing conflicting Docker packages (if any)..."
    sudo dnf -y remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-selinux \
                      docker-engine-selinux \
                      docker-engine || true  # Don't fail if packages don't exist
    
    # Setup the Docker repository
    log_info "Setting up Docker repository..."
    if ! sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo; then
        log_error "Failed to add Docker repository"
        return 1
    fi
    
    # Install Docker packages
    log_info "Installing Docker packages..."
    log_warn "If prompted to accept the GPG key, verify fingerprint: 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35"
    if ! sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "Failed to install Docker packages"
        return 1
    fi
    
    # Start and enable Docker Engine
    log_info "Starting Docker Engine..."
    if ! sudo systemctl enable --now docker; then
        log_error "Failed to start Docker Engine"
        return 1
    fi
    
    # Verify installation
    log_info "Verifying Docker installation..."
    if ! sudo docker run hello-world; then
        log_error "Docker installation verification failed"
        return 1
    fi
    
    log_info "Docker Engine installed and verified successfully."
    return 0
}

#############################################
### Install Git and GitHub CLI
#############################################
install_git_cli() {
    log_info "Starting Git and GitHub CLI installation..."
    
    # Check if already installed
    if command_exists git && command_exists gh; then
        log_warn "Git and GitHub CLI are already installed. Skipping..."
        return 0
    fi
    
    # Install Git and GitHub CLI
    log_info "Installing Git and GitHub CLI..."
    if ! sudo dnf -y install git gh; then
        log_error "Failed to install Git and GitHub CLI"
        return 1
    fi
    
    log_info "Git and GitHub CLI installed successfully."
    log_info "Git version: $(git --version)"
    log_info "GitHub CLI version: $(gh --version | head -n 1)"
    return 0
}

#############################################
### Install AWS CLI
#############################################
install_aws_cli() {
    log_info "Starting AWS CLI installation..."
    
    # Check if already installed
    if command_exists aws; then
        log_warn "AWS CLI is already installed. Skipping..."
        aws --version
        return 0
    fi
    
    # Download AWS CLI
    log_info "Downloading AWS CLI v2..."
    if ! curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; then
        log_error "Failed to download AWS CLI"
        return 1
    fi
    TEMP_FILES+=("awscliv2.zip")
    
    # Unzip the installer
    log_info "Extracting AWS CLI installer..."
    if ! unzip -q awscliv2.zip; then
        log_error "Failed to extract AWS CLI installer"
        return 1
    fi
    TEMP_FILES+=("aws")
    
    # Install AWS CLI
    log_info "Installing AWS CLI..."
    if ! sudo ./aws/install; then
        log_error "Failed to install AWS CLI"
        return 1
    fi
    
    # Clean up installation files (will also be done by trap)
    rm -rf aws awscliv2.zip
    TEMP_FILES=()
    
    log_info "AWS CLI installed successfully."
    log_info "AWS CLI version: $(aws --version)"
    return 0
}

#############################################
# Main Execution
#############################################
main() {
    log_info "=== System Software Installation Script ==="
    log_info "Starting installation process..."
    echo
    
    # Check for required dependencies first
    check_dependencies
    echo
    
    # Track failures
    FAILED_INSTALLS=()
    
    # Install Microsoft Edge and VS Code
    if ! install_microsoft_apps; then
        log_error "Microsoft applications installation failed"
        FAILED_INSTALLS+=("Microsoft Edge & VS Code")
    fi
    echo
    
    # Install Docker
    if ! install_docker; then
        log_error "Docker installation failed"
        FAILED_INSTALLS+=("Docker Engine")
    fi
    echo
    
    # Install Git CLI
    if ! install_git_cli; then
        log_error "Git CLI installation failed"
        FAILED_INSTALLS+=("Git & GitHub CLI")
    fi
    echo
    
    # Install AWS CLI
    if ! install_aws_cli; then
        log_error "AWS CLI installation failed"
        FAILED_INSTALLS+=("AWS CLI")
    fi
    echo
    
    # Summary
    log_info "=== Installation Summary ==="
    if [[ ${#FAILED_INSTALLS[@]} -eq 0 ]]; then
        log_info "All installations completed successfully! ✓"
        exit 0
    else
        log_error "Some installations failed:"
        for failed in "${FAILED_INSTALLS[@]}"; do
            log_error "  - $failed"
        done
        exit 1
    fi
}

# Run main function
main

