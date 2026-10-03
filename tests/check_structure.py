"""Verify addon load paths, XML scripts, bundled assets and Lua compilation.
Run from repository root: python3 tests/check_structure.py
Requires luatex (or lua) on PATH. Does not start or alter WoW.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
loaded = set()
inline = []

def inspect(path):
    assert path.is_file(), f'Missing load path: {path.relative_to(root)}'
    if path in loaded:
        return
    loaded.add(path)
    if path.suffix.lower() == '.xml':
        tree = ET.parse(path)
        for node in tree.iter():
            tag = node.tag.rsplit('}', 1)[-1]
            if tag in ('Include', 'Script') and node.get('file'):
                inspect(path.parent / node.get('file').replace('\\', '/'))
            if tag.startswith('On') or tag in ('PreClick', 'PostClick'):
                source = ''.join(node.itertext()).strip()
                if source:
                    inline.append((path.name + ':' + tag, source))

for line in (root / 'VoidMark.toc').read_text().splitlines():
    if line.strip() and not line.startswith('#'):
        inspect(root / line.strip().replace('\\', '/'))

files = sorted(root.rglob('*.lua'))
script = []
for path in files:
    escaped = str(path).replace('\\', '\\\\').replace('"', '\\"')
    script.append(f'assert(loadfile("{escaped}"))')
for label, source in inline:
    # Scripts execute inside a function with Blizzard-provided arguments.
    script.append('assert((loadstring or load)([====[return function(self, button, down, elapsed, ...)\n' + source + '\nend]====], ' + repr(label) + '))')

# Check literal references to assets owned by this addon. Dynamic roots in Kill
# Effects are handled below. Blizzard-owned Interface paths are not local files.
for path in files:
    if 'Libs' in path.parts:
        continue
    source = re.sub(r"^\s*--[^\n]*", "", path.read_text(), flags=re.MULTILINE)
    for asset in re.findall(r'"(Interface\\\\AddOns\\\\VoidMark\\\\[^"\n]+)"', source):
        normalized = asset.replace('\\\\', '/')
        relative = normalized.removeprefix('Interface/AddOns/VoidMark/')
        candidate = root / relative
        if relative.endswith('/'):
            assert candidate.is_dir(), f'Missing asset directory: {relative}'
        else:
            assert candidate.is_file(), f'Missing asset: {relative}'
for name in re.findall(r'"([a-z]+\.ogg)"', (root / 'KillEffects.lua').read_text()):
    assert (root / 'Sounds' / 'KillEffects' / name).is_file(), f'Missing sound: {name}'

script.append(f'print("PASS: {len(files)} Lua files, {len(inline)} XML scripts, all load paths and literal addon assets")')
runner = shutil.which('luatex') or shutil.which('lua')
assert runner, 'Install luatex or lua to run the syntax checks'
with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False) as temp:
    temp.write('\n'.join(script))
    temp_path = Path(temp.name)
try:
    command = [runner] + (['--luaonly'] if Path(runner).name == 'luatex' else []) + [str(temp_path)]
    result = subprocess.run(command, capture_output=True, text=True)
    print(result.stdout, end='')
    if result.stderr:
        print(result.stderr, end='')
    assert result.returncode == 0, 'Lua structure check failed'
finally:
    temp_path.unlink(missing_ok=True)
