#!/usr/bin/env python3
"""Snapshot/deploy the portable VSCodium config without copying private state."""
import argparse
import datetime
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import platform

ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'configs/vscodium'
MACHINE_KEYS = ('clangd.path', 'shellformat.path', 'lazygit-vscode.lazygitPath',
                'terminal.integrated.profiles.windows', 'terminal.integrated.defaultProfile.windows',
                'terminal.integrated.env.windows')

def load_jsonc(path):
    text = pathlib.Path(path).read_text(encoding='utf-8-sig')
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,(\s*[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else m[1], text)
    return json.loads(text)

def user_directory():
    if sys.platform == 'win32': return pathlib.Path(os.environ['APPDATA']) / 'VSCodium/User'
    if sys.platform == 'darwin': return pathlib.Path.home() / 'Library/Application Support/VSCodium/User'
    return pathlib.Path(os.environ.get('XDG_CONFIG_HOME', pathlib.Path.home()/'.config')) / 'VSCodium/User'

def snapshot(source, cli):
    CONFIG.mkdir(parents=True, exist_ok=True)
    settings = load_jsonc(source/'settings.json')
    for key in MACHINE_KEYS: settings.pop(key, None)
    (CONFIG/'settings.json').write_text(json.dumps(settings, indent=4, ensure_ascii=False)+'\n', encoding='utf-8')
    keys = load_jsonc(source/'keybindings.json')
    (CONFIG/'keybindings.json').write_text(json.dumps(keys, indent=4, ensure_ascii=False)+'\n', encoding='utf-8')
    result = subprocess.run([cli, '--list-extensions'], check=True, capture_output=True, text=True)
    extensions = sorted({line.strip() for line in result.stdout.splitlines()
                         if re.fullmatch(r'[\w-]+\.[\w.-]+', line.strip()) and line.strip().lower() != 'jongukc.dalbit'})
    (CONFIG/'extensions.txt').write_text('\n'.join(extensions)+'\n', encoding='utf-8')

def deploy(destination, cli, skip_extensions=False):
    destination.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    if sys.platform != 'win32' and not shutil.which('lazygit') and not skip_extensions:
        install_lazygit()
    for name in ('settings.json', 'keybindings.json'):
        target = destination/name
        content = (CONFIG/name).read_bytes()
        if name == 'settings.json' and sys.platform != 'win32':
            settings = load_jsonc(CONFIG/name)
            for executable, key in (('clangd', 'clangd.path'), ('shfmt', 'shellformat.path'), ('lazygit', 'lazygit-vscode.lazygitPath')):
                binary = shutil.which(executable)
                if binary: settings[key] = binary
            content = (json.dumps(settings, indent=4, ensure_ascii=False)+'\n').encode('utf-8')
        if target.exists() and target.read_bytes() == content: continue
        if target.exists():
            backup = pathlib.Path.home()/'.dotfiles-backup'/stamp/'vscodium'
            backup.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup/name)
        target.write_bytes(content)
    if not skip_extensions:
        installed = set(subprocess.check_output([cli, '--list-extensions'], text=True).lower().splitlines())
        for extension in (CONFIG/'extensions.txt').read_text().splitlines():
            if extension and not extension.startswith('#') and extension.lower() not in installed:
                subprocess.run([cli, '--install-extension', extension], check=True)
        if 'jongukc.dalbit' not in installed:
            subprocess.run([cli, '--install-extension', str(CONFIG/'dalbit.vsix')], check=True)

def install_lazygit():
    """Debian/Ubuntu do not consistently package LazyGit; use its official release."""
    request = urllib.request.Request('https://api.github.com/repos/jesseduffield/lazygit/releases/latest', headers={'User-Agent': 'dotfiles'})
    with urllib.request.urlopen(request, timeout=60) as response: release = json.load(response)
    arch = {'aarch64': 'arm64', 'arm64': 'arm64', 'x86_64': 'x86_64'}.get(platform.machine())
    if arch is None: raise RuntimeError('Unsupported LazyGit architecture: '+platform.machine())
    suffix = f'_{platform.system().lower()}_{arch}.tar.gz'
    asset = next(a for a in release['assets'] if a['name'].lower().endswith(suffix))
    destination = pathlib.Path.home()/'.local/bin/lazygit'
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryFile() as download:
        with urllib.request.urlopen(asset['browser_download_url'], timeout=120) as response:
            shutil.copyfileobj(response, download)
        download.seek(0)
        with tarfile.open(fileobj=download, mode='r:gz') as archive:
            member = next(m for m in archive.getmembers() if pathlib.PurePosixPath(m.name).name == 'lazygit' and m.isfile())
            with archive.extractfile(member) as binary: destination.write_bytes(binary.read())
    destination.chmod(0o755)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('snapshot', 'install'))
    parser.add_argument('--cli', default=shutil.which('codium') or shutil.which('codium.cmd') or 'codium')
    parser.add_argument('--directory', type=pathlib.Path, default=user_directory())
    parser.add_argument('--skip-extensions', action='store_true')
    args = parser.parse_args()
    if args.action == 'snapshot': snapshot(args.directory, args.cli)
    else: deploy(args.directory, args.cli, args.skip_extensions)
