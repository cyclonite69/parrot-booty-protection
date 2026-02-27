# DEPRECATION_PLAN.md
## Repository Cleanup Plan
**Generated:** 2026-02-26  
**Purpose:** Exact commands for safe repository cleanup

---

## CLEANUP SUMMARY

**Total Files to Remove:** ~180 files  
**Total Directories to Remove:** 3 major directories  
**Total Documentation to Archive:** 21 files  
**Estimated Disk Space Recovered:** ~2-3 MB

---

## PHASE 1: BACKUP CURRENT STATE

**CRITICAL: Create backup before any deletions**

```bash
cd /home/dbcooper/parrot-booty-protection

# Create backup
tar -czf ../pbp-backup-$(date +%Y%m%d-%H%M%S).tar.gz .

# Verify backup
tar -tzf ../pbp-backup-*.tar.gz | head -20

# Create git tag
git tag -a pre-cleanup-audit -m "State before cleanup audit 2026-02-26"
git push origin pre-cleanup-audit
```

---

## PHASE 2: ARCHIVE HISTORICAL DOCUMENTATION

```bash
cd /home/dbcooper/parrot-booty-protection

# Create archive directory
mkdir -p docs/archive

# Create archive README
cat > docs/archive/README.md << 'EOF'
# Historical Documentation Archive

This directory contains historical documentation from PBP development phases.
These documents are preserved for reference but are not actively maintained.

For current documentation, see the main README.md and docs/ directory.

## Contents

- Phase completion markers (PHASE*_COMPLETE.md)
- Incident reports (DNS_INCIDENT_COMPLETE.md, etc.)
- Development logs (GEMINI.md)
- Test results (TEST_RESULTS.md, UNBOUND_TLS_STATUS.md)
- Historical guides (MONITORING.md, DNS_HARDENING.md)

## Archive Date

2026-02-26
EOF

# Move root-level historical docs
mv START_HERE.md docs/archive/
mv DELIVERABLES.md docs/archive/
mv CONTROL_RESTORATION_COMPLETE.md docs/archive/
mv DNS_SOVEREIGNTY_GUARD_COMPLETE.md docs/archive/
mv DNS_INCIDENT_COMPLETE.md docs/archive/
mv INCIDENT_RESPONSE_SUMMARY.md docs/archive/
mv ROOT_CAUSE_REPORT.md docs/archive/
mv DNS_VALIDATION_CHECKLIST.md docs/archive/
mv MONITORING_GAP_REPORT.md docs/archive/
mv DNS_ARCHITECTURE_FIXED.md docs/archive/
mv DNS_HARDENING.md docs/archive/
mv MONITORING.md docs/archive/
mv TEST_RESULTS.md docs/archive/
mv UNBOUND_TLS_STATUS.md docs/archive/
mv GEMINI.md docs/archive/

# Move docs/ historical docs
mv docs/PHASE2_COMPLETE.md docs/archive/
mv docs/PHASE3_COMPLETE.md docs/archive/
mv docs/PHASE4_COMPLETE.md docs/archive/
mv docs/PROJECT_COMPLETE.md docs/archive/
mv docs/REPORTING_COMPLETE.md docs/archive/

# Verify moves
ls -la docs/archive/
```

---

## PHASE 3: DELETE DEPRECATED DOCUMENTATION

```bash
cd /home/dbcooper/parrot-booty-protection

# Delete superseded README
rm README_OLD.md

# Delete duplicate control restoration summary
rm docs/CONTROL_RESTORATION_SUMMARY.md

# Verify deletions
git status
```

---

## PHASE 4: DELETE HARDENING FRAMEWORK

**CRITICAL: Entire directory is orphaned, no references**

```bash
cd /home/dbcooper/parrot-booty-protection

# Verify no references exist
grep -r "hardenctl" . --exclude-dir=hardening-framework --exclude-dir=.git || echo "No references found (safe to delete)"

# Delete directory
rm -rf hardening-framework/

# Verify deletion
ls -la | grep hardening-framework || echo "Successfully deleted"
```

**Files Removed:** 80+ files including:
- hardenctl (main executable)
- hardenctl_simple (variant)
- core/logger.sh, core/state_manager.sh
- modules/*.sh (17 modules)
- state/enabled.json
- README.md

---

## PHASE 5: DELETE PBP-OPS

**CRITICAL: Partial implementation, never deployed**

```bash
cd /home/dbcooper/parrot-booty-protection

# Verify no references exist
grep -r "app.py\|pbp_core.py" . --exclude-dir=pbp-ops --exclude-dir=.git || echo "No references found (safe to delete)"

# Delete directory
rm -rf pbp-ops/

# Verify deletion
ls -la | grep pbp-ops || echo "Successfully deleted"
```

**Files Removed:** 40+ files including:
- ui/app.py (FastAPI web app)
- lib/pbp_core.py (Python library)
- modules/* (8 module directories with duplicates)
- state/registry.json (empty)
- Empty directories: reports/, logs/, scripts/, configs/, scheduler/

---

## PHASE 6: DELETE PBP-CORE

**CRITICAL: Shadow implementation, superseded by /core and /bin**

```bash
cd /home/dbcooper/parrot-booty-protection

# Verify no references exist
grep -r "pbp-sentinel\|pbp-respond\|pbp-learn" . --exclude-dir=pbp-core --exclude-dir=.git --exclude=install_pbp.sh || echo "No references found (safe to delete)"

# Delete directory
rm -rf pbp-core/

# Verify deletion
ls -la | grep pbp-core || echo "Successfully deleted"
```

**Files Removed:** 40+ files including:
- bin/pbp.sh (duplicate CLI)
- bin/pbp-dashboard.sh (duplicate dashboard)
- bin/pbp-sentinel.sh (threat detection stub)
- bin/pbp-respond.sh (incident response stub)
- bin/pbp-learn.sh (ML baseline stub)
- lib/pbp-lib.sh (duplicate library)
- modules/pbp-*.sh (6 modules, duplicates/stubs)
- systemd/*.service (4 duplicate units)

---

## PHASE 7: DELETE OLD DNS SCRIPTS

**CRITICAL: Superseded by modules/dns + dns-sovereignty-guard**

```bash
cd /home/dbcooper/parrot-booty-protection/scripts

# Verify no references exist
for script in dns_harden.sh dns_monitor.sh dns_status.sh dns_alert.sh dns_restore.sh dns_tls_monitor.sh dns_monitoring_install.sh dns_monitoring_uninstall.sh; do
    echo "Checking $script..."
    grep -r "$script" .. --exclude-dir=.git --exclude="$script" || echo "  No references found"
done

# Delete DNS scripts
rm -f dns_harden.sh
rm -f dns_monitor.sh
rm -f dns_status.sh
rm -f dns_alert.sh
rm -f dns_restore.sh
rm -f dns_tls_monitor.sh
rm -f dns_monitoring_install.sh
rm -f dns_monitoring_uninstall.sh

# Verify deletions
ls -la dns_*.sh 2>/dev/null || echo "All DNS scripts deleted"
```

**Files Removed:** 8 DNS scripts

---

## PHASE 8: DELETE OLD HARDENING SCRIPTS

**CRITICAL: Superseded by modules/***

```bash
cd /home/dbcooper/parrot-booty-protection/scripts

# Verify no references exist
for script in ntp_harden.sh port_harden.sh service_harden.sh docker_dns_fix.sh; do
    echo "Checking $script..."
    grep -r "$script" .. --exclude-dir=.git --exclude="$script" || echo "  No references found"
done

# Delete hardening scripts
rm -f ntp_harden.sh
rm -f port_harden.sh
rm -f service_harden.sh
rm -f docker_dns_fix.sh

# Verify deletions
ls -la ntp_harden.sh port_harden.sh service_harden.sh docker_dns_fix.sh 2>/dev/null || echo "All hardening scripts deleted"
```

**Files Removed:** 4 hardening scripts

---

## PHASE 9: DELETE ORPHANED INSTALLERS

**CRITICAL: Install dead code**

```bash
cd /home/dbcooper/parrot-booty-protection

# Verify no references exist
grep -r "install_ops.sh" . --exclude-dir=.git --exclude=install_ops.sh || echo "No references found"
grep -r "install_pbp.sh" . --exclude-dir=.git --exclude=install_pbp.sh || echo "No references found"

# Delete orphaned installers
rm -f scripts/install_ops.sh
rm -f install_pbp.sh

# Verify deletions
ls -la scripts/install_ops.sh install_pbp.sh 2>/dev/null || echo "Orphaned installers deleted"
```

**Files Removed:** 2 installers

---

## PHASE 10: VERIFY CLEANUP

```bash
cd /home/dbcooper/parrot-booty-protection

# Count remaining files
echo "=== File Count ==="
find . -type f -not -path './.git/*' | wc -l

# Check for orphaned references
echo "=== Checking for Broken References ==="
grep -r "hardening-framework" . --exclude-dir=.git --exclude-dir=docs/archive || echo "✓ No hardening-framework references"
grep -r "pbp-ops" . --exclude-dir=.git --exclude-dir=docs/archive || echo "✓ No pbp-ops references"
grep -r "pbp-core" . --exclude-dir=.git --exclude-dir=docs/archive || echo "✓ No pbp-core references"

# Verify active executables still work
echo "=== Verifying Active Executables ==="
/opt/pbp/bin/pbp version || echo "✗ pbp CLI broken"
/opt/pbp/bin/pbp-dashboard --help 2>&1 | head -1 || echo "✗ pbp-dashboard broken"
/opt/pbp/bin/pbp-report --help 2>&1 | head -1 || echo "✗ pbp-report broken"
/usr/local/bin/dns-sovereignty-guard check || echo "✗ dns-sovereignty-guard broken"

# Check git status
echo "=== Git Status ==="
git status --short
```

---

## PHASE 11: COMMIT CLEANUP

```bash
cd /home/dbcooper/parrot-booty-protection

# Stage all deletions
git add -A

# Commit with detailed message
git commit -m "Repository cleanup: Remove dead code and archive historical docs

Removed:
- hardening-framework/ (80+ files, orphaned)
- pbp-ops/ (40+ files, partial implementation)
- pbp-core/ (40+ files, superseded)
- scripts/dns_*.sh (8 files, superseded)
- scripts/ntp_harden.sh, port_harden.sh, service_harden.sh, docker_dns_fix.sh (4 files, superseded)
- scripts/install_ops.sh, install_pbp.sh (2 files, orphaned)
- README_OLD.md, docs/CONTROL_RESTORATION_SUMMARY.md (2 files, deprecated)

Archived:
- 21 historical documentation files to docs/archive/

Total files removed: ~180
Total files archived: 21

Audit reports:
- REPO_INVENTORY.md
- EXECUTION_GRAPH.md
- DOCUMENT_STATUS.md
- CRUFT_REPORT.md
- PROMPT_COMPLETION_STATUS.md
- ACTIVE_SECURITY_STACK.md
- DEPRECATION_PLAN.md
- PBP_REPOSITORY_HEALTH.md"

# Create post-cleanup tag
git tag -a post-cleanup-audit -m "State after cleanup audit 2026-02-26"

# Push changes (if remote configured)
git push origin master
git push origin post-cleanup-audit
```

---

## PHASE 12: UPDATE DOCUMENTATION

```bash
cd /home/dbcooper/parrot-booty-protection

# Update README.md to remove references to deleted code
# (Manual edit required - remove any mentions of hardening-framework, pbp-ops, pbp-core)

# Update CHANGELOG.md
cat >> CHANGELOG.md << 'EOF'

## [2.0.1] - 2026-02-26

### Removed
- Hardening framework (orphaned parallel implementation)
- PBP-Ops (incomplete Python web app)
- PBP-Core (superseded shadow implementation)
- Old DNS scripts (superseded by modules/dns + dns-sovereignty-guard)
- Old hardening scripts (superseded by modules/*)
- Orphaned installers (install_ops.sh, install_pbp.sh)
- Deprecated documentation (README_OLD.md, CONTROL_RESTORATION_SUMMARY.md)

### Changed
- Archived 21 historical documentation files to docs/archive/
- Cleaned up repository structure (removed ~180 dead code files)

### Added
- Repository audit reports (8 comprehensive analysis documents)
- docs/archive/ directory for historical documentation
EOF

# Commit documentation updates
git add README.md CHANGELOG.md
git commit -m "docs: Update README and CHANGELOG after cleanup"
git push origin master
```

---

## ROLLBACK PROCEDURE

**If cleanup causes issues:**

```bash
cd /home/dbcooper/parrot-booty-protection

# Option 1: Restore from backup
cd ..
tar -xzf pbp-backup-*.tar.gz -C parrot-booty-protection-restored/

# Option 2: Revert to pre-cleanup tag
git checkout pre-cleanup-audit

# Option 3: Revert specific commits
git log --oneline | head -5
git revert <commit-hash>
```

---

## SAFE DELETION CHECKLIST

Before executing cleanup:

- [ ] Backup created and verified
- [ ] Git tag created (pre-cleanup-audit)
- [ ] No active PBP processes running (`ps aux | grep pbp`)
- [ ] No systemd services using deleted code (`systemctl list-units pbp-*`)
- [ ] Grep verification completed (no references to deleted code)
- [ ] Test environment available (not production)

After executing cleanup:

- [ ] Active executables still work (`pbp version`, `pbp-dashboard`, `pbp-report`, `dns-sovereignty-guard`)
- [ ] No broken references (`grep -r "hardening-framework\|pbp-ops\|pbp-core"`)
- [ ] Git status clean
- [ ] Commit created with detailed message
- [ ] Post-cleanup tag created
- [ ] Documentation updated (README.md, CHANGELOG.md)

---

## ESTIMATED IMPACT

### Disk Space
- Before cleanup: ~15 MB
- After cleanup: ~12 MB
- Space recovered: ~3 MB

### File Count
- Before cleanup: ~950 files
- After cleanup: ~770 files
- Files removed: ~180 files

### Code Lines
- Before cleanup: ~12,000 lines
- After cleanup: ~6,400 lines
- Lines removed: ~5,600 lines (dead code)

### Repository Health
- Before: 3 parallel implementations, 27 duplicate implementations, 180+ dead code files
- After: 1 unified implementation, 0 duplicates, 0 dead code

---

## POST-CLEANUP VERIFICATION

```bash
# Run full test suite
cd /home/dbcooper/parrot-booty-protection
bash tests/validate_core.sh

# Run demo
bash demo.sh

# Test CLI
pbp list
pbp status
pbp health

# Test dashboard
pbp dashboard
# (Press 'q' to quit)

# Test reporting
sudo pbp scan
pbp reports

# Test DNS guard
sudo dns-sovereignty-guard check

# Test bug hunt
sudo pbp bughunt
```

---

## SUCCESS CRITERIA

Cleanup is successful if:

1. ✓ All active executables work (`pbp`, `pbp-dashboard`, `pbp-report`, `dns-sovereignty-guard`)
2. ✓ All modules load correctly (`pbp list`)
3. ✓ Health checks pass (`pbp health`)
4. ✓ Scans execute (`pbp scan`)
5. ✓ Reports generate (`pbp reports`)
6. ✓ No broken references (`grep` verification)
7. ✓ Git history preserved (tags created)
8. ✓ Backup available (tar.gz file)
9. ✓ Documentation updated (README.md, CHANGELOG.md)
10. ✓ Repository structure clean (no orphaned files)

---

## NEXT STEPS

Proceed to **PHASE 8: PBP_REPOSITORY_HEALTH.md** for final health assessment and top 10 cleanup actions.
