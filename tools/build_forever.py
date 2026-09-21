#!/usr/bin/env python3
"""Build WAF with pinned, unmodified release libraries and legacy save loaders."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
VERSION = '5.22.0-waf.1'
URL = 'https://github.com/WeakAuras/WeakAuras2/releases/download/5.22.0/WeakAuras-5.22.0.zip'
SHA256 = '298d3cbaa129af3e734f5bd4f87911acab9b10f10d079004b770fa43980cd4a9'
PACKAGES = {
    'WeakAuras': 'WAF',
    'WeakAurasOptions': 'WAFOptions',
    'WeakAurasArchive': 'WAFArchive',
    'WeakAurasModelPaths': 'WAFModelPaths',
}
# Keep upstream source names for merging. Only on-disk asset paths change in
# the build: Lua globals, named frames, translations and wire IDs stay intact.
MEDIA_PATH = re.compile(r'(Interface[\\/]+AddOns[\\/]+)(WeakAuras(?:Options|Archive|ModelPaths)?)(?=[\\/])', re.I)
PACKAGE_CASE = {name.lower(): target for name, target in PACKAGES.items()}

def relocate_media(text):
    return MEDIA_PATH.sub(lambda match: match[1] + PACKAGE_CASE[match[2].lower()], text)

LEGACY_SAVES = {
    'WeakAuras': 'WeakAurasSaved',
    'WeakAurasOptions': 'WeakAurasOptionsSaved',
    'WeakAurasArchive': 'WeakAurasArchive',
}
parser = argparse.ArgumentParser()
parser.add_argument('--dependencies', type=Path, default=Path('/tmp/WeakAuras-5.22.0.zip'))
args = parser.parse_args()
if not args.dependencies.exists():
    urllib.request.urlretrieve(URL, args.dependencies)
assert hashlib.sha256(args.dependencies.read_bytes()).hexdigest() == SHA256, 'Dependency archive checksum mismatch'
stage = ROOT / '.release' / 'waf'
if stage.exists():
    shutil.rmtree(stage)
stage.mkdir(parents=True)
tracked = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).decode().split('\0')
for name in tracked:
    source = ROOT / name
    if not name or name.split('/')[0] not in PACKAGES or not source.is_file():
        continue
    package, relative = name.split('/', 1)
    if source.suffix == '.toc':
        if not name.endswith('_Forever.toc'):
            continue
        relative = PACKAGES[package] + '.toc'
    target = stage / PACKAGES[package] / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.suffix in ('.lua', '.xml', '.toc'):
        target.write_text(relocate_media(source.read_text()))
    else:
        shutil.copyfile(source, target)
with zipfile.ZipFile(args.dependencies) as archive:
    for name in archive.namelist():
        if name.startswith(('WeakAuras/Libs/', 'WeakAurasOptions/Libs/')) and not name.endswith('/'):
            package, relative = name.split('/', 1)
            target = stage / PACKAGES[package] / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
for name in ('LICENSE', 'FOREVER.md'):
    shutil.copyfile(ROOT / name, stage / 'WAF' / name)

# Required, data-only dependencies load legacy globals before WAF initializes.
# ForeverSavedVariables selects WAF's distinct saved global when it exists.
# WoW can flush the currently running old fork after this package is installed;
# the next login reads that final save without an external snapshot race.
for package, variable in LEGACY_SAVES.items():
    target = stage / package
    target.mkdir(parents=True, exist_ok=True)
    (target / (package + '.toc')).write_text(
        '## Interface: 16001\n'
        f'## Title: WAF - Legacy saves ({package})\n'
        '## Notes: Data-only compatibility loader for WAF. Keep enabled.\n'
        f'## Version: {VERSION}\n'
        '## DefaultState: Enabled\n'
        '## LoadOnDemand: 1\n'
        f'## SavedVariables: {variable}\n'
        '## LoadSavedVariablesFirst: 1\n'
        '## X-WAF-Legacy: 1\n'
    )
# Saved/imported auras can contain literal upstream media paths. Preserve those
# assets without rewriting aura names, custom code, text, or archived payloads.
shutil.copytree(ROOT / 'WeakAuras' / 'Media', stage / 'WeakAuras' / 'Media')

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
for package in (*PACKAGES.values(), *LEGACY_SAVES):
    toc = stage / package / (package + '.toc')
    assert '## Interface: 16001' in toc.read_text()
    for line in toc.read_text().splitlines():
        if line.startswith('## Dependencies:'):
            for dependency in line.split(':', 1)[1].split(','):
                dependency = dependency.strip()
                assert (stage / dependency / (dependency + '.toc')).is_file(), f'Missing addon dependency: {dependency}'
    for line in toc.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            check(toc.parent / line.replace('\\', '/'))

output = ROOT / '.release' / f'WAF-{VERSION}.zip'
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(stage.rglob('*')):
        if path.is_file():
            archive.write(path, path.relative_to(stage))
print(f'Validated {len(seen)} client load dependencies (including Lua 5.1 syntax).')
print(output)
print('SHA256', hashlib.sha256(output.read_bytes()).hexdigest())
