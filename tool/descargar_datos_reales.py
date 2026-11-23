#!/usr/bin/env python3
"""Descarga los feeds y las imágenes reales para generar capturas con datos reales.

    python3 tool/descargar_datos_reales.py
    flutter test test/screenshots --update-goldens --tags screenshots --dart-define=REAL=true

Guarda todo en test/screenshots/real_data/ (no se sube al repositorio):
los feeds (XML) y las imágenes (reducidas a 800 px), con un manifest.json
que relaciona cada URL con su fichero local.
"""
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from io import BytesIO

try:
    from PIL import Image
except ImportError:  # sin Pillow se guardan las imágenes tal cual
    Image = None

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'test' / 'screenshots' / 'real_data'
UA = 'EuskaDigitalApp/1.0 (+https://www.euskadigital.eus)'
NS = {
    'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd',
    'content': 'http://purl.org/rss/1.0/modules/content/',
    'media': 'http://search.yahoo.com/mrss/',
    'atom': 'http://www.w3.org/2005/Atom',
    'yt': 'http://www.youtube.com/xml/schemas/2015',
}


def fetch(url: str) -> bytes | None:
    r = subprocess.run(['curl', '-sSL', '-m', '40', '-A', UA, '--fail', url], capture_output=True)
    return r.stdout if r.returncode == 0 and r.stdout else None


def first_img(html: str | None) -> str | None:
    m = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', html or '', re.I)
    return m.group(1) if m and not m.group(1).startswith('data:') else None


def image_urls(feed_id: str, xml: bytes) -> list[str]:
    """Portada del canal e imágenes de los primeros elementos."""
    urls: list[str] = []
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return urls
    if root.tag.endswith('feed'):  # Atom (YouTube)
        for e in root.findall('atom:entry', NS)[:10]:
            vid = e.findtext('yt:videoId', namespaces=NS)
            if vid:
                urls.append(f'https://i.ytimg.com/vi/{vid}/hqdefault.jpg')
        return urls
    ch = root.find('channel')
    if ch is None:
        return urls
    img = ch.find('itunes:image', NS)
    if img is not None and img.get('href'):
        urls.append(img.get('href'))
    elif ch.findtext('image/url'):
        urls.append(ch.findtext('image/url'))
    for it in ch.findall('item')[:8]:
        i = it.find('itunes:image', NS)
        if i is not None and i.get('href'):
            urls.append(i.get('href'))
        else:
            u = first_img(it.findtext('content:encoded', namespaces=NS)) or first_img(it.findtext('description'))
            if u:
                urls.append(u)
    return urls


def save_image(url: str, data: bytes) -> str:
    name = hashlib.sha1(url.encode()).hexdigest()[:16]
    if Image is not None:
        try:
            im = Image.open(BytesIO(data))
            im.thumbnail((800, 800))
            path = OUT / 'img' / f'{name}.png'
            im.convert('RGBA' if im.mode in ('RGBA', 'LA', 'P') else 'RGB').save(path)
            return str(path.relative_to(OUT))
        except Exception:
            pass
    path = OUT / 'img' / name
    path.write_bytes(data)
    return str(path.relative_to(OUT))


def main() -> int:
    cfg = json.loads((ROOT / 'assets' / 'config' / 'app_config.json').read_text(encoding='utf-8'))
    feeds = {'news': cfg['news']['feedUrl']}
    for g in cfg['programGroups']:
        for p in g['programs']:
            feeds[p['id']] = p['feedUrl']
    if cfg.get('youtube'):
        feeds['youtube'] = f"https://www.youtube.com/feeds/videos.xml?channel_id={cfg['youtube']['channelId']}"

    (OUT / 'feeds').mkdir(parents=True, exist_ok=True)
    (OUT / 'img').mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict[str, str]] = {'feeds': {}, 'images': {}}
    for fid, url in feeds.items():
        xml = fetch(url)
        if not xml:
            print(f'  feed  {fid:20} NO DISPONIBLE  {url}')
            continue
        (OUT / 'feeds' / f'{fid}.xml').write_bytes(xml)
        manifest['feeds'][fid] = f'feeds/{fid}.xml'
        imgs = image_urls(fid, xml)
        ok = 0
        for u in dict.fromkeys(imgs):
            if u in manifest['images']:
                continue
            data = fetch(u)
            if data:
                manifest['images'][u] = save_image(u, data)
                ok += 1
        print(f'  feed  {fid:20} ok   imágenes {ok}/{len(set(imgs))}')
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding='utf-8')
    print(f"Listo: {len(manifest['feeds'])} feeds, {len(manifest['images'])} imágenes en {OUT}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
