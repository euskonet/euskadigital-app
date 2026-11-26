#!/usr/bin/env python3
"""Publica en Google Play una versión que está en borrador en una pista.

Uso (en GitHub Actions, con PLAY_SERVICE_ACCOUNT_JSON en el entorno):
    python3 tool/play_publicar.py <pista> <versionCode> [pista_origen]

Cambia el estado de la versión de «draft» a «completed» y confirma la
edición; Google la envía a revisión y, una vez aprobada, la distribuye.
Con pista_origen, copia la versión desde esa pista (p. ej. de la prueba
abierta «beta» a «production») y la publica en la de destino.
"""
import json
import os
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

PACKAGE = 'eus.euskadigital.app'
API = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}'


def main() -> int:
    track, code = sys.argv[1], sys.argv[2]
    source = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None
    creds = service_account.Credentials.from_service_account_info(
        json.loads(os.environ['PLAY_SERVICE_ACCOUNT_JSON']),
        scopes=['https://www.googleapis.com/auth/androidpublisher'],
    )
    creds.refresh(Request())
    s = requests.Session()
    s.headers['Authorization'] = f'Bearer {creds.token}'

    def call(method, path, **kw):
        r = s.request(method, API + path, timeout=60, **kw)
        if r.status_code >= 400:
            print(f'::error::{method} {path}: HTTP {r.status_code} {r.text[:500]}')
            sys.exit(1)
        return r.json() if r.text else {}

    edit = call('POST', '/edits')['id']
    t = call('GET', f'/edits/{edit}/tracks/{track}')
    releases = t.get('releases', [])
    print('Versiones en la pista:', [(r.get('name'), r.get('versionCodes'), r.get('status')) for r in releases])
    target = next((r for r in releases if code in (r.get('versionCodes') or [])), None)
    if target is None and source:
        src = call('GET', f'/edits/{edit}/tracks/{source}')
        found = next((r for r in src.get('releases', []) if code in (r.get('versionCodes') or [])), None)
        if found is None:
            print(f'::error::No hay ninguna versión {code} en la pista {source}.')
            return 1
        target = {k: found[k] for k in ('name', 'versionCodes', 'releaseNotes') if k in found}
        target['status'] = 'draft'
        t = {'track': track, 'releases': [target]}
        print(f'Copiando la versión {code} de {source} a {track}.')
    if target is None:
        print(f'::error::No hay ninguna versión {code} en la pista {track}.')
        return 1
    if target.get('status') == 'completed':
        print(f'La versión {code} ya está publicada en {track}.')
        return 0
    target['status'] = 'completed'
    target.pop('userFraction', None)
    # Solo se conserva la versión que se publica (la anterior queda sustituida).
    t['releases'] = [target]
    call('PUT', f'/edits/{edit}/tracks/{track}', json=t)
    call('POST', f'/edits/{edit}:commit')
    print(f'Versión {code} publicada en la pista {track}. Google la revisará antes de distribuirla.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
