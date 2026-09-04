"""Export a static Godot game for GitHub Pages using a matching Web template."""
from pathlib import Path
import argparse
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default='godot', help='Godot 4.6.3 executable')
parser.add_argument('--templates', type=Path, help='Official export_templates.tpz, or web_nothreads_release.zip')
args = parser.parse_args()
template = ROOT / 'work/templates/web_nothreads_release.zip'
if args.templates:
    template.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.templates) as archive:
        member = 'templates/web_nothreads_release.zip'
        if member in archive.namelist():
            template.write_bytes(archive.read(member))
        elif args.templates.resolve() != template.resolve():
            shutil.copyfile(args.templates, template)
if not template.exists():
    parser.error('Pass --templates with the official Godot 4.6.3 export templates archive.')
version = subprocess.check_output([args.godot, '--version'], text=True).strip()
if not version.startswith('4.6.3.'):
    parser.error(f'Expected Godot 4.6.3, got {version}')
output = ROOT / 'build/web'
output.mkdir(parents=True, exist_ok=True)
logs = ROOT / 'work'
subprocess.run([args.godot, '--headless', '--editor', '--path', str(ROOT/'source'), '--import', '--log-file', str(logs/'web-import.log')], check=True)
subprocess.run([args.godot, '--headless', '--path', str(ROOT/'source'), '--export-release', 'Web', str(output/'index.html'), '--log-file', str(logs/'web-export.log')], check=True)
(output/'.nojekyll').touch()
required = ['index.html', 'index.js', 'index.wasm', 'index.pck']
for filename in required:
    path = output/filename
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f'Export is missing {filename}')
html = (output/'index.html').read_text()
if '$GODOT_' in html:
    raise RuntimeError('Unexpanded template variables in exported HTML')
print(f'Web build ready: {output}')
