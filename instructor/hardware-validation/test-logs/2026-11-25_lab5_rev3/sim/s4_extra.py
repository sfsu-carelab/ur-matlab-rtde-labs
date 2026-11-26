import numpy as np
from cell import *; from port import *
from s3_flow import *
ref = np.r_[1.7, 0.0, np.pi, 0.3, 0.0, Z_TABLE + 0.005 + GRIP]
ur = Robot(IMG)
print('reach scan along -17 deg ray and +25 deg ray (ref pose exactly tool-down):')
for ang in (-0.3, 0.44):
    for rad in np.arange(0.50, 0.585, 0.01):
        xy = [rad*np.cos(ang), rad*np.sin(ang)]; pick = ref.copy(); pick[3:5] = xy; pre = pick.copy(); pre[5] += 0.10; s = 'r=%.2f ' % rad
        try:
            q1 = poseToJoints(ur, pre, np.deg2rad(IMG)); s += 'approach ok (elbow %.0f deg); ' % np.rad2deg(q1[2])
            try:
                q2 = poseToJoints(ur, pick, q1); st = path_stats(q1, q2, 0.025); s += 'descent ok, bow %.1f mm, min tip height %.1f mm' % (st[2], st[0])
            except LabError: s += 'DESCENT ikFailed (robot left parked above the block)'
        except LabError: s += 'approach ikFailed, no motion'
        print('  ', s)
print('near side: block close to the base')
for rad in (0.12, 0.15, 0.18, 0.22):
    pick = ref.copy(); pick[3:5] = [rad, 0]; pre = pick.copy(); pre[5] += 0.10
    try:
        q1 = poseToJoints(ur, pre, np.deg2rad(IMG)); q2 = poseToJoints(ur, pick, q1); st = path_stats(q1, q2, 0.025)
        print('   r=%.2f ok, joints at pick %s, bow %.1f' % (rad, np.round(np.rad2deg(q2)), st[2]))
    except LabError as e: print('   r=%.2f %s' % (rad, str(e)[:40]))
print('touch -> imaging pose move (script run with the gripper still on the block), 30 spots:')
rng = np.random.default_rng(2); S25, S50, MN = [], [], []
for i in range(30):
    xy = [rng.uniform(0.22, 0.44), rng.uniform(-0.25, 0.18)]; q, e = down_q(xy, Z_TABLE + 0.005, yaw=rng.uniform(1.3, 2.0))
    a = path_stats(q, np.deg2rad(IMG), 0.025); b = path_stats(q, np.deg2rad(IMG), 0.05); S25.append(a[1]); S50.append(b[1]); MN.append(a[0])
print('   sideways travel before the tip clears the cube top: 25 mm cube med %.0f max %.0f mm (gap 30); 50 mm cube med %.0f max %.0f mm (gap 17); min tip height %.1f mm (touch at 5)' % (np.median(S25), max(S25), np.median(S50), max(S50), min(MN)))
print('   share of spots where a 50 mm cube gets hit: %.0f%%; 25 mm cube: %.0f%%' % (100*np.mean(np.array(S50) > 17), 100*np.mean(np.array(S25) > 30)))
# same from Lab-4 style Ready to imaging: joint travel
print('Ready -> imaging: joint travel deg', np.round(np.array(IMG) - np.array(READY)))
