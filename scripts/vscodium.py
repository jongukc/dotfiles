#!/usr/bin/env python3
"""Snapshot VSCodium or deploy the portable editor config without copying private state."""
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
VSCODE_CONFIG = ROOT / 'configs/Code/User'
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

def user_directory(vscode=False):
    application = 'Code' if vscode else 'VSCodium'
    if sys.platform == 'win32':
        base = pathlib.Path(os.environ['APPDATA'])
    elif sys.platform == 'darwin':
        base = pathlib.Path.home() / 'Library/Application Support'
    else:
        base = pathlib.Path(os.environ.get('XDG_CONFIG_HOME') or pathlib.Path.home()/'.config')
    return base / application / 'User'

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

def deploy(destination, cli, skip_extensions=False, *, vscode=False):
    source = VSCODE_CONFIG if vscode else CONFIG
    backup_name = 'vscode' if vscode else 'vscodium'
    destination.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    if sys.platform != 'win32' and not shutil.which('lazygit') and not skip_extensions:
        install_lazygit()
    for name in ('settings.json', 'keybindings.json'):
        target = destination/name
        content = (source/name).read_bytes()
        if name == 'settings.json' and sys.platform != 'win32':
            settings = load_jsonc(source/name)
            for executable, key in (('clangd', 'clangd.path'), ('shfmt', 'shellformat.path'), ('lazygit', 'lazygit-vscode.lazygitPath')):
                binary = shutil.which(executable)
                if binary: settings[key] = binary
            content = (json.dumps(settings, indent=4, ensure_ascii=False)+'\n').encode('utf-8')
        if target.exists() and target.read_bytes() == content: continue
        if target.exists():
            backup = pathlib.Path.home()/'.dotfiles-backup'/stamp/backup_name
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
    parser.add_argument('--cli')
    parser.add_argument('--directory', type=pathlib.Path)
    parser.add_argument('--vscode', action='store_true', help='install into Visual Studio Code')
    parser.add_argument('--skip-extensions', action='store_true')
    args = parser.parse_args()
    if args.action == 'snapshot' and args.vscode:
        parser.error('--vscode is only supported for install')
    command = 'code' if args.vscode else 'codium'
    cli = args.cli or shutil.which(command) or shutil.which(command + '.cmd') or command
    directory = args.directory or user_directory(args.vscode)
    if args.action == 'snapshot':
        snapshot(directory, cli)
    else:
        deploy(directory, cli, args.skip_extensions, vscode=args.vscode)
