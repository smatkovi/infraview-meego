#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds the launcher icon: InfraView's eye in MeeGo's own icon shape.

Upstream's icon is a circle -- right for Sailfish, foreign on a Harmattan
home screen, where every stock icon is cut to the same rounded-square
"squircle". So the silhouette is taken literally from a stock icon's alpha
channel rather than approximated:
/usr/share/themes/blanco/meegotouch/icons/icon-l-*.png all carry it, pixel
for pixel (kept beside this script as mask-icon-l.png).

Filling the corners is done in the SVG, not on top of the rendered circle:
the circle element is swapped for a full-bleed rect carrying the same
gradient, so the teal reaches the mask's edge with no seam where it would
otherwise meet the circle's antialiased rim. The eye artwork is untouched.

Everything is drawn at 4x and scaled down at the end; the squircle's curve
aliases badly at 80 px otherwise.
"""
import io
import re

import cairosvg
from PIL import Image

HERE = __file__.rsplit("/", 1)[0]
SVG_SOURCE = HERE + "/icons/upstream-infraview.svg"
MASK_SOURCE = HERE + "/icons/mask-icon-l.png"

S = 320                      # working size, 4x the largest output
OUTPUTS = (80, 64)           # 80x80 goes in the package, 64x64 into the control

# The circle that carries the background gradient. Upstream draws it at
# r=42.7 in an 86x86 box, so it already runs to the edge -- only the corners
# are missing, which is exactly what the squircle wants filled.
CIRCLE = re.compile(r'<circle[^>]*r="42\.7"[^>]*/>')
FULL_BLEED = '<rect x="0" y="0" width="86" height="86" style="fill:url(#_Linear1);"/>'


def artwork():
    """Upstream's icon with the background circle grown to the full box."""
    with open(SVG_SOURCE, "r") as handle:
        svg = handle.read()
    svg, count = CIRCLE.subn(FULL_BLEED, svg, count=1)
    if count != 1:
        raise SystemExit("background circle not found in %s" % SVG_SOURCE)
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"),
                           output_width=S, output_height=S)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def squircle():
    """MeeGo's icon silhouette, straight out of a stock icon's alpha."""
    stock = Image.open(MASK_SOURCE).convert("RGBA")
    return stock.split()[3].resize((S, S), Image.LANCZOS)


def build():
    icon = artwork()
    mask = squircle()

    # Gloss across the top, the way the blanco icons carry it. Kept light --
    # upstream's gradient already runs top-left to bottom-right, so this only
    # has to seat the icon among the stock ones, not light it from scratch.
    gloss = Image.new("L", (S, S), 0)
    gp = gloss.load()
    for y in range(int(S * 0.44)):
        value = int(42 * (1.0 - y / (S * 0.44)) ** 1.7)
        for x in range(S):
            gp[x, y] = value
    lit = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), icon, gloss)
    lit.putalpha(icon.split()[3])

    # The squircle cuts the corners; where the artwork is already transparent
    # it must stay transparent, so the two alphas are multiplied.
    alpha = Image.new("L", (S, S))
    alpha.putdata([a * m // 255 for a, m in zip(lit.split()[3].get_flattened_data(),
                                                mask.get_flattened_data())])
    lit.putalpha(alpha)

    for size in OUTPUTS:
        out = lit.resize((size, size), Image.LANCZOS)
        path = "%s/icons/infraview-%d.png" % (HERE, size)
        out.save(path)
        print("wrote %s" % path)
    lit.save(HERE + "/icons/infraview-320.png")
    print("wrote %s/icons/infraview-320.png (master)" % HERE)


if __name__ == "__main__":
    build()
