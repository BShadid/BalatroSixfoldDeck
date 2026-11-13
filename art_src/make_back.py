"""Sixfold Deck card back. Two colours like the vanilla backs (deck colour + white).
Frame metrics are measured from the vanilla Red Deck back; the hexagon artwork is original.
Usage: python make_back.py <out_dir>
Output: back_1x.png (71x95), back_2x.png, back_preview_4x.png"""
import math, sys
import numpy as np
from PIL import Image

W, H = 71, 95
X0, Y0, X1, Y1 = 1, 1, 69, 93          # the back is 69x93 inside its 71x95 slot
CX, CY = 35, 47                         # centre; mirror axes x' = 70 - x, y' = 94 - y
COPPER, WHITE = (0xd9, 0x77, 0x3a, 255), (255, 255, 255, 255)
S3 = math.sqrt(3)

def hexnorm(dx, dy):
    """'Radius' of a point in a pointy-top hexagon metric (vertex distance)."""
    ax, ay = abs(dx), abs(dy)
    return max(ax * 2 / S3, ay + ax / S3)

def lattice_edge(dx, dy, R):
    """True on the edges of a pointy-top honeycomb of cell radius R centred on the emblem."""
    q = (S3 / 3 * dx - dy / 3) / R; r = (2 / 3 * dy) / R
    x, z = q, r; y = -x - z
    rx, ry, rz = round(x), round(y), round(z)
    if abs(rx - x) > abs(ry - y) and abs(rx - x) > abs(rz - z): rx = -ry - rz
    elif abs(ry - y) > abs(rz - z): ry = -rx - rz
    else: rz = -rx - ry
    cx = R * (S3 * rx + S3 / 2 * rz); cy = R * 1.5 * rz
    return hexnorm(dx - cx, dy - cy) > R - 0.62

def make(C=COPPER):
    img = np.zeros((H, W, 4), np.uint8)
    # rounded outer shape in the deck colour
    for y in range(Y0, Y1 + 1):
        for x in range(X0, X1 + 1):
            dx, dy = min(x - X0, X1 - x), min(y - Y0, Y1 - y)
            if dx + dy >= 3 or (dx >= 2 and dy >= 1) or (dy >= 2 and dx >= 1): img[y, x] = C
    # white band with a dotted line along its middle
    for y in range(4, 91):
        for x in range(4, 67):
            if x <= 8 or x >= 62 or y <= 8 or y >= 86: img[y, x] = WHITE
    for i in range(7, 64, 3): img[6, i] = C; img[88, i] = C
    for i in range(8, 87, 3): img[i, 6] = C; img[i, 64] = C
    for (x, y) in ((4, 4), (66, 4), (4, 90), (66, 90)): img[y, x] = C

    # inner panel (x 9-61, y 9-85): built per pixel from the centre outwards
    for y in range(9, 86):
        for x in range(9, 62):
            dx, dy = x - CX, y - CY
            h = hexnorm(dx, dy)
            ang = math.degrees(math.atan2(dy, dx)) % 360
            on = False
            if x in (10, 60) or y in (10, 84):                     # panel outline
                on = True
            elif x in (9, 61) or y in (9, 85) or x in (11, 59) or y in (11, 83):
                on = False                                         # colour gaps either side of it
            elif h <= 3.2:                                         # solid core...
                on = not (dx == 0 and dy == 0)                     # ...with a colour centre point
            elif h < 7.6 or 17.6 < h < 19.2:
                on = False                                         # clear zones inside the emblem
            elif 7.6 <= h <= 8.6 or 16.6 <= h <= 17.6 or 19.2 <= h <= 20.6:
                on = True                                          # emblem rings (outer one doubled)
            elif 8.6 < h < 16.6:
                # six diamonds pointing at the corners: one per card played
                for k in range(6):
                    a = math.radians(90 + 60 * k)
                    px, py = CX + 12.4 * math.cos(a), CY + 12.4 * math.sin(a)
                    if abs(x - px) + abs(y - py) * 0.8 <= 2.6: on = True
                # small dots midway along each edge
                for k in range(6):
                    a = math.radians(60 * k)
                    px, py = CX + 11.5 * math.cos(a), CY + 11.5 * math.sin(a)
                    if round(px) == x and round(py) == y: on = True
            elif 20.6 < h <= 24.6:
                # clear ring around the emblem, with a pip off each corner
                for k in range(6):
                    a = math.radians(90 + 60 * k)
                    px, py = round(CX + 22.8 * math.cos(a)), round(CY + 22.8 * math.sin(a))
                    if (abs(x - px) + abs(y - py)) <= 1: on = True
            else:
                on = False                                         # filled by tiled hexagons below
            if on: img[y, x] = WHITE
    # interlocking honeycomb: 5x7 pointy hexagons on a 4px grid, odd rows shifted 2px, so
    # neighbours share edges exactly. Centred on the emblem, so it is pixel-symmetric.
    CELL = ['..#..', '.#.#.', '#...#', '#...#', '#...#', '.#.#.', '..#..']
    comb = np.zeros((H, W), bool)
    for j in range(-13, 14):
        for i in range(-10, 11):
            cx = CX + 4 * i + (2 if j % 2 else 0); cy = CY + 4 * j
            for sy, row in enumerate(CELL):
                for sx, p in enumerate(row):
                    x, y = cx - 2 + sx, cy - 3 + sy
                    if p == '#' and 0 <= x < W and 0 <= y < H: comb[y, x] = True
    for y in range(13, 82):
        for x in range(13, 58):
            if comb[y, x] and hexnorm(x - CX, y - CY) > 25.2: img[y, x] = WHITE
    # enforce exact four-way symmetry (rounding can break it by a pixel)
    left = img[:, :36].copy(); img[:, 35:] = left[:, ::-1][:, :36]
    top = img[:48].copy(); img[47:] = top[::-1][:48]

    # small hexagon breaking the white band at top and bottom centre
    for y in range(3, 10):
        for x in range(31, 40):
            if hexnorm(x - CX, (y - 6) * 1.1) <= 3.9: img[y, x] = C; img[94 - y, x] = C
    for y in range(4, 9):
        for x in range(33, 38):
            if 1.0 <= hexnorm(x - CX, y - 6) <= 2.2: img[y, x] = WHITE; img[94 - y, x] = WHITE
    return img

if __name__ == '__main__':
    out = sys.argv[1]
    im = Image.fromarray(make(), 'RGBA')
    im.save(f'{out}/back_1x.png')
    im.resize((W * 2, H * 2), Image.NEAREST).save(f'{out}/back_2x.png')
    im.resize((W * 4, H * 4), Image.NEAREST).save(f'{out}/back_preview_4x.png')
    print('ok')
