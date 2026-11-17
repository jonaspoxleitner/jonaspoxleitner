#!/usr/bin/env bash
# Rebuilds the optimised assets in web/assets from the full-size originals in
# sources/. Nothing here runs at deploy time: the outputs are committed.
#
#   fonts   variable TTFs -> Latin-subset WOFF2
#   images  banner.png    -> banner.webp
#   images  logo.png      -> social-card.jpg (1200x630 link preview)
#   icons   <app>.png     -> <app>.webp at 128px (drawn at 32px, so 4x headroom)
#
# Needs fonttools (pip install fonttools), cwebp (brew install webp), npx, and
# python3 with Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."

# Latin coverage, matching Google Fonts' "latin" subset.
LATIN="U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2074,U+20AC,U+2122,U+2190-2193,U+2212,U+2215,U+FEFF,U+FFFD"

# Keep the WOFF2 files reproducible: fontTools stamps head.modified from here.
export SOURCE_DATE_EPOCH=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

subset_woff2() { # <source ttf> <output woff2>, keeping the variable axes
    pyftsubset "$1" --unicodes="$LATIN" --layout-features='*' --name-IDs='*' \
        --output-file="${1%.ttf}-subset.ttf"
    npx -y -p wawoff2 woff2_compress.js "${1%.ttf}-subset.ttf" >/dev/null
    mv "${1%.ttf}-subset.woff2" "$2"
}

# Roboto: wdth is pinned at its default (the design never narrows text), wght
# stays free so the body face can carry every weight the stylesheet asks for.
fonttools varLib.instancer sources/fonts/Roboto-Variable.ttf \
    wdth=100 --output="$TMP/roboto.ttf" >/dev/null
subset_woff2 "$TMP/roboto.ttf" web/assets/fonts/Roboto-Variable.woff2

# JetBrains Mono: the page uses 400/600/700, so the axis is clipped to 400-800.
fonttools varLib.instancer sources/fonts/JetBrainsMono-Variable.ttf \
    wght=400:800 --output="$TMP/jetbrains.ttf" >/dev/null
subset_woff2 "$TMP/jetbrains.ttf" web/assets/fonts/JetBrainsMono-Variable.woff2

# Banner: a 1584x396 gradient behind a 64-72px bar, so q84 keeps the grain.
cwebp -quiet -q 84 -m 6 -mt sources/images/banner.png -o web/assets/images/banner.webp

# Share card: the banner cover-cropped to the 1200x630 that link previews expect (they only take JPG/PNG, so the WebP in the bar is out), with the monogram in white centred on top.
python3 - <<'PY'
import os

from PIL import Image

W, H = 1200, 630

banner = Image.open("sources/images/banner.png").convert("RGB")
scale = max(W / banner.width, H / banner.height)
banner = banner.resize((round(banner.width * scale), round(banner.height * scale)), Image.LANCZOS)
left, top = (banner.width - W) // 2, (banner.height - H) // 2
card = banner.crop((left, top, left + W, top + H))

logo = Image.open("web/assets/images/logo.png").convert("RGBA")
mark_height = 230
logo = logo.resize((round(logo.width * mark_height / logo.height), mark_height), Image.LANCZOS)
mark = Image.new("RGBA", logo.size, (255, 255, 255, 255))
mark.putalpha(logo.split()[3])
card.paste(mark, ((W - logo.width) // 2, (H - logo.height) // 2), mark)

# q82 is where the banner's grain stops costing bytes without turning into blockiness; the card lands just under 100 KB.
card.save("web/assets/images/social-card.jpg", "JPEG", quality=82, optimize=True, progressive=True)
print(f"web/assets/images/social-card.jpg ({os.path.getsize('web/assets/images/social-card.jpg'):,} B)")
PY

# Lighthouse <=13.5 only probes the predecessor path (and its schema wants the specVersion root that ARD ignores), so the manifest is mirrored instead of living twice.
cp web/.well-known/ard.json web/.well-known/ai-catalog.json

python3 - <<'PY'
from PIL import Image
import glob, os

for src in sorted(glob.glob("sources/icons/*.png")):
    name = os.path.splitext(os.path.basename(src))[0]
    dst = f"web/assets/icons/{name}.webp"
    im = Image.open(src).convert("RGBA")
    if im.size != (128, 128):
        im = im.resize((128, 128), Image.LANCZOS)
    im.save(dst, "WEBP", quality=92, method=6)
    print(f"{dst} ({os.path.getsize(dst):,} B)")
PY
