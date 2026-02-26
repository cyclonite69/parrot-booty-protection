import os
import subprocess
import json
import datetime
from typing import List, Dict

PBP_ROOT = "/opt/parrot-booty-protection"
MODULES_DIR = f"{PBP_ROOT}/modules"
REPORTS_DIR = f"{PBP_ROOT}/reports"
LOGS_DIR = f"{PBP_ROOT}/logs"
REGISTRY_FILE = f"{PBP_ROOT}/state/registry.json"

class PBPCore:
    def __init__(self):
        self.PBP_ROOT = "/opt/parrot-booty-protection"
        self.MODULES_DIR = f"{self.PBP_ROOT}/modules"
        self.REPORTS_DIR = f"{self.PBP_ROOT}/reports"
        self.LOGS_DIR = f"{self.PBP_ROOT}/logs"
        self.REGISTRY_FILE = f"{self.PBP_ROOT}/state/registry.json"
        self._ensure_dirs()
        self.load_registry()

    def _ensure_dirs(self):
        for d in [self.REPORTS_DIR, self.LOGS_DIR, f"{self.PBP_ROOT}/state"]:
            os.makedirs(d, exist_ok=True)

    def load_registry(self):
        if os.path.exists(self.REGISTRY_FILE):
            with open(self.REGISTRY_FILE, 'r') as f:
                self.registry = json.load(f)
        else:
            self.registry = {}

    def save_registry(self):
        with open(self.REGISTRY_FILE, 'w') as f:
            json.dump(self.registry, f, indent=2)

    def run_module_script(self, module_name: str, script_type: str):
        """Types: install, run, status"""
        script_path = f"{self.MODULES_DIR}/{module_name}/{script_type}.sh"
        if not os.path.exists(script_path):
            return {"status": "error", "message": f"Script {script_type}.sh not found for {module_name}"}

        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = f"{self.LOGS_DIR}/{module_name}_{script_type}_{timestamp}.log"

        try:
            # Execute and capture output
            result = subprocess.run(
                ["bash", script_path],
                capture_output=True,
                text=True,
                env={**os.environ, "PBP_ROOT": self.PBP_ROOT, "MODULE_NAME": module_name}
            )
            
            with open(log_file, "w") as f:
                f.write(result.stdout)
                f.write(result.stderr)

            # Update registry status if it's a status check
            if script_type == "status":
                is_active = "active" in result.stdout.lower()
                self.registry[module_name] = self.registry.get(module_name, {})
                self.registry[module_name]["active"] = is_active
                self.save_registry()

            return {
                "status": "success" if result.returncode == 0 else "failed",
                "stdout": result.stdout,
                "stderr": result.stderr,
                "exit_code": result.returncode
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}

    def get_reports(self, module_name: str = None):
        reports = []
        search_dir = f"{self.REPORTS_DIR}/{module_name}" if module_name else self.REPORTS_DIR
        for root, dirs, files in os.walk(search_dir):
            for file in files:
                reports.append({
                    "name": file,
                    "path": os.path.join(root, file),
                    "module": os.path.basename(root),
                    "mtime": os.path.getmtime(os.path.join(root, file))
                })
        return sorted(reports, key=lambda x: x['mtime'], reverse=True)
