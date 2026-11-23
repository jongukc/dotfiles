#!/usr/bin/env python3
"""Package the upstream Dalbit theme at a pinned revision; no npm needed."""
import pathlib
import urllib.request
import zipfile

REVISION = 'e5d2081bed3a18e84beb964f2273cbb036575afa'
BASE = f'https://raw.githubusercontent.com/jongukc/dalbit.vscode/{REVISION}/'
OUTPUT = pathlib.Path(__file__).resolve().parents[1] / 'configs/vscodium/dalbit.vsix'
MANIFEST = '''<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
<Metadata><Identity Language="en-US" Id="dalbit" Version="0.1.0" Publisher="jongukc"/>
<DisplayName>Dalbit</DisplayName><Description xml:space="preserve">Warm accents on neutral dark</Description>
<Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.55.0"/></Properties>
<Categories>Themes</Categories></Metadata><Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
<Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets></PackageManifest>'''
TYPES = '''<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="json" ContentType="application/json"/>
<Default Extension="vsixmanifest" ContentType="text/xml"/></Types>'''

if __name__ == '__main__':
    files = {'extension.vsixmanifest': MANIFEST.encode(), '[Content_Types].xml': TYPES.encode()}
    for name in ('package.json', 'themes/dalbit-color-theme.json'):
        with urllib.request.urlopen(BASE + name, timeout=60) as response:
            files['extension/' + name] = response.read()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUTPUT, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, content)
    print(OUTPUT)
