# Repository Guidelines

## Project Structure & Module Organization
- `core/` holds the core engine, state, registry, and shared libraries used by the CLI.
- `modules/` contains security modules (e.g., `modules/dns/`, `modules/time/`). Use `modules/_template/` as the starting point and keep `manifest.json` in sync with hook scripts (`install.sh`, `enable.sh`, `disable.sh`, `scan.sh`, `health.sh`).
- `scripts/` provides install and operational helpers (e.g., `scripts/install.sh`, `scripts/install_control.sh`).
- `systemd/` contains unit files for services/timers.
- `reporting/` and `reporting/parsers/` implement report generation.
- `ui/` hosts the local web control plane assets.
- `tests/` contains shell-based validation suites.
- `docs/` holds design and operational documentation.

## Build, Test, and Development Commands
- `sudo bash scripts/install.sh`: install PBP and core assets.
- `sudo bash scripts/install_control.sh`: install the control plane.
- `sudo bash scripts/install_reporting_deps.sh`: install PDF/report dependencies.
- `pbp control start`: start the local control plane (access at `http://localhost:7777`).
- `pbp list`, `pbp status`, `pbp scan`: inspect modules, system status, and run scans.
- `bash tests/test_core.sh`: full core engine test suite.
- `bash tests/validate_core.sh`: quick core validation.
- `bash tests/test_report.sh`: generate a sample report in `/tmp`.

## Coding Style & Naming Conventions
- Shell scripts must start with `set -euo pipefail` and use the shared logging helpers (`log_info`, `log_warn`, `log_error`) from `core/lib/logging.sh`.
- Keep user-facing strings in the project’s pirate theme.
- Module naming: directory name == module name (e.g., `modules/dns/`) and reflected in `manifest.json`.
- Indentation: 2 spaces for JSON, 4 spaces for shell script blocks as used in existing scripts.
- Prefer explicit, readable bash over clever one-liners; add brief comments for non-obvious logic.

## Testing Guidelines
- Tests are shell-based; run them locally before PRs.
- When adding modules or changing system behavior, validate with `sudo pbp scan` and verify module health.
- Test on Parrot OS or Debian, as documented in `README.md` and `CONTRIBUTING.md`.

## Commit & Pull Request Guidelines
- Commit messages are short and descriptive; the history commonly uses `feat:`, `fix:`, and `docs:` prefixes.
- Branch naming: `feat/<short-scope>` or `fix/<short-scope>` (example: `fix/scan-timeout`).
- PRs should include a clear summary, test commands run, and any operational impact or rollback notes.
- If changes touch the UI or reporting output, include screenshots or sample reports.

## Security & Configuration Notes
- Do not introduce autonomous system changes without explicit operator control; this is a core project principle.
- Configuration sources live in `config/` and `configs/`. Keep defaults safe and reversible.
- For vulnerabilities, follow `SECURITY.md` and coordinate responsibly.
## Operational Best Practices
- Favor least-privilege execution. Use `sudo` only when a script requires it.
- Avoid writing outside `/tmp` during tests unless the script is explicitly installing or configuring system files.
- If you add a new systemd unit, include a matching `enable --now` example and rollback guidance.
