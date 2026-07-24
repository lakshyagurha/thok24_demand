#!/usr/bin/env python3
"""
Copies the legacy PHP `/uploads` imagery into the Supabase `product-images` bucket.

WHY THIS EXISTS, AND WHY IT IS URGENT
-------------------------------------
The Phase 5 catalog migration brought across 101 image *paths* (83 product_images,
6 banner, 12 main_category) but no image *bytes* -- the bucket is still empty. The
binaries live only under Backend/api_folder/:

    uploads/<file>   ->  Backend/api_folder/product_api_project/uploads/<file>
    banner/<file>    ->  Backend/api_folder/banner_api/banner/<file>
    category/<file>  ->  Backend/api_folder/main_category/category/<file>

Of those, the 154 files in `uploads/` are **gitignored and untracked** (.gitignore:62),
so they exist only on this machine and on the live digixcode.com server. `banner/` and
`category/` are tracked and therefore recoverable from git; the product photos are not.

=> Deleting or moving Backend/ before this script has run successfully would
   irreversibly destroy every product photo in the catalog. Run this FIRST, verify,
   and only then decommission the PHP backend.

The database already stores clean relative paths (verified: zero rows contain a full
http URL), and both Flutter apps resolve them with
`client.storage.from(bucket).getPublicUrl(path)`. So bucket keys must match the stored
paths exactly -- this script preserves them verbatim rather than re-naming anything.

USAGE
-----
Dry run (default -- reads only, needs no secret, safe to run anytime):

    python3 supabase/tools/migrate_storage.py

Real upload (needs the service-role key, because the bucket has no client INSERT policy
by design -- writes go through the service role only, never from an app):

    SUPABASE_SERVICE_ROLE_KEY='<key>' python3 supabase/tools/migrate_storage.py --apply

Get the key from: Supabase dashboard -> Project Settings -> API -> service_role.
It is a full-access credential: never commit it, never put it in a Flutter build.

Existing objects are skipped unless --upsert is passed, so re-running is safe.
"""
import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

PROJECT_URL = os.environ.get("SUPABASE_URL", "https://asnjjkpjuqsmjqrjojzl.supabase.co")
PUBLISHABLE_KEY = os.environ.get(
    "SUPABASE_PUBLISHABLE_KEY", "sb_publishable_4x3520_7eL-CvEz5Y9_LmQ_OfTCs0xf"
)
BUCKET = "product-images"

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND = REPO_ROOT / "Backend" / "api_folder"

# Stored-path prefix -> directory holding the actual bytes.
PREFIX_TO_DIR = {
    "uploads/": BACKEND / "product_api_project" / "uploads",
    "banner/": BACKEND / "banner_api" / "banner",
    "category/": BACKEND / "main_category" / "category",
}

# (table, column) pairs that reference an image path.
SOURCES = [
    ("product_images", "image_url"),
    ("banner", "banner_image"),
    ("main_category", "image"),
]


def get(path):
    req = urllib.request.Request(
        PROJECT_URL + path,
        headers={"apikey": PUBLISHABLE_KEY, "Authorization": f"Bearer {PUBLISHABLE_KEY}"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def referenced_paths():
    """Every image path the catalog actually points at, deduplicated."""
    found = {}
    for table, column in SOURCES:
        rows = get(f"/rest/v1/{table}?select={column}")
        for r in rows:
            p = (r.get(column) or "").strip()
            if p:
                found.setdefault(p, []).append(table)
    return found


def local_file_for(stored_path):
    for prefix, directory in PREFIX_TO_DIR.items():
        if stored_path.startswith(prefix):
            return directory / stored_path[len(prefix):]
    return None


def upload(stored_path, local_path, service_key, upsert):
    data = local_path.read_bytes()
    ctype = mimetypes.guess_type(str(local_path))[0] or "application/octet-stream"
    url = f"{PROJECT_URL}/storage/v1/object/{BUCKET}/{urllib.parse.quote(stored_path)}"
    headers = {
        "Authorization": f"Bearer {service_key}",
        "Content-Type": ctype,
        "x-upsert": "true" if upsert else "false",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:200]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually upload (default: dry run)")
    ap.add_argument("--upsert", action="store_true", help="overwrite objects that already exist")
    args = ap.parse_args()

    refs = referenced_paths()
    print(f"Catalog references {len(refs)} distinct image paths.\n")

    ready, missing, unknown_prefix = [], [], []
    for stored in sorted(refs):
        local = local_file_for(stored)
        if local is None:
            unknown_prefix.append(stored)
        elif local.is_file():
            ready.append((stored, local))
        else:
            missing.append((stored, local))

    print(f"  resolvable and present on disk : {len(ready)}")
    print(f"  referenced but MISSING on disk : {len(missing)}")
    print(f"  unrecognised path prefix       : {len(unknown_prefix)}")

    if missing:
        print("\n  -- broken references (catalog points at a file that is not here) --")
        for stored, local in missing:
            print(f"     {stored}   (looked in {local.parent})")
    if unknown_prefix:
        print("\n  -- unrecognised prefixes (teach PREFIX_TO_DIR about these) --")
        for stored in unknown_prefix:
            print(f"     {stored}")

    # Orphans: files on disk nothing points at. Not migrated, just reported, so the
    # decision to discard them is deliberate rather than accidental.
    orphans = 0
    for prefix, directory in PREFIX_TO_DIR.items():
        if not directory.is_dir():
            continue
        for f in directory.iterdir():
            if f.is_file() and not f.name.startswith(".") and (prefix + f.name) not in refs:
                orphans += 1
    print(f"\n  files on disk nothing references: {orphans} (not uploaded)")

    if not args.apply:
        print("\nDRY RUN -- nothing uploaded.")
        print("Re-run with --apply and SUPABASE_SERVICE_ROLE_KEY set to perform the copy.")
        return 0

    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not service_key:
        print("\nERROR: --apply needs SUPABASE_SERVICE_ROLE_KEY in the environment.",
              file=sys.stderr)
        return 2

    print(f"\nUploading {len(ready)} objects to '{BUCKET}' ...")
    uploaded = skipped = failed = 0
    for stored, local in ready:
        status, err = upload(stored, local, service_key, args.upsert)
        if status in (200, 201):
            uploaded += 1
        elif status == 409 and not args.upsert:
            skipped += 1
        else:
            failed += 1
            print(f"  FAIL {stored}: HTTP {status} {err}")
    print(f"\n  uploaded: {uploaded}   already present: {skipped}   failed: {failed}")

    if failed:
        print("\nSome uploads failed -- do NOT decommission Backend/ yet.")
        return 1
    print("\nAll referenced imagery is now in the bucket.")
    print("Verify a public URL renders in the app, then Backend/ is safe to retire.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
