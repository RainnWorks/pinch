"""Rebuild with Python 3 + Pillow and rsvg-convert (librsvg/Pango)."""
from pathlib import Path
from PIL import Image, ImageFilter
from io import BytesIO
import base64
import subprocess

ROOT = Path(__file__).resolve().parent
original = Image.open(ROOT / 'earbud-generated.png').convert('L')
ink = original.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: 255 if v > 95 else 0)
box = ink.getbbox()
ink = ink.crop((box[0]-20, box[1]-20, box[2]+20, box[3]+20))

def embedded(image):
    stream = BytesIO()
    image.save(stream, format='PNG')
    return 'data:image/png;base64,' + base64.b64encode(stream.getvalue()).decode()

def earbud(x, y, w, h, icon=False):
    raster = ink.filter(ImageFilter.MaxFilter(11 if icon else 1)).filter(ImageFilter.GaussianBlur(0.65))
    return f'<image x="{x}" y="{y}" width="{w}" height="{h}" href="{embedded(raster)}"/>'

def text(x, y, value, size=32, anchor='start'):
    return f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}">{value}</text>'

def path(d):
    return f'<path d="{d}" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'

def arrow(x1, y, x2):
    return path(f'M{x1} {y} H{x2} M{x2-9} {y-7} L{x2} {y} L{x2-9} {y+7}')

def document(w, h, content, background=True):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<g fill="white" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="400">
{'<rect width="100%" height="100%" fill="black"/>' if background else ''}
{content}
</g></svg>'''

hero = earbud(155, 115, 495, 670)
for index, (y, label) in enumerate([(310, 'Play / Pause'), (450, '⌥ Space'), (590, 'Previous track')]):
    start = 535 + index * 22
    hero += path(f'M{550-index*6} {start} H{670+index*25} L{785+index*10} {y} H825')
    for dot in range(index + 1):
        hero += f'<circle cx="{858+dot*23}" cy="{y}" r="5"/>'
    hero += arrow(943, y, 992)
    hero += text(1022, y+12, label, 37)

flow = earbud(88, 151, 185, 258)
flow += text(180, 463, 'Stem press', 29, 'middle')
flow += arrow(302, 300, 390)
flow += '<rect x="425" y="208" width="280" height="184" rx="14" fill="none" stroke="white" stroke-width="2.5"/>'
flow += text(565, 263, 'macOS', 28, 'middle')
flow += text(565, 312, 'now playing', 33, 'middle')
flow += path('M544 342 L557 350 L544 358 Z M572 341 V359 M582 341 V359')
flow += arrow(734, 300, 805)
flow += '<rect x="835" y="240" width="190" height="120" rx="25" fill="none" stroke="white" stroke-width="2.5"/>'
flow += text(930, 312, 'Pinch', 37, 'middle')
flow += text(930, 405, 'Silent loop', 25, 'middle')
flow += path('M1025 300 H1090 M1090 200 V400')
flow += arrow(1090, 200, 1180) + arrow(1090, 400, 1180)
flow += '<rect x="1210" y="153" width="305" height="94" rx="12" fill="none" stroke="white" stroke-width="2.5"/>'
flow += text(1362, 212, 'Keyboard shortcut', 28, 'middle')
flow += '<rect x="1210" y="353" width="305" height="94" rx="12" fill="none" stroke="white" stroke-width="2.5"/>'
flow += text(1362, 412, 'Spotify / Music', 30, 'middle')

# The 824px black tile leaves the standard 100px optical margin at 1024px.
shape = 'M285 100 H739 C865 100 924 159 924 285 V739 C924 865 865 924 739 924 H285 C159 924 100 865 100 739 V285 C100 159 159 100 285 100 Z'
icon = f'<defs><clipPath id="tile"><path d="{shape}"/></clipPath></defs><path d="{shape}" fill="black"/>'
icon += '<g clip-path="url(#tile)">' + earbud(265, 185, 494, 654, True) + '</g>'

for name, svg in [('hero', document(1600, 900, hero)), ('how-it-works', document(1600, 600, flow)), ('icon-1024', document(1024, 1024, icon, False))]:
    source = ROOT / f'{name}.svg'
    source.write_text(svg)
    subprocess.run(['rsvg-convert', str(source), '-o', str(ROOT.parent / f'{name}.png')], check=True)

Image.open(ROOT.parent / 'icon-1024.png').resize((32, 32), Image.Resampling.LANCZOS).save(ROOT / 'icon-preview-32.png')
