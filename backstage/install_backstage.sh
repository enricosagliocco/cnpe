#!/bin/bash

# Backstage Installation Script for Rocky Linux
# Questo script automatizza l'installazione di Backstage su Rocky Linux 9

set -e

echo "=========================================="
echo "Backstage Installation Script"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. System Prerequisites
print_info "Step 1: Updating system and installing build tools..."
sudo dnf update -y
sudo dnf install -y curl git make gcc gcc-c++ python3 python3-pip wget

print_info "✓ System prerequisites installed"
echo ""

# 2. Install Node.js via nvm
print_info "Step 2: Installing Node.js via nvm..."

if ! command -v nvm &> /dev/null; then
    print_info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
    print_warn "nvm è già installato"
fi

# Source nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

print_info "Installing Node.js LTS..."
nvm install --lts
nvm use --lts

# Verifica
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)
print_info "✓ Node.js $NODE_VERSION installed"
print_info "✓ npm $NPM_VERSION installed"
echo ""

# 3. Enable Corepack and install Yarn
print_info "Step 3: Enabling Corepack and installing Yarn..."
corepack enable
yarn set version 4.4.1

YARN_VERSION=$(yarn --version)
print_info "✓ Yarn $YARN_VERSION installed"
echo ""

# 4. Create Backstage project
print_info "Step 4: Creating Backstage project..."

# Chiedi il nome del progetto
read -p "Inserisci il nome del progetto Backstage (default: my-backstage): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-my-backstage}

print_info "Creazione del progetto '$PROJECT_NAME'..."
cd ~
npx @backstage/create-app@latest <<< "$PROJECT_NAME"

print_info "✓ Progetto Backstage creato"
echo ""

# 5. Configure app-config.yaml for remote access
print_info "Step 5: Configuring Backstage for remote access..."

cd ~/$PROJECT_NAME

# Backup del file di configurazione
if [ -f "app-config.yaml" ]; then
    cp app-config.yaml app-config.yaml.bak
    print_warn "Backup salvato in app-config.yaml.bak"
fi

# Modifica il file di configurazione per permettere accesso remoto
print_info "Configurando app-config.yaml per accesso remoto..."
cat >> app-config.yaml << 'EOF'

# Configurazione per accesso remoto
backend:
  listen:
    host: 0.0.0.0  # Ascolta su tutte le interfacce di rete
    port: 7007
EOF

print_info "✓ app-config.yaml configurato"
echo ""

# 6. Install dependencies
print_info "Step 6: Installing dependencies (questo può richiedere qualche minuto)..."
yarn install

print_info "✓ Dipendenze installate"
echo ""

# Final information
print_info "=========================================="
print_info "✓ Backstage installation completed successfully!"
print_info "=========================================="
echo ""
echo "Per avviare Backstage in modalità sviluppo:"
echo ""
echo "    cd ~/$PROJECT_NAME"
echo "    yarn start"
echo ""
echo "Backstage sarà disponibile su:"
echo ""
echo "    Frontend:  http://192.168.1.48:3000"
echo "    Backend:   http://192.168.1.48:7007"
echo ""
print_warn "Nota: Assicurati che le porte 3000 e 7007 siano libere e accessibili"
echo ""
