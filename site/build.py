#!/usr/bin/env python3
"""Build the dependency-free Pages site with inline, clickable D2 SVGs."""
from pathlib import Path
import re
import shutil

site = Path(__file__).resolve().parent
root = site.parent
output = root / '.build' / 'site'
output.mkdir(parents=True, exist_ok=True)
(output / 'diagrams').mkdir(exist_ok=True)
html = (site / 'index.html').read_text()
for name in ('stack-trace', 'open-source'):
    svg = (root / 'examples' / 'diagrams' / f'{name}.svg').read_text()
    svg = re.sub(r'<\?xml[^>]*\?>\s*', '', svg)
    html = html.replace(f'<!-- diagram:{name} -->', svg)
    for ext in ('d2', 'svg'):
        shutil.copyfile(root / 'examples' / 'diagrams' / f'{name}.{ext}', output / 'diagrams' / f'{name}.{ext}')
assert '<!-- diagram:' not in html, 'Unexpanded diagram marker'
(output / 'index.html').write_text(html)
shutil.copyfile(site / 'style.css', output / 'style.css')
(output / '.nojekyll').touch()
print(f'Built {output}')
