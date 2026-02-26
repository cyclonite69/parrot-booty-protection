#!/bin/bash
# Sync docs/ to wiki

REPO_DIR="/home/dbcooper/parrot-booty-protection"
WIKI_DIR="/home/dbcooper/parrot-booty-protection.wiki"

echo "Syncing docs to wiki..."

# Copy documentation files
cp "$REPO_DIR/docs/REPORTING_SYSTEM.md" "$WIKI_DIR/Reporting-System.md"
cp "$REPO_DIR/docs/SECURITY_AUDIT.md" "$WIKI_DIR/Security-Audit.md" 2>/dev/null || echo "Security audit not found"
cp "$REPO_DIR/docs/PROJECT_COMPLETE.md" "$WIKI_DIR/Architecture.md"

# Commit and push
cd "$WIKI_DIR"
git add -A
git commit -m "docs: Sync from main repository docs/"
git push origin master

echo "✓ Wiki updated"
