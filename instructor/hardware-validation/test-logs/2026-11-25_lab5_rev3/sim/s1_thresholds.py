import numpy as np
from PIL import Image
from matplotlib.colors import rgb_to_hsv
from cell import *; from port import *
np.set_printoptions(precision=3, suppress=True)
cam = Camera()
IMG_Q = np.deg2rad([0.95, -71.2, -33.84, -142.19, 89.36, 180.96])
base = Box((0, 0), 0.16, 0.074, COL['metal'], zbase=Z_TABLE)
red = Box((0.40, -0.05), 0.025, 0.025, COL['red'], yaw=0.2); teal = Box((0.45, -0.20), 0.025, 0.025, COL['teal'], yaw=0.5)
def click(img, P, n=5):
    (uv,), _ = cam.project(np.array([P])); u, v = int(uv[0]), int(uv[1])
    return np.median(rgb_to_hsv(img[v-n:v+n+1, u-n:u+n+1].reshape(-1, 3) / 255.0), axis=0)
def rule(c, dh=0.05, ds=0.3, dv=0.3):
    lo = [(c[0] - dh) % 1, max(c[1] - ds, 0), max(c[2] - dv, 0)]; hi = [(c[0] + dh) % 1, 1, 1]; return np.round(lo, 2), np.round(hi, 2)
for noise in (4, 8):
    print('\n=== pixel noise sigma', noise)
    img = render(cam, [base, red, teal], arm_q=IMG_Q, noise=noise, rng=np.random.default_rng(1))
    if noise == 4: Image.fromarray(img).save('scene_imaging_pose.png')
    cr = click(img, [0.40, -0.05, Z_TABLE + 0.025]); ct = click(img, [0.45, -0.20, Z_TABLE + 0.025]); cb = click(img, [0.5, 0.1, Z_TABLE])
    print('click red', cr, 'teal', ct, 'table', cb)
    tb = rgb_to_hsv(img[300:400, 900:1000].reshape(-1, 3) / 255.0)
    print('table pixel spread: H %.3f-%.3f  S %.2f-%.2f  V %.2f-%.2f (1-99 pct)' % tuple(np.percentile(tb, [1, 99], axis=0).T.ravel()))
    bands = {'default green': ([0.25, 0.35, 0.25], [0.45, 1, 1]), 'hardware red': ([0.95, 0.5, 0.3], [0.05, 1, 1]),
             'hardware teal': ([0.47, 0.55, 0.35], [0.54, 1, 1]), 'rule red': rule(cr), 'rule teal': rule(ct),
             'rule teal, V floor = midway block/table': ([(ct[0]-0.05) % 1, max(ct[1]-0.3, 0), (ct[2]+cb[2])/2], [(ct[0]+0.05) % 1, 1, 1])}
    for name, (lo, hi) in bands.items():
        uv, mask, stats = detect_block(img, lo, hi, 200)
        print('%-42s lo %s hi %s -> %d blob(s), areas %s, centroid %s' % (name, np.round(lo, 2), np.round(hi, 2), len(stats), stats[:4], np.round(uv, 1)))
(pr, pt), _ = cam.project(np.array([[0.40, -0.05, Z_TABLE + 0.025], [0.45, -0.20, Z_TABLE + 0.025]])); print('true top-centre px red', pr, 'teal', pt)
# arm in view: arm parked over the work area, and UR-blue joint caps vs the teal band
for name, q in {'arm at Lab4-style Ready over table': [0, -80, -80, -110, 90, 0], 'arm retracted 15 cm above last touch': None}.items():
    if q is None:
        T = np.eye(4); T[:3, :3] = eul2R([1.6, 0, np.pi]); T[:3, 3] = [0.40, -0.05, 0.105 + 0.15]; qq, _ = ik_step(T, np.deg2rad([0, -110, -90, -70, 90, 0]))
    else: qq = np.deg2rad(q)
    img = render(cam, [base, red, teal], arm_q=qq, noise=4)
    Image.fromarray(img).save('scene_%s.png' % name.split()[1])
    for bn in ('hardware red', 'hardware teal'):
        uv, mask, stats = detect_block(img, *bands[bn], 200); print('%-40s %-14s blobs %s centroid %s' % (name, bn, stats[:4], np.round(uv, 1)))
# stray red object
for nm, size in (('stray red pouch 60x40 mm', (0.06, 0.04)), ('stray red marker cap 15 mm', (0.015, 0.015))):
    img = render(cam, [base, red, teal, Box((0.30, 0.15), size, 0.01, COL['red'] * 0.95)], arm_q=IMG_Q)
    uv, mask, stats = detect_block(img, *bands['hardware red'], 200); print(nm, '-> blobs', stats, 'centroid', np.round(uv, 1), '(block is at', np.round(pr, 1), ')')
