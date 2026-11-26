"""Simulated cell: pinhole bird's-eye camera, rendered scene, UR3e with slider-scaled moves, server that drops commands."""
import numpy as np, colorsys
from PIL import Image, ImageDraw
from kin import *
Z_TABLE = -0.074          # table below base plane: flange Z at a touch ~0.105 with a 174 mm gripper
GRIP = 0.174
W, H, F = 1280, 720, 920.0
def hsv(h, s, v): return np.array(colorsys.hsv_to_rgb(h, s, v)) * 255
COL = dict(table=hsv(0.436, 0.58, 0.25), red=hsv(0.033, 0.81, 0.65), teal=hsv(0.478, 0.95, 0.51),
           wall=hsv(0.25, 0.04, 0.88), floor=hsv(0.10, 0.10, 0.55), metal=hsv(0.6, 0.05, 0.70),
           blue=hsv(0.58, 0.60, 0.70), green=hsv(0.36, 0.7, 0.55), black=hsv(0, 0, 0.08))
class Camera:
    def __init__(self, tilt_deg=(2.0, -1.5), height=0.92, centre=(0.4393, 0.0386)):
        u = np.array([-0.1435, 0.9787, 0]); u /= np.linalg.norm(u)
        z = np.array([0, 0, -1.0]); v = np.cross(z, u)          # image y; (0.979,0.143,0)
        R = np.c_[u, v, z]                                        # camera axes in world
        ax, ay = np.deg2rad(tilt_deg)
        Rx = np.array([[1,0,0],[0,np.cos(ax),-np.sin(ax)],[0,np.sin(ax),np.cos(ax)]])
        Ry = np.array([[np.cos(ay),0,np.sin(ay)],[0,1,0],[-np.sin(ay),0,np.cos(ay)]])
        self.R = R @ Rx @ Ry
        # keep the optical axis hitting the table at `centre`
        self.C = np.array([centre[0], centre[1], Z_TABLE]) - self.R[:, 2] * height / abs(self.R[2, 2]) * abs(self.R[2,2])
        self.C = np.array([centre[0], centre[1], Z_TABLE]) - self.R[:, 2] * (height / -self.R[2, 2])
    def project(self, P):
        pc = (np.atleast_2d(P) - self.C) @ self.R
        return np.c_[F * pc[:, 0] / pc[:, 2] + W/2, F * pc[:, 1] / pc[:, 2] + H/2], pc[:, 2]
class Box:
    def __init__(s, xy, size, height, color, yaw=0.0, zbase=Z_TABLE, side=0.6):
        s.xy = np.array(xy, float); s.size = np.atleast_1d(size) * np.ones(2); s.h = height; s.color = np.array(color, float)
        s.yaw = yaw; s.zb = zbase; s.side = side
def render(cam, boxes, arm_q=None, roi=None, noise=4.0, rng=None, gripper_open=True):
    rng = rng or np.random.default_rng(0)
    u0, v0, u1, v1 = roi or (0, 0, W, H)
    uu, vv = np.meshgrid(np.arange(u0, u1) + 0.5, np.arange(v0, v1) + 0.5)
    d = np.stack([(uu - W/2) / F, (vv - H/2) / F, np.ones_like(uu)], -1) @ cam.R.T      # world ray dirs
    C = cam.C
    t = (Z_TABLE - C[2]) / d[..., 2]
    X = C[0] + t * d[..., 0]; Y = C[1] + t * d[..., 1]
    img = np.empty(uu.shape + (3,)); img[:] = COL['table']
    img[Y > 0.25] = COL['wall']; img[Y < -0.50 - 0.15 * (X - 0.4)] = COL['floor']
    tbest = t.copy()
    for b in boxes:
        c, s = np.cos(-b.yaw), np.sin(-b.yaw)
        o = np.array([C[0] - b.xy[0], C[1] - b.xy[1], C[2]]); o = np.array([c*o[0] - s*o[1], s*o[0] + c*o[1], o[2]])
        dx = c * d[..., 0] - s * d[..., 1]; dy = s * d[..., 0] + c * d[..., 1]; dz = d[..., 2]
        lo = np.array([-b.size[0]/2, -b.size[1]/2, b.zb]); hi = np.array([b.size[0]/2, b.size[1]/2, b.zb + b.h])
        tn = np.full(uu.shape, -np.inf); tf = np.full(uu.shape, np.inf); face = np.zeros(uu.shape, int)
        for k, dk in enumerate((dx, dy, dz)):
            with np.errstate(divide='ignore', invalid='ignore'):
                ta = (lo[k] - o[k]) / dk; tb = (hi[k] - o[k]) / dk
            tmin = np.minimum(ta, tb); tmax = np.maximum(ta, tb)
            upd = tmin > tn; tn = np.where(upd, tmin, tn); face = np.where(upd, k, face); tf = np.minimum(tf, tmax)
        hit = (tn < tf) & (tn > 0) & (tn < tbest)
        shade = np.where(face == 2, 1.0, np.where(face == 0, b.side, b.side * 0.8))
        img[hit] = b.color * shade[hit][:, None]; tbest = np.where(hit, tn, tbest)
    if arm_q is not None:
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)); dr = ImageDraw.Draw(im)
        Fr = fk(arm_q, True); pts = [T[:3, 3] for T in Fr]
        # offset links: insert DH intermediate points so the drawing has the shoulder/elbow offsets
        segs = [(pts[0], pts[1], 0.09, 'metal'), (pts[1], pts[2], 0.075, 'metal'), (pts[2], pts[3], 0.065, 'metal'),
                (pts[3], pts[4], 0.065, 'metal'), (pts[4], pts[5], 0.065, 'metal'), (pts[5], pts[6], 0.065, 'metal')]
        T6 = Fr[6]; tip = T6[:3, 3] + T6[:3, 2] * GRIP; palm = T6[:3, 3] + T6[:3, 2] * 0.10
        segs.append((pts[6], palm, 0.075, 'black'))
        half = 0.0425 if gripper_open else 0.0125
        for sgn in (-1, 1):
            segs.append((palm + sgn * half * T6[:3, 0], tip + sgn * half * T6[:3, 0], 0.02, 'black'))
        segs.sort(key=lambda sg: -cam.project((sg[0] + sg[1]) / 2)[1][0])
        for a, b_, dia, col in segs:
            (pa, pb), dep = cam.project(np.array([a, b_]))
            if dep.min() <= 0.05: continue
            wpx = max(2, int(dia * F / dep.mean()))
            dr.line([pa[0] - u0, pa[1] - v0, pb[0] - u0, pb[1] - v0], fill=tuple(COL[col].astype(int)), width=wpx)
            for p, de in ((pa, dep[0]), (pb, dep[1])):
                r = dia * F / de / 2
                if col == 'metal': dr.ellipse([p[0]-u0-r, p[1]-v0-r, p[0]-u0+r, p[1]-v0+r], fill=tuple(COL['blue'].astype(int)))
        img = np.asarray(im).astype(float)
    img = img + rng.normal(0, noise, img.shape)
    return np.clip(np.round(img), 0, 255).astype(np.uint8)

class Clock:
    def __init__(s): s.t = 0.0
class Robot:
    """UR3e + URServerScript model. Virtual time."""
    def __init__(s, q_deg, slider=1.0, clock=None, playing=True):
        s.clk = clock or Clock(); s.slider = slider; s.playing = playing
        s.q0 = np.deg2rad(q_deg).astype(float); s.q1 = s.q0.copy(); s.t0 = 0.0; s.dur = 0.0
        s.busy_until = -1.0; s.gripper = 'open'; s.grip_event = None; s.lastGrip = None
        s.log = []; s.dropped = []; s.held = None; s.paths = []
    def q(s, t=None):
        t = s.clk.t if t is None else t
        if s.dur <= 0 or t >= s.t0 + s.dur: return s.q1.copy()
        x = (t - s.t0) / s.dur; a = 10*x**3 - 15*x**4 + 6*x**5
        return s.q0 + a * (s.q1 - s.q0)
    def _tick(s):
        if s.grip_event and s.clk.t >= s.grip_event[0]:
            s.gripper = s.grip_event[1]; s.grip_event = None
    def executing(s): s._tick(); return s.clk.t < s.busy_until
    # ---- toolbox API stand-ins
    def readJointConfiguration(s): return s.q()
    def readCartesianPose(s): return pose_of(s.q())
    def readMotionStatus(s): return 'Executing' if s.executing() else 'Succeeded'
    def sendJointConfigurationAndWait(s, q, EndTime):
        tsend = s.clk.t
        if not s.playing or s.executing():
            s.dropped.append((round(tsend, 2), 'move')); s.clk.t += EndTime + 5; return False
        s.q0 = s.q(); s.q1 = np.array(q, float); s.t0 = tsend + 0.05; s.dur = EndTime / s.slider
        s.busy_until = s.t0 + s.dur + 0.15                       # server returns from movej a little after arrival
        s.log.append(('move', round(tsend, 2), np.round(np.rad2deg(q), 2)))
        s.paths.append((s.q0.copy(), s.q1.copy()))
        if s.dur + 0.2 <= EndTime + 5: s.clk.t = s.busy_until; return True
        s.clk.t = tsend + EndTime + 5; return False               # library gives up at EndTime + 5 s
    def actuateGripper(s, action):
        s.clk.t += 0.01
        if not s.playing or s.executing(): s.dropped.append((round(s.clk.t, 2), action)); return
        if s.lastGrip == action: return                           # server only acts on a change of command
        s.lastGrip = action; s.busy_until = s.clk.t + 0.05 + 1.7
        s.grip_event = (s.clk.t + 1.5, 'closed' if action == 'grip' else 'open'); s.log.append((action, round(s.clk.t, 2)))
    def tip(s, q=None):
        T = fk(s.q() if q is None else q); return T[:3, 3] + T[:3, 2] * GRIP
