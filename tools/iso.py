# -*- coding: utf-8 -*-
"""The counting house, drawn in isometric projection on a character grid.

PROJECTION.  True isometric is a 2:1 ratio (26.57 degrees) -- the ratio that
lands cleanly on a grid instead of aliasing.  A character cell is about 1 wide
by 2 tall, so a 2:1 SCREEN slope needs 4 COLUMNS per 1 ROW, not one per one:

    tan(t) = (rows * 2W) / (cols * W) = 1/2   ->   cols = 4 * rows

hence TW = 4, TH = 1.  A vertical unit must be drawn the same screen length as
a horizontal one: one step along i covers sqrt((4W)^2 + (2W)^2) = 4.47W, which
is 2.24 rows, so KH = 2.

SHADING follows the ramp ' .:-=+*#%@'.  The light is at the upper left: top
faces are lightest, the left-facing faces mid, the right-facing darkest.

Plain ASCII only.  Block and geometric glyphs are East Asian Wide or Ambiguous
and would shear the alignment in half the terminals that open this.
"""
import io

W, H = 78, 44
TW, TH, KH = 4, 1, 2
OX, OY = 39, 15

grid = [[" "] * W for _ in range(H)]

def put(c, r, ch, force=False):
    if 0 <= c < W and 0 <= r < H and (force or ch != " "):
        grid[r][c] = ch

def P(i, j, k=0.0):
    return (int(round(OX + (i - j) * TW)),
            int(round(OY + (i + j) * TH - k * KH)))

def lerp(a, b, f):
    return tuple(a[n] + (b[n] - a[n]) * f for n in range(3))

def edge(a, b, ch, n=300):
    for t in range(n + 1):
        put(*P(*lerp(a, b, t / n)), ch=ch, force=True)

def quad(a, b, c, d, ch, n=170):
    """Fill the planar quad a-b-c-d.  Pass c == d for a triangle."""
    for s in range(n + 1):
        u = s / n
        p, q = lerp(a, b, u), lerp(d, c, u)
        for t in range(n + 1):
            put(*P(*lerp(p, q, t / n)), ch=ch, force=True)

def box(i0, j0, di, dj, dk, k0=0.0, left=".", right=":", top=" ", edges=True):
    i1, j1, k1 = i0 + di, j0 + dj, k0 + dk
    quad((i0, j1, k0), (i1, j1, k0), (i1, j1, k1), (i0, j1, k1), right)
    quad((i1, j0, k0), (i1, j1, k0), (i1, j1, k1), (i1, j0, k1), left)
    quad((i0, j0, k1), (i1, j0, k1), (i1, j1, k1), (i0, j1, k1), top)
    if edges:
        for a, b in [((i0, j0, k1), (i1, j0, k1)), ((i1, j0, k1), (i1, j1, k1)),
                     ((i1, j1, k1), (i0, j1, k1)), ((i0, j1, k1), (i0, j0, k1))]:
            edge(a, b, "_")
        for c in [(i1, j0), (i1, j1), (i0, j1)]:
            edge((c[0], c[1], k0), (c[0], c[1], k1), "|")

def stamp(art, x, y):
    for dy, line in enumerate(art.strip("\n").split("\n")):
        for dx, ch in enumerate(line):
            if ch != " ":
                put(x + dx, y + dy, " " if ch == "@" else ch, force=True)

def stamp_at(art, i, j, k, ox=0, oy=0):
    c, r = P(i, j, k)
    stamp(art, c + ox, r + oy)

# Palette, along the ramp ' .:-=+*#%@'.  The light is at the upper left, so a
# horizontal surface is lightest, a wall facing the light is next, a wall
# facing away is darker, and the tilted roof is darker still.  Two surfaces in
# the same plane get the same value: the gable and the right-hand wall are both
# ':' and are told apart by the roof edge between them, not by shading.
QUAY_TOP, QUAY_L, QUAY_R = " ", ".", ":"
WALL_L, WALL_R = ".", ":"
ROOF, GLASS, SEA = "=", "#", "~"

# ═══ water ═══════════════════════════════════════════════════════════
quad((0, 5.6, 0), (9, 5.6, 0), (9, 9, 0), (0, 9, 0), SEA)

# ═══ the quay ════════════════════════════════════════════════════════
box(0, 0, 9, 5.6, 0.45, left=QUAY_L, right=QUAY_R, top=QUAY_TOP)
edge((0, 5.6, 0.45), (9, 5.6, 0.45), "_")

# ═══ the counting house ══════════════════════════════════════════════
HI0, HI1, HJ0, HJ1 = 0.9, 5.6, 0.6, 4.6
WK, RK, APEX = 0.45, 3.0, 4.6
RIDGE = (HJ0 + HJ1) / 2
EA0, EA1, EJ = HI0 - .35, HI1 + .35, HJ1 + .35

box(HI0, HJ0, HI1 - HI0, HJ1 - HJ0, RK - WK, k0=WK, left=WALL_L, right=WALL_R)

quad((3.0, HJ1, WK), (3.8, HJ1, WK), (3.8, HJ1, 2.0), (3.0, HJ1, 2.0), " ")
edge((3.0, HJ1, 2.0), (3.8, HJ1, 2.0), "_")
edge((3.0, HJ1, WK), (3.0, HJ1, 2.0), "|")
edge((3.8, HJ1, WK), (3.8, HJ1, 2.0), "|")
for wi in (1.4, 4.6):
    quad((wi, HJ1, 1.5), (wi + .7, HJ1, 1.5), (wi + .7, HJ1, 2.4), (wi, HJ1, 2.4), GLASS)
    edge((wi, HJ1, 1.5), (wi + .7, HJ1, 1.5), "_")
    edge((wi, HJ1, 2.4), (wi + .7, HJ1, 2.4), "_")
for wj in (1.2, 3.3):
    quad((HI1, wj, 1.5), (HI1, wj + .7, 1.5), (HI1, wj + .7, 2.4), (HI1, wj, 2.4), GLASS)
    edge((HI1, wj, 1.5), (HI1, wj + .7, 1.5), "_")
    edge((HI1, wj, 2.4), (HI1, wj + .7, 2.4), "_")

# The far slope is NOT drawn.  Ridged along i, its normal points away from the
# viewer, so none of it can be seen -- and because the two slopes are offset on
# screen by 4*(EJ-RIDGE) columns, the near slope cannot cover it either.
# Drawing it put a second roof in the sky.
quad((EA0, EJ, RK), (EA1, EJ, RK), (EA1, RIDGE, APEX), (EA0, RIDGE, APEX), ROOF)
quad((EA1, HJ0 - .35, RK), (EA1, EJ, RK), (EA1, RIDGE, APEX), (EA1, RIDGE, APEX), WALL_R)
edge((EA0, EJ, RK), (EA1, EJ, RK), "_")
edge((EA0, RIDGE, APEX), (EA1, RIDGE, APEX), "_")
edge((EA1, HJ0 - .35, RK), (EA1, RIDGE, APEX), "_")
edge((EA0, EJ, RK), (EA0, RIDGE, APEX), "/")
edge((EA1, EJ, RK), (EA1, RIDGE, APEX), "/")

box(4.1, RIDGE - .35, .7, .7, 1.6, k0=3.7, left=WALL_L, right=WALL_R)   # chimney
stamp_at("""
   ( )
  (   )
 ( ( ) )
  (   )
   ( )
""", 4.45, RIDGE, 5.9, ox=-3, oy=-5)

# ═══ cargo on the quay ══════════════════════════════════════════════
for ci, cj, ck in ((6.7, 0.7, .45), (7.9, 2.1, .45), (6.7, 0.7, 1.25)):
    box(ci, cj, .8, .8, .8, k0=ck, left="=", right="+")

# A barque was moored here.  At this scale her sails came out as blank
# rectangles -- a filled quad of two rows cannot read as canvas -- and she
# fouled the quay edge and the gnu.  The open water is calmer without her.

# ═══ gulls, and the gnu at his own front door ════════════════════════
for gx, gy in ((13, 6), (21, 3), (29, 8), (60, 3), (67, 7)):
    stamp("~v~", gx, gy)
stamp_at(r"""
 ,,,
(o o)
 /|\
""", 3.4, HJ1 + .9, .45, ox=-2, oy=-3)

scene = "\n".join("".join(r).rstrip() for r in grid)
io.open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), 'iso.txt'),
        'w', encoding='utf-8').write(scene)
print(scene)
print("widest:", max(len(l) for l in scene.split("\n")))
