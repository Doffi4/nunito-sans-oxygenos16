"""Offline module checks; never connects to or changes an Android device."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
import struct

PACKAGE_FILES = {'module.prop', 'customize.sh', 'post-fs-data.sh', 'late-load.sh',
                 'nunito.conf', 'tools/root-manager.sh', 'tools/prepare-fonts.sh',
                 'tools/patch-sans-family.awk', 'system/fonts/Nunito-VF.ttf',
                 'system/fonts/Nunito-Italic-VF.ttf', 'LICENSES/OFL.txt'}

ROOT = Path(__file__).resolve().parents[1]
OPTIONS = None
CONTENT = '\n    <font weight="400" style="normal">Nunito-VF.ttf<axis tag="wght" stylevalue="450" /></font>\n'


def patch(xml, content=CONTENT):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "content.xml").write_text(content, encoding="utf-8")
        (tmp / "source.xml").write_text(xml, encoding="utf-8")
        return subprocess.run([OPTIONS.awk, "-v", f"replacement_file={(tmp / 'content.xml').as_posix()}",
                               "-f", str(ROOT / "tools/patch-sans-family.awk"),
                               str(tmp / "source.xml")], capture_output=True)


class PatchChecks(unittest.TestCase):
    def assert_preserved(self, xml):
        result = patch(xml)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        start = xml.index("<family ", xml.index("<familyset") if "<familyset" in xml else 0)
        start = xml.index(">", start) + 1
        end = xml.index("</family>", start)
        self.assertEqual(result.stdout.decode(), xml[:start] + CONTENT + xml[end:])
        ET.fromstring(result.stdout)

    def test_keeps_attributes_comments_fallbacks_and_no_final_newline(self):
        xml = '<?xml version="1.0"?>\n<familyset version="23">\n' \
              '<!-- example <family name="sans-serif"><font>Example.ttf</font></family> -->\n' \
              '<family name="sans-serif"><font>Roboto.ttf</font></family>\n' \
              '<family name="monospace"><font>Mono.ttf</font></family>\n' \
              '<family lang="und-Zsye"><font>NotoColorEmoji.ttf</font></family>\n' \
              '<alias name="sans-serif-light" to="sans-serif" weight="300" />\n</familyset>'
        # Skip the commented example when deriving the expected edit.
        result = patch(xml)
        start = xml.index('<family name="sans-serif">', xml.index("-->"))
        end = xml.index("</family>", start)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.decode(), xml[:start + len('<family name="sans-serif">')] + CONTENT + xml[end:])
        ET.fromstring(result.stdout)

    def test_product_customization_and_multiline_single_quoted_attributes(self):
        self.assert_preserved("<fonts-modification>\n<family\n customizationType='new-named-family'\n name = 'sans-serif'>\n<font>OEM.ttf</font>\n</family>\n</fonts-modification>".replace("<family\n", "<family \n"))

    def test_plain_family(self):
        self.assert_preserved('<familyset><family name="sans-serif"><font>Roboto.ttf</font></family><family><font>NotoSans.ttf</font></family></familyset>\n')

    def test_attribute_text_is_not_a_real_family_name(self):
        xml = '<familyset><family annotation="example name=\'sans-serif\'" name="monospace"><font>Mono.ttf</font></family><family name="sans-serif"><font>Roboto.ttf</font></family></familyset>'
        result = patch(xml)
        self.assertEqual(result.returncode, 0)
        before, after = xml.split('<family name="sans-serif">', 1)
        expected = before + '<family name="sans-serif">' + CONTENT + '</family>' + after.split('</family>', 1)[1]
        self.assertEqual(result.stdout.decode(), expected)

    def test_refuses_missing_duplicate_malformed_and_unsupported(self):
        examples = [
            '<familyset><family name="serif" /></familyset>',
            '<familyset><family name="sans-serif"><font>A.ttf</font></family><family name="sans-serif"><font>B.ttf</font></family></familyset>',
            '<familyset><family name="sans-serif"><font>A.ttf</font></family>',
            '<familyset><family name="sans-serif"><font>A.ttf</family></familyset>',
            '<familyset><family-list name="sans-serif"><family><font>A.ttf</font></family></family-list></familyset>',
            '<familyset><alias name="sans-serif" to="other" /></familyset>',
            '<fonts-modification><family name="sans-serif"><font>A.ttf</font></family></fonts-modification>',
            '<unknown><family name="sans-serif"><font>A.ttf</font></family></unknown>',
            '<familyset><!-- <family name="sans-serif"> --> <family name="serif" /></familyset>',
            '<familyset><family name="sans-serif" lang="ru"><font>A.ttf</font></family></familyset>',
            '<familyset><family name="sans-serif" lang=""><font>A.ttf</font></family></familyset>',
            '<familyset><family name="sans-serif" name="monospace"><font>A.ttf</font></family></familyset>',
            '<familyset><family annotation="example name=\'sans-serif\'" name="monospace"><font>Mono.ttf</font></family></familyset>',
        ]
        for xml in examples:
            with self.subTest(xml=xml):
                result = patch(xml)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, b"", "A rejected config must not emit partial XML")

    def test_captured_device_configs(self):
        if not OPTIONS.device_configs:
            self.skipTest("No private device snapshot directory supplied")
        for source in sorted(Path(OPTIONS.device_configs).glob("*.xml")):
            xml = source.read_text(encoding="utf-8")
            with self.subTest(file=source.name):
                self.assert_preserved(xml)


def shell(code, cwd=ROOT, extra_env=None):
    env = os.environ.copy()
    for key in ('KSU', 'APATCH', 'MAGISK_VER_CODE', 'BOOTMODE', 'API', 'KSU_LATE_LOAD'):
        env.pop(key, None)
    env.update(extra_env or {})
    if os.name == 'nt':
        for key in ('CHECK_MODDIR', 'CHECK_META'):
            if key in env and len(env[key]) > 2 and env[key][1] == ':':
                env[key] = '/' + env[key][0].lower() + env[key][2:]
    return subprocess.run([OPTIONS.shell, '-c', code], cwd=cwd, env=env, capture_output=True)


class RuntimeChecks(unittest.TestCase):
    def test_installer_manager_and_failure_gates(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'work') as tmp:
            folder = Path(tmp)
            for name in PACKAGE_FILES:
                target = folder / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            helper = folder / 'tools/root-manager.sh'
            helper.write_text(helper.read_text() + '\nmount_provider_ready() { [ "${CHECK_META_READY:-false}" = true ]; }\n', encoding='utf-8')
            generator = folder / 'tools/prepare-fonts.sh'
            generator.write_text(generator.read_text() + '\nprepare_fonts() { applied=1; }\n', encoding='utf-8')
            # Simulate read-only ROM availability and installer-provided utilities.
            # All module/permission operations are confined to this desktop fixture.
            code = '''abort() { printf '%s\\n' "$*" >&2; exit 90; }
ui_print() { printf '%s\\n' "$*"; }
set_perm() { :; }
set_perm_recursive() { :; }
getprop() { printf 'fixture-fingerprint'; }
[() {
    if command [ "$1" = -r ] && command [ "$2" = /system/etc/font_fallback.xml ]; then return 0; fi
    if command [ "$1" = ! ] && command [ "$2" = -r ] && command [ "$3" = /system/etc/font_fallback.xml ]; then return 1; fi
    command [ "$@"
}
MODPATH="$PWD"
. ./customize.sh
'''
            cases = [({'MAGISK_VER_CODE': '27000'}, 0, 'Magisk'),
                     ({'APATCH': 'true', 'APATCH_VER_CODE': '11107', 'MAGISK_VER_CODE': '27000'}, 0, 'APatch'),
                     ({'APATCH': 'true', 'APATCH_VER_CODE': '11224', 'CHECK_META_READY': 'true'}, 0, 'APatch'),
                     ({'APATCH': 'true', 'APATCH_VER_CODE': '11224'}, 90, 'metamodule'),
                     ({'KSU': 'true', 'MAGISK_VER_CODE': '25200', 'CHECK_META_READY': 'true'}, 0, 'KernelSU'),
                     ({'KSU': 'true'}, 90, 'metamodule'),
                     ({'KSU': 'true', 'CHECK_META_READY': 'true', 'KSU_LATE_LOAD': '1'}, 90, 'late-load'),
                     ({'MAGISK_VER_CODE': '27000', 'API': '35'}, 90, 'API 36'),
                     ({'MAGISK_VER_CODE': '27000', 'BOOTMODE': 'false'}, 90, 'recovery'),
                     ({}, 90, 'Unsupported root manager')]
            for values, expected, message in cases:
                env = {'BOOTMODE': 'true', 'API': '36', **values}
                result = shell(code, cwd=folder, extra_env=env)
                self.assertEqual(result.returncode, expected, result.stderr.decode())
                self.assertIn(message, (result.stdout + result.stderr).decode())

    def test_shell_syntax(self):
        for source in [ROOT / 'customize.sh', ROOT / 'post-fs-data.sh', ROOT / 'late-load.sh', *ROOT.glob('tools/*.sh')]:
            result = subprocess.run([OPTIONS.shell, '-n', str(source)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())

    def test_manager_detection_precedence(self):
        for env, expected in [({'APATCH': 'true', 'KSU': 'true', 'MAGISK_VER_CODE': '27000'}, 'APatch'),
                              ({'KSU': 'true', 'MAGISK_VER_CODE': '27000'}, 'KernelSU'),
                              ({'MAGISK_VER_CODE': '27000'}, 'Magisk')]:
            result = shell('. ./tools/root-manager.sh; detect_root_manager && printf "%s" "$ROOT_MANAGER"', extra_env=env)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout.decode(), expected)
        for value in ('', 'nonsense', '0'):
            result = shell('. ./tools/root-manager.sh; detect_root_manager', extra_env={'MAGISK_VER_CODE': value})
            self.assertNotEqual(result.returncode, 0)

    def test_metamodule_marker_and_disabled_state(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'work') as tmp:
            folder = Path(tmp)
            for marker, disabled, expected in [('1', False, 0), ('true', False, 0), ('false', False, 1), ('1', True, 1)]:
                (folder / 'module.prop').write_text(f'metamodule={marker}\n', encoding='utf-8')
                (folder / 'metamount.sh').write_text('#!/system/bin/sh\n', encoding='utf-8')
                (folder / 'disable').unlink(missing_ok=True)
                if disabled: (folder / 'disable').touch()
                result = shell('. ./tools/root-manager.sh; mount_provider_ready "$CHECK_META"', extra_env={'CHECK_META': folder.as_posix()})
                self.assertEqual(result.returncode, expected)

    def test_weight_mapping_both_variants(self):
        for regular in (400, 450):
            result = shell('. ./tools/prepare-fonts.sh; regular_weight="$CHECK_WEIGHT"; write_font_content', extra_env={'CHECK_WEIGHT': str(regular)})
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            fonts = ET.fromstring(b'<family>' + result.stdout + b'</family>').findall('font')
            actual = {(int(f.get('weight')), f.get('style')): (f.text.strip(), int(f.find('axis').get('stylevalue'))) for f in fonts}
            expected = {(w, s): ('Nunito-VF.ttf' if s == 'normal' else 'Nunito-Italic-VF.ttf', 200 if w == 100 else regular if w == 400 else w)
                        for s in ('normal', 'italic') for w in range(100, 901, 100)}
            self.assertEqual(actual, expected)
            self.assertEqual(len(actual), 18)

    def test_apatch_post_mount_preserves_installed_config_inodes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'work') as tmp:
            folder = Path(tmp)
            dest = folder / 'system/etc/fonts.xml'
            dest.parent.mkdir(parents=True)
            dest.write_text('install-prepared-config', encoding='utf-8')
            (folder / '.nunito-install-state').write_text('manager=APatch\nfingerprint=original\n', encoding='utf-8')
            before = dest.stat().st_ino
            for fingerprint in ('original', 'changed'):
                result = shell('. ./tools/prepare-fonts.sh; MODDIR="$CHECK_MODDIR"; getprop() { printf "%s" "$CHECK_FINGERPRINT"; }; prepare_fonts', extra_env={'CHECK_MODDIR': folder.as_posix(), 'CHECK_FINGERPRINT': fingerprint})
                self.assertEqual(result.returncode, 0)
                self.assertEqual(dest.read_text(), 'install-prepared-config')
                self.assertEqual(dest.stat().st_ino, before)
                log = (folder / 'font-status.log').read_text()
                self.assertIn('install-prepared' if fingerprint == 'original' else 'fingerprint changed', log)

    def test_late_load_and_missing_fonts_clear_stale_configs(self):
        for late in ('0', '1'):
            with tempfile.TemporaryDirectory(dir=ROOT / 'work') as tmp:
                folder = Path(tmp)
                dest = folder / 'system/etc/fonts.xml'
                dest.parent.mkdir(parents=True)
                dest.write_text('stale', encoding='utf-8')
                result = shell('. ./tools/prepare-fonts.sh; MODDIR="$CHECK_MODDIR"; prepare_fonts', extra_env={'CHECK_MODDIR': folder.as_posix(), 'KSU_LATE_LOAD': late})
                self.assertEqual(result.returncode, 0, result.stderr.decode())
                self.assertFalse(dest.exists())
                log = (folder / 'font-status.log').read_text()
                self.assertIn('Late-load' if late == '1' else 'Missing/unsafe', log)

    def test_product_staging_and_no_source_writes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'work') as tmp:
            folder = Path(tmp)
            (folder / 'system/fonts').mkdir(parents=True)
            for name in ('Nunito-VF.ttf', 'Nunito-Italic-VF.ttf'):
                shutil.copyfile(ROOT / 'system/fonts' / name, folder / 'system/fonts' / name)
            (folder / 'tools').mkdir()
            shutil.copyfile(ROOT / 'tools/patch-sans-family.awk', folder / 'tools/patch-sans-family.awk')
            source = folder / 'original.xml'
            xml = '<fonts-modification><family customizationType="new-named-family" name="sans-serif"><font>Original.ttf</font></family></fonts-modification>'
            source.write_text(xml, encoding='utf-8')
            (folder / '.nunito-content.xml').write_text(CONTENT, encoding='utf-8')
            result = shell('. ./tools/prepare-fonts.sh; MODDIR="$CHECK_MODDIR"; chown() { :; }; chcon() { :; }; patch_config "$MODDIR/original.xml" system/product/etc/fonts_customization.xml', extra_env={'CHECK_MODDIR': folder.as_posix()})
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertEqual(source.read_text(), xml)
            out = ET.parse(folder / 'system/product/etc/fonts_customization.xml')
            self.assertEqual(out.find('family').get('customizationType'), 'new-named-family')
            for name in ('Nunito-VF.ttf', 'Nunito-Italic-VF.ttf'):
                self.assertEqual((folder / 'system/product/fonts' / name).read_bytes(), (ROOT / 'system/fonts' / name).read_bytes())

    def test_unsafe_relative_paths(self):
        for path in ('../system/fonts', 'system/../../fonts', 'system//fonts', '/system/fonts', 'product/fonts'):
            result = shell('. ./tools/prepare-fonts.sh; MODDIR="$PWD"; safe_module_path "$CHECK_PATH"', extra_env={'CHECK_PATH': path})
            self.assertNotEqual(result.returncode, 0)

    def test_symlinked_destination_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'work') as tmp:
            folder = Path(tmp)
            (folder / 'system').mkdir()
            (folder / 'outside').mkdir()
            try:
                (folder / 'system/etc').symlink_to(folder / 'outside', target_is_directory=True)
            except OSError as error:
                self.skipTest(f'Desktop symlink creation unavailable: {error}')
            result = shell('. ./tools/prepare-fonts.sh; MODDIR="$CHECK_MODDIR"; safe_module_path system/etc/fonts.xml', extra_env={'CHECK_MODDIR': folder.as_posix()})
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list((folder / 'outside').iterdir()), [])


class FontPayloadChecks(unittest.TestCase):
    def test_variable_axis_and_cyrillic_glyphs(self):
        points = list(range(0x410, 0x450)) + [0x401, 0x451, 0x490, 0x491, 0x404, 0x454, 0x406, 0x456, 0x407, 0x457, 0x41]
        for filename in ('Nunito-VF.ttf', 'Nunito-Italic-VF.ttf'):
            data = (ROOT / 'system/fonts' / filename).read_bytes()
            u16 = lambda p: struct.unpack_from('>H', data, p)[0]
            u32 = lambda p: struct.unpack_from('>I', data, p)[0]
            tables = {data[p:p + 4]: u32(p + 8) for p in range(12, 12 + u16(4) * 16, 16)}
            fvar = tables[b'fvar']
            axis = fvar + u16(fvar + 4)
            self.assertEqual(u16(fvar + 8), 1)
            self.assertEqual(data[axis:axis + 4], b'wght')
            self.assertEqual((u32(axis + 4) / 65536, u32(axis + 12) / 65536), (200, 1000))
            cmap = tables[b'cmap']
            subtables = [cmap + u32(cmap + 4 + i * 8 + 4) for i in range(u16(cmap + 2))]
            supported = set()
            for sub in subtables:
                if u16(sub) != 4: continue
                count = u16(sub + 6) // 2
                ends = sub + 14
                starts = ends + count * 2 + 2
                deltas = starts + count * 2
                offsets = deltas + count * 2
                for cp in points:
                    for i in range(count):
                        if not u16(starts + i * 2) <= cp <= u16(ends + i * 2): continue
                        delta, offset = u16(deltas + i * 2), u16(offsets + i * 2)
                        glyph = u16(offsets + i * 2 + offset + (cp - u16(starts + i * 2)) * 2) if offset else cp
                        if glyph and (glyph + delta) & 0xffff: supported.add(cp)
                        break
            self.assertEqual(set(points) - supported, set(), filename)


class ArchiveChecks(unittest.TestCase):
    def test_zip_payload_and_permissions(self):
        if not OPTIONS.zip: self.skipTest('No ZIP paths supplied')
        for source in OPTIONS.zip:
            with self.subTest(zip=source), zipfile.ZipFile(source) as archive:
                self.assertEqual(set(archive.namelist()), PACKAGE_FILES)
                self.assertIsNone(archive.testzip())
                regular = int(archive.read('nunito.conf').decode().split('regular_weight=')[1].strip())
                self.assertIn(regular, (400, 450))
                self.assertIn(b'id=nunito_sans_ksu\n', archive.read('module.prop'))
                for item in archive.infolist():
                    self.assertEqual(item.create_system, 3)
                    self.assertEqual((item.external_attr >> 16) & 0o777, 0o755 if item.filename.endswith('.sh') else 0o644)
                    data = archive.read(item)
                    if item.filename.endswith(('.sh', '.awk', '.conf', '.prop')):
                        self.assertNotIn(b'\r', data)
                        self.assertFalse(data.startswith(b'\xef\xbb\xbf'))
                    if item.filename.endswith('.ttf'):
                        self.assertEqual(data, (ROOT / item.filename).read_bytes())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--awk", default=shutil.which("awk"))
    parser.add_argument("--shell", default=shutil.which("sh"))
    parser.add_argument("--device-configs")
    parser.add_argument("--zip", action='append', default=[])
    OPTIONS = parser.parse_args()
    if not OPTIONS.awk:
        parser.error("AWK is required (e.g. from Git Bash on Windows)")
    if not OPTIONS.shell:
        parser.error('POSIX sh is required')
    (ROOT / 'work').mkdir(exist_ok=True)
    unittest.main(argv=[__file__], verbosity=2)
