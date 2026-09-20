#!/usr/bin/env python3
"""Build the isolated Forever package with pinned, unmodified release libraries."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
VERSION = '5.22.0-forever.2'
URL = 'https://github.com/WeakAuras/WeakAuras2/releases/download/5.22.0/WeakAuras-5.22.0.zip'
SHA256 = '298d3cbaa129af3e734f5bd4f87911acab9b10f10d079004b770fa43980cd4a9'
PACKAGES = ('WeakAuras', 'WeakAurasOptions', 'WeakAurasArchive', 'WeakAurasModelPaths')
parser = argparse.ArgumentParser()
parser.add_argument('--dependencies', type=Path, default=Path('/tmp/WeakAuras-5.22.0.zip'))
args = parser.parse_args()
if not args.dependencies.exists():
    urllib.request.urlretrieve(URL, args.dependencies)
assert hashlib.sha256(args.dependencies.read_bytes()).hexdigest() == SHA256, 'Dependency archive checksum mismatch'
stage = ROOT / '.release' / 'forever'
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir(parents=True)
tracked = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).decode().split('\0')
for name in tracked:
    source = ROOT / name
    if not name or name.split('/')[0] not in PACKAGES or not source.is_file():
        continue
    if source.suffix == '.toc':
        if not name.endswith('_Forever.toc'):
            continue
        name = name.replace('_Forever.toc', '.toc')
    target = stage / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
with zipfile.ZipFile(args.dependencies) as archive:
    for name in archive.namelist():
        if name.startswith(('WeakAuras/Libs/', 'WeakAurasOptions/Libs/')) and not name.endswith('/'):
            target = stage / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
for name in ('LICENSE', 'FOREVER.md'):
    shutil.copyfile(ROOT / name, stage / 'WeakAuras' / name)

# Validate every file reached by each TOC and XML include in client load order.
seen = set()
def check(path):
    assert path.is_file(), f'Missing client load dependency: {path.relative_to(stage)}'
    if path in seen:
        return
    seen.add(path)
    if path.suffix == '.xml':
        for node in ET.parse(path).iter():
            filename = node.attrib.get('file')
            if filename and node.tag.rsplit('}', 1)[-1] in ('Script', 'Include'):
                check(path.parent / filename.replace('\\', '/'))
    elif path.suffix == '.lua':
        subprocess.run(['luac5.1', '-p', str(path)], check=True, capture_output=True)
for package in PACKAGES:
    toc = stage / package / (package + '.toc')
    assert '## Interface: 16001' in toc.read_text()
    for line in toc.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            check(toc.parent / line.replace('\\', '/'))

output = ROOT / '.release' / f'WeakAurasForever-{VERSION}.zip'
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(stage.rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(stage))
print(f'Validated {len(seen)} client load dependencies (including Lua 5.1 syntax).')
print(output)
print('SHA256', hashlib.sha256(output.read_bytes()).hexdigest())
