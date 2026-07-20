## Python Review Criteria
- Shell injection: Note subprocess/os.system with shell=True and interpolated input. RISKY: subprocess.run(f"git clone {arg}", shell=True)  SAFER: subprocess.run(["git","clone",arg])
- Dynamic execution and unsafe deserialization: Note eval, exec, pickle.loads, marshal.loads, or yaml.load (non-safe) on external data; base64-decode feeding any of these. RISKY: exec(base64.b64decode(s))  SAFER: yaml.safe_load; no dynamic exec
- Env-to-network flow: Note os.environ (or specific token vars) serialized or passed into requests/urllib/socket calls. RISKY: requests.post(u, json=dict(os.environ))  SAFER: env used only for documented config
- New network capability: Note newly added requests/urllib/socket/http.client imports or new destination URLs in a previously offline script. RISKY: new import socket + hardcoded IP  SAFER: unchanged endpoints
- Runtime installation: Note pip install executed by the code itself, --index-url/--extra-index-url changes, or direct-URL requirements. RISKY: subprocess.run(["pip","install","--index-url","https://mirror.dev", ...])  SAFER: pinned requirements installed by the workflow, standard index
- Persistence-adjacent writes: Note writes to ~/.ssh, shell profiles, sitecustomize.py, or .pth files. RISKY: open(os.path.expanduser("~/.ssh/authorized_keys"),"a")  SAFER: writes confined to the workspace
- Dynamic import: Note importlib.import_module(variable) or __import__ on non-literal input. RISKY: importlib.import_module(cfg["mod"])  SAFER: explicit imports
