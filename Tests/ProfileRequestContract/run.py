#!/usr/bin/env python3
"""Run real Swift ViewModel/APIClient contract tests without production Keychain access.
Usage: python3 Tests/ProfileRequestContract/run.py OUTPUT_DIR [swift test arguments]
OUTPUT_DIR must not already exist. All staged production files are byte-for-byte copies.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

here = Path(__file__).resolve().parent
root = here.parents[1]
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=False)
source = out / 'Sources'
source.mkdir()
paths = [
    'Services/APIClient.swift', 'ViewModels/ProfileViewModel.swift',
    'Models/User.swift', 'Models/Project.swift', 'Models/Notification.swift',
    'Models/Vendor.swift', 'Models/Designer.swift', 'Extensions/String+Display.swift',
]
hashes = {}
for relative in paths:
    original = root / 'Sources/KeyAtlas' / relative
    shutil.copy2(original, source / original.name)
    hashes[relative] = hashlib.sha256(original.read_bytes()).hexdigest()
shutil.copy2(here / 'Support/KeychainService.swift', source / 'KeychainService.swift')
shutil.copy2(here / 'Package.swift', out / 'Package.swift')
shutil.copy2(here / 'project.yml', out / 'project.yml')
shutil.copytree(here / 'Tests', out / 'Tests')
(out / 'production-source-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
# No app host, AuthService, Security import, real Keychain, or external dependencies.
result = subprocess.run(['swift', 'test', '--package-path', str(out)] + sys.argv[2:])
sys.exit(result.returncode)
