#!/bin/bash
set -e

# Script to set up Ansible environment for the IRC stack

echo "🔧 Setting up Ansible environment..."
echo "====================================="

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is not installed!"
    echo "Please install Ansible:"
    echo "  macOS: brew install ansible"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install ansible"
    echo "  RHEL/CentOS/Fedora: sudo dnf install ansible"
    echo "  pip: pip install ansible"
    exit 1
fi

echo "✅ Ansible found: $(ansible --version | head -1)"

# Install Ansible collections
echo "📦 Installing required Ansible collections..."
ansible-galaxy collection install -r ansible/requirements.yml

echo "✅ Ansible collections installed successfully!"

echo ""
echo "🎯 Available commands:"
echo "  Test configuration: ansible all -i ansible/inventory/hosts -m ping"
echo "  Run playbook:       ansible-playbook -i ansible/inventory/hosts ansible/playbooks/site.yml"
echo "  Test idempotency:   ./scripts/test-ansible-idempotency.sh"
echo "  Check mode:         ansible-playbook -i ansible/inventory/hosts ansible/playbooks/site.yml --check --diff"
echo ""
echo "📋 Next steps:"
echo "  1. Run 'terraform apply' to create infrastructure"
echo "  2. Run './scripts/test-ansible-idempotency.sh' to verify configuration"