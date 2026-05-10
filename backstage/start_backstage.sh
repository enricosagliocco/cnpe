#!/bin/bash

# Quick Start Script for Backstage
# This script provides a quick way to start Backstage on 192.168.1.48

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Backstage is already created
if [ ! -d "$HOME/my-backstage" ]; then
    print_error "Backstage non è ancora installato!"
    print_info "Esegui install_backstage.sh per prima cosa"
    exit 1
fi

cd ~/my-backstage

print_info "Avvio Backstage..."
print_warn "Frontend disponibile su: http://192.168.1.48:3000"
print_warn "Backend disponibile su: http://192.168.1.48:7007"
echo ""

yarn start
