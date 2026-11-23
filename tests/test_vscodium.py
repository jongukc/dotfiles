import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('vscodium', ROOT/'scripts/vscodium.py')
vscodium = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vscodium)


class VSCodiumConfigTests(unittest.TestCase):
    def test_jsonc_preserves_comment_characters_inside_strings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)/'settings.json'
            path.write_text('{/* comment */"url":"https://example.com/a//b",\n'
                            '"text":"comma,} and \\\"quote\\\"",//comment\n"list":[1,2,],}', encoding='utf-8')
            result = vscodium.load_jsonc(path)
            self.assertEqual(result['url'], 'https://example.com/a//b')
            self.assertEqual(result['text'], 'comma,} and "quote"')
            self.assertEqual(result['list'], [1, 2])

    def test_deploy_backs_up_existing_config_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config = root/'source'
            destination = root/'destination'
            config.mkdir(); destination.mkdir()
            for name in ('settings.json', 'keybindings.json'):
                (config/name).write_text('{"new": true}', encoding='utf-8')
                (destination/name).write_text('original-'+name, encoding='utf-8')
            (destination/'private-storage').write_text('retain', encoding='utf-8')
            with mock.patch.object(vscodium, 'CONFIG', config), \
                 mock.patch.object(vscodium.sys, 'platform', 'win32'), \
                 mock.patch.object(pathlib.Path, 'home', return_value=root), \
                 mock.patch.object(vscodium.subprocess, 'run') as run:
                vscodium.deploy(destination, 'unused', skip_extensions=True)
                first_backups = list((root/'.dotfiles-backup').rglob('*.json'))
                self.assertEqual(len(first_backups), 2)
                self.assertEqual({p.read_text() for p in first_backups},
                                 {'original-settings.json', 'original-keybindings.json'})
                vscodium.deploy(destination, 'unused', skip_extensions=True)
                self.assertEqual(len(list((root/'.dotfiles-backup').rglob('*.json'))), 2)
                run.assert_not_called()
            self.assertEqual((destination/'private-storage').read_text(), 'retain')

    def test_snapshot_omits_machine_paths_and_packages_dalbit_separately(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory); source = root/'user'; source.mkdir()
            settings = {key: 'machine-specific' for key in vscodium.MACHINE_KEYS}
            settings['workbench.colorTheme'] = 'Dalbit'
            (source/'settings.json').write_text(json.dumps(settings), encoding='utf-8')
            (source/'keybindings.json').write_text('[]', encoding='utf-8')
            result = subprocess.CompletedProcess([], 0, 'vscodevim.vim\njongukc.dalbit\n', '')
            with mock.patch.object(vscodium, 'CONFIG', root/'snapshot'), \
                 mock.patch.object(vscodium.subprocess, 'run', return_value=result):
                vscodium.snapshot(source, 'codium')
            captured = json.loads((root/'snapshot/settings.json').read_text())
            self.assertEqual(captured, {'workbench.colorTheme': 'Dalbit'})
            self.assertEqual((root/'snapshot/extensions.txt').read_text(), 'vscodevim.vim\n')

    def test_portable_snapshot_has_no_windows_home_paths(self):
        settings = vscodium.load_jsonc(ROOT/'configs/vscodium/settings.json')
        self.assertFalse(set(settings) & set(vscodium.MACHINE_KEYS))
        self.assertNotIn('C:/Users/', json.dumps(settings))
        self.assertNotIn('C:\\\\Users\\\\', json.dumps(settings))
        self.assertEqual(settings['workbench.colorTheme'], 'Dalbit')
        self.assertEqual(settings['prettier.tabWidth'], 4)
        self.assertFalse(settings['editor.detectIndentation'])


if __name__ == '__main__': unittest.main()
