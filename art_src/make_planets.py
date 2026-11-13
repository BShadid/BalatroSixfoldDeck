"""Sixfold Deck planet cards, v4.
Layout, sizes and the four card colours are measured pixel-for-pixel from the game's own
planet cards (Tarots.png); all artwork, lettering and icons are drawn here from scratch.
Usage: python make_planets.py <output_dir>
Output: planets_1x.png (639x95: nine 71x95 slots), planets_2x.png, preview_4x.png"""
import math, random, sys
import numpy as np
from PIL import Image

W, H = 71, 95                # sprite slot
CX0, CY0, CX1, CY1 = 4, 1, 66, 93   # the card itself sits inside the slot (63x93)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

def hexc(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# The in-game planet cards use exactly these four colours (plus white for highlights).
TEAL, LIGHT, DARK, MID, WHITE = hexc('#5b9baa'), hexc('#dff5fc'), hexc('#4f6367'), hexc('#84c5d2'), hexc('#ffffff')

# ---------------- card frame ----------------
def depth(x, y):
    """Distance in from the card's chamfered edge (0 = outermost ring)."""
    dx, dxr, dy, dyb = x - CX0, CX1 - x, y - CY0, CY1 - y
    if min(dx, dxr, dy, dyb) < 0: return -1
    corner = min(dx, dxr) + min(dy, dyb) - 3
    return min(dx, dxr, dy, dyb, corner)

HEADER = {4: (10, 60), 5: (9, 61), **{y: (9, 61) for y in range(6, 12)}, 12: (10, 60)}
TRAY = {78: (10, 60), **{y: (9, 61) for y in range(79, 89)}, 89: (9, 61), 90: (10, 60)}
FRAME_FILL = {4: [(8, 9), (61, 62)], 5: [(8, 8), (62, 62)], 89: [(8, 8), (62, 62)], 90: [(8, 9), (61, 62)]}

def base_card():
    img = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        for x in range(W):
            d = depth(x, y)
            if d < 0: continue
            img[y, x] = TEAL if d == 0 else DARK if d == 1 else LIGHT if d <= 3 else TEAL
    for rows in (HEADER, TRAY):
        for y, (a, b) in rows.items():
            img[y, a:b + 1] = MID
    for y, spans in FRAME_FILL.items():
        for a, b in spans: img[y, a:b + 1] = LIGHT
    return img

# ---------------- stars ----------------
def stars(img, rng):
    def ok(x, y):  # panel only, away from the pill and the planet's rim
        return (14 <= y <= 15 or 29 <= y <= 76) and 9 <= x <= 61 and tuple(img[y, x]) == TEAL
    for _ in range(40):
        x, y = rng.randint(9, 61), rng.randint(14, 76)
        if ok(x, y): img[y, x] = LIGHT
    for _ in range(2):  # long-armed sparkles
        for _try in range(50):
            x, y = rng.randint(10, 60), rng.randint(31, 73)
            pts = [(x, y), (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1), (x, y - 2), (x, y + 2)]
            if all(ok(px, py) for px, py in pts):
                for px, py in pts: img[py, px] = LIGHT
                break

# ---------------- header icons: one per Sixfold planet, this card's lit ----------------
CIRCLE = ['.###.', '#...#', '#...#', '#...#', '.###.']
DIAMOND = ['..#..', '.#.#.', '#...#', '.#.#.', '..#..']
def header_icons(img, index, secret_flags):
    n = len(secret_flags); x = 9 + (53 - (n * 5 + (n - 1))) // 2
    for i, secret in enumerate(secret_flags):
        shape = DIAMOND if secret else CIRCLE
        edge = WHITE if i == index else DARK
        for dy, row in enumerate(shape):
            inside = False
            for dx, p in enumerate(row):
                if p == '#': img[6 + dy, x + dx] = edge
            # fill the inside with the light colour
            for dx in range(5):
                left = row[:dx].count('#'); right = row[dx + 1:].count('#')
                if row[dx] == '.' and left and right: img[6 + dy, x + dx] = LIGHT
        x += 6

# ---------------- name pill and lettering ----------------
PILL_K = {17: [(15, 55)], 18: [(14, 15), (55, 56)], 19: [(13, 14), (56, 57)], 20: [(13, 14), (56, 57)],
          **{y: [(12, 13), (57, 58)] for y in range(21, 25)}, 25: [(13, 14), (56, 57)],
          26: [(13, 14), (56, 57)], 27: [(14, 15), (55, 56)], 28: [(15, 55)]}
PILL_W = {18: (16, 54), 19: (15, 55), 20: (15, 55), **{y: (14, 56) for y in range(21, 25)},
          25: (15, 55), 26: (15, 55), 27: (16, 54)}
# Original 6px capitals: heavy left stroke, light right stroke, 1px spacing.
FONT = {
 'A': ['.##.', '##.#', '##.#', '####', '##.#', '##.#'], 'C': ['.###', '##..', '##..', '##..', '##..', '.###'],
 'D': ['###.', '##.#', '##.#', '##.#', '##.#', '###.'], 'E': ['###', '##.', '###', '##.', '##.', '###'],
 'G': ['.###', '##..', '##..', '##.#', '##.#', '.###'], 'H': ['##.#', '##.#', '####', '##.#', '##.#', '##.#'],
 'I': ['####', '.##.', '.##.', '.##.', '.##.', '####'], 'K': ['##.#', '##.#', '###.', '##.#', '##.#', '##.#'],
 'L': ['##..', '##..', '##..', '##..', '##..', '####'], 'M': ['#...#', '##.##', '##.##', '#.#.#', '##..#', '##..#'],
 'N': ['##..#', '###.#', '##.##', '##..#', '##..#', '##..#'], 'O': ['.##.', '##.#', '##.#', '##.#', '##.#', '.##.'],
 'P': ['###.', '##.#', '##.#', '###.', '##..', '##..'], 'R': ['###.', '##.#', '##.#', '###.', '##.#', '##.#'],
 'S': ['.###', '##..', '.##.', '..##', '..##', '###.'], 'T': ['####', '.##.', '.##.', '.##.', '.##.', '.##.'],
 'U': ['##.#', '##.#', '##.#', '##.#', '##.#', '.##.'], 'Y': ['##.#', '##.#', '.##.', '.##.', '.##.', '.##.'],
}
def text_width(t): return sum(len(FONT[c][0]) for c in t) + len(t) - 1
def name_pill(img, name):
    for y, spans in PILL_K.items():
        for a, b in spans: img[y, a:b + 1] = DARK
    for y, (a, b) in PILL_W.items(): img[y, a:b + 1] = LIGHT
    w = text_width(name); assert w <= 41, (name, w)
    x = 35 - w // 2
    for ch in name:
        for gy, row in enumerate(FONT[ch]):
            for gx, p in enumerate(row):
                if p == '#': img[20 + gy, x + gx] = DARK
        x += len(FONT[ch][0]) + 1

# ---------------- tray of mini cards showing the 6-card hand ----------------
# The game's mini cards are 9px wide; six of them only fit the tray at 7px wide (gap 1).
MW, MH, MY, MGAP = 7, 11, 79, 1
# Marks on the 5x9 interior: 'A' first rank (dot), 'B' second rank (pip-cornered blob),
# 'C' third rank (hollow square, needed for Three Pair), ints = straight pips.
MARKS = {
    'A': [(2, 4)],
    'B': [(0, 1), (2, 2), (1, 3), (2, 3), (3, 3), (1, 4), (2, 4), (3, 4), (1, 5), (2, 5), (3, 5), (2, 6), (4, 7)],
    'C': [(0, 1), (1, 3), (2, 3), (3, 3), (1, 4), (3, 4), (1, 5), (2, 5), (3, 5), (4, 7)],
    1: [(2, 4)], 2: [(2, 2), (2, 6)], 3: [(2, 2), (2, 4), (2, 6)],
    4: [(1, 2), (3, 2), (1, 6), (3, 6)], 5: [(1, 2), (3, 2), (2, 4), (1, 6), (3, 6)],
    6: [(1, 2), (3, 2), (1, 4), (3, 4), (1, 6), (3, 6)],
}
def mini_card(img, x, i, suited, mark):
    for dy in range(MH):
        for dx in range(MW):
            if dx in (0, MW - 1) and dy in (0, MH - 1): continue        # cut corners
            border = dx in (0, MW - 1) or dy in (0, MH - 1)
            img[MY + dy, x + dx] = TEAL if (border or suited) else LIGHT
    ix, iy = x + 1, MY + 1
    if suited:   # one-suit cards: teal with two dark blocks
        for dy in range(0, 5):
            for dx in (0, 1): img[iy + dy, ix + dx] = DARK
        for dy in range(5, 9):
            for dx in (3, 4): img[iy + dy, ix + dx] = DARK
        ink = LIGHT
    else:        # mixed suits: mark colour alternates card to card
        ink = DARK if i % 2 == 0 else TEAL
    for (px, py) in MARKS.get(mark, []): img[iy + py, ix + px] = ink

def tray(img, suited, marks):
    total = len(marks) * MW + (len(marks) - 1) * MGAP
    x = 9 + (53 - total) // 2
    for i, m in enumerate(marks):
        mini_card(img, x, i, suited, m); x += MW + MGAP

# ---------------- planet bodies ----------------
class Noise:
    def __init__(self, seed):
        rng = random.Random(seed)
        self.perm = list(range(256)); rng.shuffle(self.perm); self.perm += self.perm
        self.vals = [rng.random() for _ in range(256)]
    def _h(self, x, y, z): return self.vals[self.perm[(self.perm[(self.perm[x & 255] + y) & 255] + z) & 255]]
    def __call__(self, x, y, z):
        xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
        s = lambda t: t * t * (3 - 2 * t); u, v, w = s(x - xi), s(y - yi), s(z - zi)
        L = lambda a, b, t: a + (b - a) * t
        c = [[[self._h(xi + i, yi + j, zi + k) for k in (0, 1)] for j in (0, 1)] for i in (0, 1)]
        return L(L(L(c[0][0][0], c[0][0][1], w), L(c[0][1][0], c[0][1][1], w), v),
                 L(L(c[1][0][0], c[1][0][1], w), L(c[1][1][0], c[1][1][1], w), v), u)
    def fbm(self, x, y, z, o=3):
        t, a, f, n = 0, 1, 1, 0
        for _ in range(o): t += a * self(x * f, y * f, z * f); n += a; a *= .5; f *= 2
        return t / n

LIGHT_DIR = np.array([-.55, -.6, .58]); LIGHT_DIR /= np.linalg.norm(LIGHT_DIR)
PX, PY = 35, 52

def ell(x, y, cx, cy, rx, ry): return ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2

def body(img, cx, cy, rx, ry, surface, halo=None):
    """Planet with the in-game treatment: light rim, dark outline, softly shaded surface."""
    extra = 1.4 if halo else 0
    for y in range(H):
        for x in range(W):
            if ell(x, y, cx, cy, rx + extra + 1.1, ry + extra + 1.1) <= 1: img[y, x] = LIGHT       # rim
    for y in range(H):
        for x in range(W):
            if ell(x, y, cx, cy, rx + extra + .1, ry + extra + .1) <= 1: img[y, x] = DARK        # outline
            if halo and ell(x, y, cx, cy, rx + extra - .8, ry + extra - .8) <= 1: img[y, x] = hexc(halo)
    for y in range(H):
        for x in range(W):
            nx = (x + .5 - cx) / (rx - .9); ny = (y + .5 - cy) / (ry - .9)
            d = nx * nx + ny * ny
            if d > 1: continue
            nz = math.sqrt(1 - d)
            lam = .25 + .75 * max(0., nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1] + nz * LIGHT_DIR[2])
            ramp = surface(nx, ny, nz)
            v = lam * (len(ramp) - 1) + (BAYER[y % 4, x % 4] - .5) * .35
            img[y, x] = hexc(ramp[int(min(len(ramp) - 1, max(0, round(v))))])

def spots(seed, n):
    rng = random.Random(seed); out = []
    for _ in range(n):
        v = np.array([rng.gauss(0, 1) for _ in range(3)]); v /= np.linalg.norm(v); v[2] = abs(v[2]); out.append(v)
    return out
def near(pts, nx, ny, nz, r): return any((p[0] - nx) ** 2 + (p[1] - ny) ** 2 + (p[2] - nz) ** 2 < r * r for p in pts)

def io(img):
    n = Noise(11); vol = spots(5, 8)
    Y = ['#a8862a', '#d8b43e', '#f0d460', '#fbec9c']; O = ['#9c5222', '#c8702e', '#e2964a', '#f2bc70']
    D = ['#3a1a10', '#5a2616', '#7a361c', '#984624']
    def s(nx, ny, nz):
        if near(vol, nx, ny, nz, .14): return D
        if near(vol, nx, ny, nz, .23): return O
        return O if n.fbm(nx * 3, ny * 3, nz * 3) > .56 else Y
    body(img, PX, PY, 15, 15, s)

def europa(img):
    n, m = Noise(21), Noise(22)
    C = ['#b0a690', '#d2c8b0', '#ebe3d0', '#faf6ec']; L = ['#7a3c22', '#9e5232', '#bc6c40', '#cc8454']
    def s(nx, ny, nz):
        a = abs(n.fbm(nx * 2.2, ny * 2.2, nz * 2.2) - .5); b = abs(m.fbm(nx * 3.1 + 5, ny * 3.1, nz * 3.1) - .5)
        return L if (a < .03 or b < .026) else C
    body(img, PX, PY, 15, 15, s)

def ganymede(img):
    n = Noise(31); cr = spots(7, 6)
    Dk = ['#6a5c50', '#857668', '#a09080', '#b8a998']; Lt = ['#a29c92', '#c0bab0', '#dcd6cc', '#f0ece4']
    def s(nx, ny, nz):
        if near(cr, nx, ny, nz, .08): return ['#d0cac0', '#e6e0d8', '#f6f2ec', '#ffffff']
        return Lt if n.fbm(nx * 2.5, ny * 2.5, nz * 2.5) > .5 else Dk
    body(img, PX, PY, 16, 16, s)

def callisto(img):
    cr = spots(9, 28); big = spots(3, 2)
    B = ['#3e3028', '#56443a', '#6e5a4c', '#86705e']; Br = ['#a89c90', '#c8beb2', '#e2dace', '#f6f0e8']
    def s(nx, ny, nz):
        if near(big, nx, ny, nz, .13) and not near(big, nx, ny, nz, .08): return Br
        return Br if near(cr, nx, ny, nz, .05) else B
    body(img, PX, PY, 15, 15, s)

def titan(img):
    n = Noise(51)
    A = ['#a8681e', '#cc8c34', '#e6ae58', '#f6d088']; Bd = ['#985a1a', '#bc7c2c', '#d89c46', '#ecbc70']
    def s(nx, ny, nz): return Bd if math.sin((ny + n.fbm(nx * 2, ny * 2, nz * 2) * .25) * 9) > .55 else A
    body(img, PX, PY, 13.5, 13.5, s, halo='#e8c890')

def triton(img):
    n = Noise(61)
    Pk = ['#b09094', '#d0b4b2', '#ead4ce', '#fbeee8']; G = ['#80846e', '#a0a488', '#bec0a4', '#d8d8c2']
    Cap = ['#ccb4b6', '#e6d2d0', '#f8eae6', '#ffffff']
    def s(nx, ny, nz):
        if ny > .35 + (n(nx * 4, 0, nz * 4) - .5) * .3: return Cap
        return G if (n.fbm(nx * 6, ny * 6, nz * 6) > .55 and ny < .1) else Pk
    body(img, PX, PY, 14, 14, s)

def ring(img, cx, cy, rx, ry, front):
    """A 2px band with dark edges, drawn as its back or front half."""
    for y in range(H):
        for x in range(W):
            if ((y + .5 - cy) > 0) != front: continue
            d_out, d_in = ell(x, y, cx, cy, rx + 1, ry + 1), ell(x, y, cx, cy, rx - 2, ry - 1.2)
            if d_out <= 1 and d_in > 1:
                edge = ell(x, y, cx, cy, rx, ry) > 1 or ell(x, y, cx, cy, rx - 1, ry - .6) <= 1
                img[y, x] = DARK if edge else hexc('#cfe2ea')

def haumea(img):
    Wt = ['#a6b0be', '#c8d0da', '#e2e8ee', '#f8fafc']; Rd = ['#7e2630', '#9a3440', '#b4464e', '#c85c62']
    sp = np.array([.15, .25, .95]); sp /= np.linalg.norm(sp)
    def s(nx, ny, nz): return Rd if (nx - sp[0]) ** 2 + (ny - sp[1]) ** 2 + (nz - sp[2]) ** 2 < .06 else Wt
    ring(img, PX, PY + 1, 25, 5, front=False)
    body(img, PX, PY, 14, 9.5, s)
    ring(img, PX, PY + 1, 25, 5, front=True)

def makemake(img):
    n = Noise(81)
    Rb = ['#7a3a20', '#9e5232', '#bc7048', '#d4906a']; Tn = ['#9e7e60', '#bc9c7c', '#d8bc9c', '#eed6bc']
    def s(nx, ny, nz): return Tn if n.fbm(nx * 2.8, ny * 2.8, nz * 2.8) > .55 else Rb
    body(img, PX + 2, PY + 2, 12, 12, s)
    body(img, 16, 37, 3.4, 3.4, lambda *a: ['#8a8292', '#a8a0b0', '#c4bccc', '#dcd6e2'])

def sedna(img):
    n = Noise(91)
    R1 = ['#7a1a16', '#a0281e', '#c03a2c', '#d85444']; R2 = ['#5a1210', '#7a1c16', '#982820', '#b03428']
    def s(nx, ny, nz): return R2 if n.fbm(nx * 3.2, ny * 3.2, nz * 3.2) > .57 else R1
    body(img, PX, PY, 12, 12, s)

# (draw fn, name, secret, one-suit tray?, tray marks)
CARDS = [
    (io,       'IO',       False, False, ['B', 'B', 'C', 'C', 'A', 'A']),   # Three Pair
    (europa,   'EUROPA',   False, False, [1, 2, 3, 4, 5, 6]),               # Long Straight
    (ganymede, 'GANYMEDE', False, True,  [None] * 6),                       # Big Flush
    (callisto, 'CALLISTO', False, False, ['B', 'B', 'B', 'A', 'A', 'A']),   # Double Trips
    (titan,    'TITAN',    False, False, ['B', 'B', 'B', 'B', 'A', 'A']),   # Mansion
    (triton,   'TRITON',   False, True,  [1, 2, 3, 4, 5, 6]),               # Long Straight Flush
    (haumea,   'HAUMEA',   True,  False, ['A'] * 6),                        # Six of a Kind
    (makemake, 'MAKEMAKE', True,  True,  ['B', 'B', 'B', 'B', 'A', 'A']),   # Flush Mansion
    (sedna,    'SEDNA',    True,  True,  ['A'] * 6),                        # Flush Six
]

if __name__ == '__main__':
    out = sys.argv[1]
    flags = [c[2] for c in CARDS]
    sheet = np.zeros((H, W * len(CARDS), 4), np.uint8)
    for i, (fn, name, secret, suited, marks) in enumerate(CARDS):
        img = base_card()
        stars(img, random.Random(300 + i))
        header_icons(img, i, flags)
        name_pill(img, name)
        fn(img)
        tray(img, suited, marks)
        sheet[:, i * W:(i + 1) * W] = img
    im = Image.fromarray(sheet, 'RGBA')
    im.save(f'{out}/planets_1x.png')
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(f'{out}/planets_2x.png')
    im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(f'{out}/preview_4x.png')
    print('ok', im.size)
