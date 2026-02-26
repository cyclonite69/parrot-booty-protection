from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import sys
import os

# Add lib to path
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "lib"))
from pbp_core import PBPCore

app = FastAPI(title="Parrot Booty Protection Ops")
core = PBPCore()

# Define available modules for UI
MODULE_DEFS = {
    "rootkit": "Rootkit Sentry (rkhunter/chkrootkit)",
    "network": "Network Exposure (Nmap)",
    "dns": "DNS Hardening (DoT/DNSSEC)",
    "time": "Encrypted Time (NTS)",
    "firewall": "Firewall (nftables)",
    "system": "System Hardening Pack",
    "container": "Container Audit (Podman)",
    "ipv6": "IPv6 Policy Control"
}

@app.get("/api/modules")
async def list_modules():
    core.load_registry()
    modules = []
    for m_id, m_name in MODULE_DEFS.items():
        status = core.registry.get(m_id, {"active": False, "installed": False})
        modules.append({
            "id": m_id,
            "name": m_name,
            "active": status.get("active", False),
            "installed": os.path.exists(f"{core.MODULES_DIR}/{m_id}/run.sh")
        })
    return modules

@app.post("/api/modules/{module_id}/{action}")
async def manage_module(module_id: str, action: str):
    if action not in ["install", "run", "status"]:
        raise HTTPException(status_code=400, detail="Invalid action")
    
    result = core.run_module_script(module_id, action)
    return result

@app.get("/api/reports")
async def list_reports(module: str = None):
    return core.get_reports(module)

@app.get("/api/reports/{module}/{filename}")
async def get_report_content(module: str, filename: str):
    path = os.path.join(core.REPORTS_DIR, module, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Report not found")
    with open(path, 'r') as f:
        return {"content": f.read()}

@app.get("/", response_class=HTMLResponse)
async def dashboard():
    return """
    <html>
        <head>
            <title>PBP Ops Console</title>
            <style>
                body { 
                    background: #000000; 
                    color: #ffffff; 
                    font-family: 'Segoe UI', Arial, sans-serif; 
                    margin: 40px; 
                    line-height: 1.6;
                }
                .module-card { 
                    background: #1a1a1a; 
                    border: 2px solid #333333; 
                    padding: 25px; 
                    margin-bottom: 20px; 
                    border-radius: 4px; 
                }
                .module-card:hover { border-color: #ffd700; }
                h1 { color: #ffd700; border-bottom: 3px solid #ffd700; padding-bottom: 10px; text-transform: uppercase; letter-spacing: 2px; }
                h2 { color: #ffd700; margin-top: 50px; border-bottom: 1px solid #333; }
                h3 { color: #ffffff; margin-top: 0; font-size: 1.4em; }
                button { 
                    background: #ffd700; 
                    color: #000000; 
                    border: none; 
                    padding: 10px 20px; 
                    border-radius: 2px; 
                    cursor: pointer; 
                    font-family: inherit;
                    margin-right: 10px;
                    font-weight: bold;
                    text-transform: uppercase;
                }
                button:hover { background: #ffffff; }
                .status-on { color: #00ff00; font-weight: bold; background: #002200; padding: 2px 8px; border-radius: 3px; }
                .status-off { color: #ff0000; font-weight: bold; background: #220000; padding: 2px 8px; border-radius: 3px; }
                .report-link { color: #ffd700; font-weight: bold; text-decoration: none; border: 1px solid #ffd700; padding: 2px 10px; border-radius: 3px; cursor: pointer; }
                .report-link:hover { background: #ffd700; color: #000; }
                .report-item { background: #1a1a1a; border-left: 4px solid #ffd700; padding: 15px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }
                #viewer { 
                    display: none; 
                    position: fixed; 
                    top: 50px; left: 50px; right: 50px; bottom: 50px; 
                    background: #111; border: 3px solid #ffd700; padding: 30px; 
                    z-index: 100; overflow: auto; white-space: pre-wrap;
                    font-family: 'Courier New', monospace;
                }
                .close-viewer { position: absolute; top: 10px; right: 10px; color: #ff0000; cursor: pointer; font-weight: bold; }
            </style>
        </head>
        <body>
            <h1>🏴‍☠️ Parrot Booty Protection: Ops Command Center</h1>
            <div id="modules">Loading the ship's rigging...</div>
            
            <h2>📜 The Captain's Ledger (Reports)</h2>
            <div id="reports"></div>

            <div id="viewer">
                <span class="close-viewer" onclick="document.getElementById('viewer').style.display='none'">[X] CLOSE</span>
                <div id="viewer-content"></div>
            </div>

            <script>
                async function loadModules() {
                    const res = await fetch('/api/modules');
                    const mods = await res.json();
                    document.getElementById('modules').innerHTML = mods.map(m => `
                        <div class="module-card">
                            <h3>${m.name}</h3>
                            <p>Status: <span class="${m.active ? 'status-on' : 'status-off'}">${m.active ? 'SECURED' : 'UNSECURED'}</span></p>
                            <button onclick="action('${m.id}', 'install')">Install</button>
                            <button onclick="action('${m.id}', 'run')">Batten Down</button>
                            <button onclick="action('${m.id}', 'status')">Inspect</button>
                        </div>
                    `).join('');
                }

                async function action(id, type) {
                    const btn = event.target;
                    const oldText = btn.innerText;
                    btn.innerText = 'Working...';
                    
                    try {
                        const res = await fetch(`/api/modules/${id}/${type}`, {method: 'POST'});
                        const data = await res.json();
                        if (data.status === 'failed') alert('Failure in the rigging: ' + (data.stderr || data.message));
                    } catch (e) {
                        alert('System error: ' + e);
                    }
                    
                    btn.innerText = oldText;
                    loadModules();
                    loadReports();
                }

                async function viewReport(module, name) {
                    const res = await fetch(`/api/reports/${module}/${name}`);
                    const data = await res.json();
                    document.getElementById('viewer-content').innerText = data.content;
                    document.getElementById('viewer').style.display = 'block';
                }

                async function loadReports() {
                    const res = await fetch('/api/reports');
                    const reps = await res.json();
                    document.getElementById('reports').innerHTML = reps.map(r => `
                        <div class="report-item">
                            <div>
                                <span style="color:#8892b0">[${r.module}]</span> 
                                <span style="color:#ffffff; margin-left: 10px;">${r.name}</span>
                            </div>
                            <span class="report-link" onclick="viewReport('${r.module}', '${r.name}')">Open Ledger</span>
                        </div>
                    `).join('');
                }

                loadModules();
                loadReports();
                setInterval(loadModules, 30000);
            </script>
        </body>
    </html>
    """

