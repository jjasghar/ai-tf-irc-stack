#!/bin/bash
set -e

# Script to test Ansible playbook idempotency
# This ensures that running the playbooks multiple times produces no changes

INVENTORY_FILE="ansible/inventory/hosts"
PLAYBOOK_FILE="ansible/playbooks/site.yml"

if [ ! -f "$INVENTORY_FILE" ]; then
    echo "❌ Error: Inventory file $INVENTORY_FILE not found!"
    echo "   Make sure Terraform has run successfully to generate the inventory."
    exit 1
fi

if [ ! -f "$PLAYBOOK_FILE" ]; then
    echo "❌ Error: Playbook file $PLAYBOOK_FILE not found!"
    exit 1
fi

echo "🔍 Testing Ansible playbook idempotency..."
echo "========================================="

# First run
echo "📋 Running playbook (first time)..."
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" | tee /tmp/ansible-first-run.log

echo ""
echo "🔄 Running playbook (second time to test idempotency)..."
ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK_FILE" | tee /tmp/ansible-second-run.log

echo ""
echo "📊 Analyzing results..."

# Check for changes in second run
if grep -q "changed=0" /tmp/ansible-second-run.log && ! grep -q "failed=" /tmp/ansible-second-run.log; then
    echo "✅ SUCCESS: Playbook is idempotent!"
    echo "   No changes were made on the second run."
else
    echo "⚠️  WARNING: Playbook may not be fully idempotent."
    echo "   Some tasks reported changes on the second run."
    echo ""
    echo "📝 Second run summary:"
    grep -E "(changed=|failed=|ok=)" /tmp/ansible-second-run.log || true
fi

echo ""
echo "📁 Full logs saved to:"
echo "   First run:  /tmp/ansible-first-run.log"
echo "   Second run: /tmp/ansible-second-run.log"
echo ""
echo "🔍 To test manually, run:"
echo "   ansible-playbook -i $INVENTORY_FILE $PLAYBOOK_FILE --check --diff"