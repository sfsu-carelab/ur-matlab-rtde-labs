"""Draw the figures of the Lab 5 manual (Rev3).
usage: make_lab5_figures.py <camera frame png> <out dir>
Figure 4 is built from a real frame of the lab camera (exp_probe_30.png, 2026-11-04) with a
Python port of detect_block.m; everything else is a schematic in the style of Lab 4 Figure 1."""
import sys, colorsys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, FancyArrowPatch, Circle, FancyBboxPatch, Arc
from matplotlib.colors import hsv_to_rgb, rgb_to_hsv
from PIL import Image
from scipy import ndimage

FRAME, OUT = sys.argv[1], sys.argv[2]
BLUE, ORANGE, GRAY, DARK = (0.25, 0.45, 0.75), (0.85, 0.33, 0.10), (0.35, 0.35, 0.35), (0.1, 0.2, 0.45)
plt.rcParams.update({'font.family': 'Helvetica', 'font.size': 13})

def save(fig, name):
    fig.savefig(f'{OUT}/{name}', dpi=200, bbox_inches='tight', pad_inches=0.08, facecolor='w')
    plt.close(fig)

def arrow(ax, p0, p1, color='k', lw=2, ms=16, style='-|>', ls='-', z=5):
    ax.add_patch(FancyArrowPatch(p0, p1, arrowstyle=style, mutation_scale=ms, lw=lw, color=color,
                                 linestyle=ls, zorder=z, shrinkA=0, shrinkB=0))

def arm(ax, pts, lw=8, color=BLUE, joints=True):
    pts = np.array(pts)
    ax.plot(pts[:, 0], pts[:, 1], color=color, lw=lw, solid_capstyle='round', solid_joinstyle='round', zorder=3)
    if joints:
        ax.plot(pts[1:-1, 0], pts[1:-1, 1], 'o', ms=lw * 1.6, mfc='w', mec=DARK, mew=2, zorder=4)

def gripper(ax, flange, length=0.174, fw=0.035, finger=0.05, color='k', alpha=1.0, angle=0.0):
    """Gripper hanging from the flange point, pointing down (angle in degrees from vertical)."""
    a = np.deg2rad(angle); d = np.array([np.sin(a), -np.cos(a)]); n = np.array([np.cos(a), np.sin(a)])
    f = np.array(flange); palm = f + d * (length - finger); tip = f + d * length
    ax.plot(*zip(f, palm), color=(0.3, 0.3, 0.3), lw=6, alpha=alpha, zorder=3, solid_capstyle='butt')
    ax.plot(*zip(palm - n * fw, palm + n * fw), color=color, lw=3.5, alpha=alpha, zorder=4)
    for s in (-1, 1):
        ax.plot(*zip(palm + s * n * fw, tip + s * n * fw), color=color, lw=3.5, alpha=alpha, zorder=4)
    return tip

def base(ax, x=0.0, w=0.12, h=0.03):
    ax.add_patch(Rectangle((x - w / 2, 0), w, h, fc=BLUE, ec='none', zorder=3))

def table(ax, x0, x1):
    ax.plot([x0, x1], [0, 0], color=GRAY, lw=3, zorder=2)

# ------------------------------------------------------------------ Figure 1: the cell and the pipeline
def fig1():
    fig = plt.figure(figsize=(9, 6.6))
    ax = fig.add_axes([0, 0.27, 1, 0.73]); ax.set_aspect('equal'); ax.axis('off')
    table(ax, -0.42, 0.78)
    base(ax)
    # arm parked at the imaging pose: folded up and back, out of the camera view
    P = [(0, 0.03), (0, 0.152), (-0.14, 0.35), (-0.02, 0.50), (-0.02, 0.41)]
    arm(ax, P); gripper(ax, P[-1], length=0.13, fw=0.028, finger=0.04)
    # camera on a mast, looking straight down
    cx, cy = 0.40, 0.78
    ax.plot([0.74, 0.74], [0, cy + 0.03], color=GRAY, lw=5, zorder=2)
    ax.plot([0.74, cx], [cy + 0.03, cy + 0.03], color=GRAY, lw=5, zorder=2)
    ax.add_patch(Rectangle((cx - 0.05, cy - 0.015), 0.10, 0.045, fc='k', ec='none', zorder=4))
    ax.add_patch(Rectangle((cx - 0.012, cy - 0.03), 0.024, 0.02, fc='k', ec='none', zorder=4))
    half = 0.27
    ax.add_patch(Polygon([(cx, cy - 0.03), (cx - half, 0), (cx + half, 0)], fc=(1.0, 0.93, 0.6), ec='none', alpha=0.45, zorder=1))
    for s in (-1, 1):
        ax.plot([cx, cx + s * half], [cy - 0.03, 0], color=(0.75, 0.6, 0.1), lw=1.5, ls='--', zorder=1)
    ax.add_patch(Rectangle((0.33, 0), 0.05, 0.05, fc=ORANGE, ec='none', zorder=3))
    t = lambda x, y, s, **k: ax.text(x, y, s, fontsize=14, **k)
    t(cx - 0.07, cy + 0.01, 'fixed camera,\nlooking down at the table', ha='right', va='center')
    t(cx + 0.02, 0.36, 'field of view', ha='center', color=(0.5, 0.4, 0.05))
    t(0.405, 0.025, 'block', va='center')
    t(-0.17, 0.44, 'robot parked at the\nimaging pose, outside\nthe field of view', ha='right', va='center')
    t(-0.075, 0.045, 'base', ha='right')
    t(-0.41, -0.035, 'table', va='top')
    ax.set_xlim(-0.62, 0.80); ax.set_ylim(-0.07, 0.86)
    # pipeline strip
    bx = fig.add_axes([0, 0, 1, 0.25]); bx.axis('off'); bx.set_xlim(0, 10); bx.set_ylim(0, 2)
    steps = [('1. Capture', 'one RGB image\nfrom the camera'),
             ('2. Detect', 'the block centroid\nin pixels (u, v)'),
             ('3. Convert', 'pixels to base\ncoordinates (X, Y)'),
             ('4. Pick', 'move to (X, Y),\ngrip, lift, place')]
    w, gap, x = 2.05, 0.5, 0.15
    for k, (head, body) in enumerate(steps):
        bx.add_patch(FancyBboxPatch((x, 0.25), w, 1.5, boxstyle='round,pad=0.02,rounding_size=0.12', fc=(0.93, 0.95, 0.99), ec=BLUE, lw=2))
        bx.text(x + w / 2, 1.42, head, ha='center', va='center', fontsize=14, fontweight='bold', color=DARK)
        bx.text(x + w / 2, 0.80, body, ha='center', va='center', fontsize=12.5)
        if k < 3: arrow(bx, (x + w + 0.06, 1.0), (x + w + gap - 0.06, 1.0), color=DARK, lw=2.5, ms=18)
        x += w + gap
    save(fig, 'fig1_cell.png')

# ------------------------------------------------------------------ Figure 2: pixel frame and base frame
def fig2():
    fig, (a, b) = plt.subplots(1, 2, figsize=(10.5, 4.6), gridspec_kw={'wspace': 0.32})
    # (a) image
    a.set_aspect('equal'); a.axis('off')
    a.add_patch(Rectangle((0, 0), 1280, 720, fc=(0.16, 0.18, 0.19), ec='k', lw=2))
    a.set_xlim(-190, 1300); a.set_ylim(800, -190)
    arrow(a, (0, -75), (430, -75), color='k', lw=3, ms=20); a.text(455, -75, 'u', color='k', fontsize=17, va='center', fontweight='bold', style='italic')
    arrow(a, (-75, 0), (-75, 330), color='k', lw=3, ms=20); a.text(-75, 385, 'v', color='k', fontsize=17, ha='center', va='center', fontweight='bold', style='italic')
    a.plot(0, 0, 'o', ms=9, mfc='w', mec='k', zorder=6, clip_on=False)
    a.text(-25, -25, '(0, 0)', ha='right', va='bottom', fontsize=12)
    a.text(1280, 755, '(1280, 720)', ha='right', va='top', fontsize=12)
    u, v = 820, 430
    a.add_patch(Rectangle((u - 45, v - 45), 90, 90, fc=ORANGE, ec='none'))
    a.plot(u, v, '+', ms=22, mew=3, color='w')
    a.plot([u, u], [0, v], color='w', lw=1.2, ls=':'); a.plot([0, u], [v, v], color='w', lw=1.2, ls=':')
    a.text(u, v + 70, 'block centroid\n(u, v), in pixels', color='w', fontsize=12.5, ha='center', va='top')
    a.set_title('(a) Camera image, 1280 x 720 pixels', fontsize=14, pad=4)
    # (b) table top view
    b.set_aspect('equal'); b.axis('off')
    b.add_patch(Rectangle((-0.45, -0.72), 0.95, 0.90, fc=(0.93, 0.93, 0.93), ec=GRAY, lw=1.5))
    th = np.deg2rad(-12)                       # field of view, slightly rotated against the base axes
    R = np.array([[np.cos(th), -np.sin(th)], [np.sin(th), np.cos(th)]])
    c0 = np.array([0.02, -0.40]); hw, hh = 0.36, 0.2025
    corners = [c0 + R @ np.array(p) for p in [(-hw, hh), (hw, hh), (hw, -hh), (-hw, -hh)]]
    b.add_patch(Polygon(corners, fc=(1.0, 0.93, 0.6), ec=(0.75, 0.6, 0.1), lw=1.5, ls='--', alpha=0.55))
    b.text(*(c0 + R @ np.array((-hw + 0.015, -hh + 0.02))), 'area the camera sees', fontsize=11.5, rotation=-12, color=(0.5, 0.4, 0.05), ha='left', va='bottom')
    b.add_patch(Circle((0, 0), 0.065, fc=BLUE, ec=DARK, lw=2, zorder=4))
    b.text(0.085, 0.07, 'robot base', fontsize=12.5, va='center')
    arrow(b, (0, 0), (0, -0.30), color='k', lw=3, ms=20, z=6); b.text(-0.03, -0.30, 'X', fontsize=17, fontweight='bold', style='italic', ha='right', va='center')
    arrow(b, (0, 0), (0.30, 0), color='k', lw=3, ms=20, z=6); b.text(0.335, 0, 'Y', fontsize=17, fontweight='bold', style='italic', va='center')
    blk = c0 + R @ np.array(((u - 640) / 1280 * 2 * hw, -(v - 360) / 720 * 2 * hh))
    sq = [blk + R @ np.array(p) for p in [(-0.025, 0.025), (0.025, 0.025), (0.025, -0.025), (-0.025, -0.025)]]
    b.add_patch(Polygon(sq, fc=ORANGE, ec='none', zorder=5))
    b.plot([blk[0], blk[0]], [0, blk[1]], color='k', lw=1.2, ls=':'); b.plot([0, blk[0]], [blk[1], blk[1]], color='k', lw=1.2, ls=':')
    b.text(blk[0] + 0.045, blk[1] - 0.005, 'same block,\n(X, Y) in meters', fontsize=12.5, va='center')
    b.text(-0.43, -0.70, 'table', fontsize=12.5, va='bottom')
    b.set_xlim(-0.47, 0.52); b.set_ylim(-0.74, 0.20)
    b.set_title('(b) Table seen from above, robot base frame', fontsize=14, pad=4)
    # link between the panels
    fig.patches.append(FancyArrowPatch((0.455, 0.50), (0.545, 0.50), transform=fig.transFigure, arrowstyle='-|>', mutation_scale=26, lw=3, color=DARK))
    fig.text(0.50, 0.57, 'calibration', ha='center', fontsize=13, color=DARK, fontweight='bold')
    fig.text(0.50, 0.40, 'matrix A', ha='center', fontsize=13, color=DARK)
    save(fig, 'fig2_frames.png')

# ------------------------------------------------------------------ Figure 3: the three HSV channels
def fig3():
    fig = plt.figure(figsize=(9.5, 4.3))
    n = 720
    ax = fig.add_axes([0.16, 0.56, 0.80, 0.16])
    hue = np.linspace(0, 1, n)
    ax.imshow(hsv_to_rgb(np.dstack([hue[None, :].repeat(40, 0), np.ones((40, n)), np.ones((40, n))])), aspect='auto', extent=[0, 1, 0, 1])
    ax.set_yticks([]); ax.set_xticks(np.arange(0, 1.01, 0.1)); ax.tick_params(labelsize=12)
    fig.text(0.145, 0.64, 'Hue (h)', ha='right', va='center', fontsize=14, fontweight='bold')
    def band(lo, hi, label, x=None, color='k'):
        y = 1.22
        ax.plot([lo, lo, hi, hi], [y - 0.14, y, y, y - 0.14], color=color, lw=2.2, clip_on=False)
        ax.text((lo + hi) / 2 if x is None else x, y + 0.14, label, ha='center', va='bottom', fontsize=12, clip_on=False)
    band(0.0, 0.05, '', ); band(0.95, 1.0, '')
    ax.text(0.0, 1.50, 'red: 0 to 0.05 ...', ha='left', va='bottom', fontsize=12, clip_on=False)
    ax.text(1.0, 1.50, '... and 0.95 to 1', ha='right', va='bottom', fontsize=12, clip_on=False)
    band(0.25, 0.45, 'green: 0.25 to 0.45')
    band(0.55, 0.70, 'blue: 0.55 to 0.70')
    fig.text(0.56, 0.90, 'Red sits at both ends of the hue scale, so a red band wraps around: lower hue limit 0.95, upper hue limit 0.05',
             ha='center', va='center', fontsize=11.5, style='italic')
    for k, (name, lab0, lab1) in enumerate([('Saturation (s)', 'gray, washed out', 'pure, vivid color'), ('Value (v)', 'dark', 'bright')]):
        bx = fig.add_axes([0.16, 0.30 - 0.21 * k, 0.80, 0.10])
        x = np.linspace(0, 1, n)[None, :].repeat(30, 0)
        hsv = np.dstack([np.full_like(x, 0.03), x, np.ones_like(x)]) if k == 0 else np.dstack([np.full_like(x, 0.03), np.ones_like(x), x])
        bx.imshow(hsv_to_rgb(hsv), aspect='auto', extent=[0, 1, 0, 1]); bx.set_yticks([]); bx.set_xticks([0, 0.25, 0.5, 0.75, 1]); bx.tick_params(labelsize=12)
        fig.text(0.145, 0.35 - 0.21 * k, name, ha='right', va='center', fontsize=14, fontweight='bold')
        bx.text(0.012, 0.5, lab0, ha='left', va='center', fontsize=11.5, color='k' if k == 0 else 'w')
        bx.text(0.988, 0.5, lab1, ha='right', va='center', fontsize=11.5, color='w' if k == 0 else 'k')
    save(fig, 'fig3_hsv.png')

# ------------------------------------------------------------------ Figure 4: a real detection
def detect_block(img, lo, hi, min_area):
    """Port of detect_block.m: HSV band (hue wraps when lo > hi), small blobs removed, largest blob."""
    hsv = rgb_to_hsv(img.astype(float) / 255.0); h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    hm = (h >= lo[0]) & (h <= hi[0]) if lo[0] <= hi[0] else (h >= lo[0]) | (h <= hi[0])
    mask = hm & (s >= lo[1]) & (s <= hi[1]) & (v >= lo[2]) & (v <= hi[2])
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n == 0: return None, mask, 0
    area = ndimage.sum(mask, lab, range(1, n + 1))
    keep = np.isin(lab, 1 + np.flatnonzero(area >= min_area));
    if not keep.any(): return None, keep, 0
    k = 1 + int(np.argmax(area)); cy, cx = ndimage.center_of_mass(lab == k)
    return (cx + 1, cy + 1), keep, int(area.max())

def fig4():
    img = np.array(Image.open(FRAME).convert('RGB'))
    uv, mask, area = detect_block(img, (0.95, 0.50, 0.30), (0.05, 1.0, 1.0), 200)
    print('figure 4 detection (red band): centroid u=%.1f v=%.1f, area %d px, blobs kept %d' % (uv[0], uv[1], area, ndimage.label(mask)[1]))
    over = img.astype(float).copy()
    over[mask] = 0.45 * over[mask] + 0.55 * np.array([0, 60, 255])
    over = over.astype(np.uint8)
    x0, x1, y0, y1 = 0, 900, 40, 720
    fig, (a, b) = plt.subplots(1, 2, figsize=(10.5, 4.3), gridspec_kw={'wspace': 0.04})
    for ax, im, ttl in ((a, img, '(a) MATLAB Figure 1: the camera image'), (b, over, '(b) MATLAB Figure 2: the mask and the centroid')):
        ax.imshow(im[y0:y1, x0:x1], extent=[x0, x1, y1, y0]); ax.set_xticks([]); ax.set_yticks([]); ax.set_title(ttl, fontsize=13, pad=5)
    b.plot(uv[0], uv[1], '+', color='r', ms=24, mew=3)
    b.annotate('red cross =\ncentroid (u, v)', xy=(uv[0] + 14, uv[1] - 14), xytext=(uv[0] + 120, uv[1] - 190), color='w', fontsize=12.5,
               arrowprops=dict(arrowstyle='-|>', color='w', lw=1.8), ha='left')
    b.annotate('tinted pixels =\nthe mask', xy=(uv[0] - 30, uv[1] + 8), xytext=(60, 660), color='w', fontsize=12.5,
               arrowprops=dict(arrowstyle='-|>', color='w', lw=1.8), ha='left', va='center')
    a.annotate('robot base', xy=(640, 62), xytext=(250, 300), color='w', fontsize=12.5, arrowprops=dict(arrowstyle='-|>', color='w', lw=1.8), ha='center')
    a.annotate('red block', xy=(535, 600), xytext=(700, 480), color='w', fontsize=12.5, arrowprops=dict(arrowstyle='-|>', color='w', lw=1.8), ha='center')
    save(fig, 'fig4_detection.png')

# ------------------------------------------------------------------ Figure 5: calibration spots and the touch
def fig5():
    fig = plt.figure(figsize=(10.5, 4.9))
    def view(pos, spots, title, note, good):
        ax = fig.add_axes(pos); ax.set_aspect('equal'); ax.axis('off')
        ax.add_patch(Rectangle((0, 0), 1280, 720, fc=(0.16, 0.18, 0.19), ec='k', lw=2))
        ax.add_patch(Rectangle((230, 150), 820, 470, fc='none', ec=(1.0, 0.85, 0.3), lw=1.8, ls='--'))
        ax.text(640, 135, 'area you will pick from', color=(1.0, 0.85, 0.3), fontsize=10.5, ha='center', va='bottom')
        for k, (x, y) in enumerate(spots):
            ax.add_patch(Rectangle((x - 38, y - 38), 76, 76, fc=ORANGE, ec='none'))
            ax.text(x, y, str(k + 1), color='w', fontsize=12.5, fontweight='bold', ha='center', va='center')
        ax.set_xlim(-10, 1290); ax.set_ylim(730, -10)
        ax.set_title(title, fontsize=13, pad=5, color=(0.0, 0.45, 0.15) if good else (0.75, 0.1, 0.1), fontweight='bold')
        ax.text(640, 750, note, fontsize=11.5, ha='center', va='top')
    view([0.0, 0.56, 0.36, 0.36], [(300, 215), (980, 215), (980, 555), (300, 555)], '(a) Spread out: good', 'the four spots frame the pick area', True)
    view([0.0, 0.06, 0.36, 0.36], [(700, 300), (860, 300), (860, 440), (700, 440)], '(b) Clustered: poor', 'the map drifts away from the cluster', False)
    # (c) the touch, side view
    ax = fig.add_axes([0.40, 0.0, 0.60, 1.0]); ax.set_aspect('equal'); ax.axis('off')
    table(ax, -0.20, 0.36)
    bw = 0.05
    ax.add_patch(Rectangle((-bw / 2, 0), bw, bw, fc=ORANGE, ec='none', zorder=3))
    fl = (0.0, 0.012 + 0.174)
    ax.plot([0, 0], [fl[1], fl[1] + 0.07], color=BLUE, lw=9, zorder=3, solid_capstyle='butt')
    ax.plot([0, -0.13], [fl[1] + 0.07, fl[1] + 0.07], color=BLUE, lw=9, zorder=3, solid_capstyle='round')
    ax.plot(0, fl[1] + 0.07, 'o', ms=13, mfc='w', mec=DARK, mew=2, zorder=4)
    gripper(ax, fl, fw=0.043, finger=0.06)
    ax.plot([0, 0], [-0.025, fl[1] + 0.095], color='k', lw=1.2, ls='-.', zorder=6)
    ax.plot(*fl, 'o', ms=10, mfc='r', mec='k', zorder=7)
    ax.annotate('tool flange: the point whose\nX, Y, Z readCartesianPose returns', xy=(0.006, fl[1]), xytext=(0.075, fl[1] + 0.035), fontsize=12.5,
                arrowprops=dict(arrowstyle='-|>', color='k', lw=1.5), va='center')
    ax.text(0.075, 0.105, 'open gripper pointing\nstraight down, so the flange\nis directly above the block', fontsize=12.5, va='center')
    ax.annotate('block centered\nbetween the fingers', xy=(0.027, 0.03), xytext=(0.075, 0.035), fontsize=12.5, arrowprops=dict(arrowstyle='-|>', color='k', lw=1.5), va='center')
    ax.text(-0.19, -0.012, 'table', fontsize=12.5, va='top')
    # dimension: gripper length
    xd = -0.085
    ax.annotate('', xy=(xd, 0.012), xytext=(xd, fl[1]), arrowprops=dict(arrowstyle='<|-|>', color=GRAY, lw=1.5))
    ax.plot([xd - 0.01, -0.005], [fl[1], fl[1]], color=GRAY, lw=1, ls=':')
    ax.text(xd - 0.008, 0.09, 'gripper length\n(174 mm for\nthe 2F-85)', fontsize=11.5, ha='right', va='center', color=GRAY)
    ax.set_xlim(-0.24, 0.37); ax.set_ylim(-0.045, 0.31)
    ax.set_title('(c) The touch, seen from the side', fontsize=13, pad=0, y=0.93)
    save(fig, 'fig5_calibration.png')

# ------------------------------------------------------------------ Figure 6: the pick sequence
def fig6():
    fig = plt.figure(figsize=(9.5, 5.2)); ax = fig.add_axes([0, 0, 1, 1]); ax.set_aspect('equal'); ax.axis('off')
    table(ax, -0.50, 0.66); base(ax)
    P = [(0, 0.03), (0, 0.152), (-0.14, 0.35), (-0.02, 0.50), (-0.02, 0.41)]
    arm(ax, P); gripper(ax, P[-1], length=0.13, fw=0.028, finger=0.04)
    img_pt = np.array((-0.02, 0.28)); xb, xp = 0.30, 0.55
    ax.add_patch(Rectangle((xb - 0.025, 0), 0.05, 0.05, fc=ORANGE, ec='none', zorder=3))
    ax.add_patch(Rectangle((xp - 0.025, 0), 0.05, 0.05, fc='none', ec=ORANGE, lw=2, ls='--', zorder=3))
    pick = np.array((xb, 0.025)); pre = np.array((xb, 0.16)); place = np.array((xp, 0.055))
    for p in (pre, pick, place):
        ax.plot(*p, 'o', ms=9, mfc='w', mec='k', mew=2, zorder=8)
    C = DARK
    def curved(p0, p1, rad, label, lp, ls='-'):
        ax.add_patch(FancyArrowPatch(p0, p1, connectionstyle=f'arc3,rad={rad}', arrowstyle='-|>', mutation_scale=18, lw=2.2, color=C, zorder=6, shrinkA=6, shrinkB=6, linestyle=ls))
        num(label, lp)
    def num(label, lp):
        ax.text(*lp, label, fontsize=12, fontweight='bold', color='w', ha='center', va='center', zorder=9,
                bbox=dict(boxstyle='circle,pad=0.22', fc=C, ec='none'))
    curved(img_pt + (0.03, 0.0), pre, -0.25, '1', (0.17, 0.285))
    ax.add_patch(FancyArrowPatch(pre + (-0.012, 0), pick + (-0.012, 0), arrowstyle='-|>', mutation_scale=18, lw=2.2, color=C, zorder=6, shrinkA=6, shrinkB=6)); num('2', (xb - 0.045, 0.10))
    num('3', (xb - 0.065, 0.025))
    ax.add_patch(FancyArrowPatch(pick + (0.012, 0), pre + (0.012, 0), arrowstyle='-|>', mutation_scale=18, lw=2.2, color=C, zorder=6, shrinkA=6, shrinkB=6)); num('4', (xb + 0.045, 0.10))
    curved(pre, place + (-0.005, 0), -0.22, '5', (0.445, 0.158))
    num('6', (xp + 0.065, 0.055))
    curved(place + (0.005, 0.01), img_pt + (0.04, 0.035), 0.5, '7', (0.34, 0.345))
    t = lambda x, y, s, **k: ax.text(x, y, s, fontsize=12.5, **k)
    t(xb - 0.03, 0.163, 'approach point', ha='right', va='center')
    ax.annotate('', xy=(xb + 0.095, 0.025), xytext=(xb + 0.095, 0.16), arrowprops=dict(arrowstyle='<|-|>', color=GRAY, lw=1.5))
    t(xb + 0.105, 0.0925, '10 cm', va='center', color=GRAY)
    t(xb, -0.02, 'block at the detected (X, Y)', ha='center', va='top')
    t(xp + 0.02, -0.02, 'drop-off', ha='center', va='top')
    t(-0.17, 0.44, 'imaging pose', ha='right', va='center')
    t(-0.49, -0.02, 'table', va='top')
    legend = ['1  Approach above the block', '2  Down to the pick pose', '3  Close the gripper', '4  Lift',
              '5  Move to the place waypoint', '6  Open the gripper', '7  Back to the imaging pose']
    for k, s in enumerate(legend):
        ax.text(-0.50, 0.30 - 0.033 * k, s, fontsize=12, va='center')
    ax.set_xlim(-0.52, 0.68); ax.set_ylim(-0.07, 0.56)
    save(fig, 'fig6_sequence.png')

for f in (fig1, fig2, fig3, fig4, fig5, fig6): f()
print('figures written to', OUT)
