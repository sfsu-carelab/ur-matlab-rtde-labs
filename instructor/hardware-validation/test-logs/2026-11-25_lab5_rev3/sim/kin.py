import numpy as np
D = [0.15185, 0, 0, 0.13105, 0.08535, 0.0921]
A = [0, -0.24355, -0.2132, 0, 0, 0]
AL = [np.pi/2, 0, 0, np.pi/2, -np.pi/2, 0]
def dh(th, d, a, al):
    c, s, ca, sa = np.cos(th), np.sin(th), np.cos(al), np.sin(al)
    return np.array([[c, -s*ca, s*sa, a*c], [s, c*ca, -c*sa, a*s], [0, sa, ca, d], [0, 0, 0, 1]])
def fk(q, all_frames=False):
    T = np.eye(4); out = [T.copy()]
    for i in range(6):
        T = T @ dh(q[i], D[i], A[i], AL[i]); out.append(T.copy())
    return out if all_frames else T
def eul_zyx(R):
    return np.array([np.arctan2(R[1,0], R[0,0]), np.arcsin(-R[2,0]), np.arctan2(R[2,1], R[2,2])])
def eul2R(e):
    z, y, x = e
    Rz = np.array([[np.cos(z), -np.sin(z), 0], [np.sin(z), np.cos(z), 0], [0, 0, 1]])
    Ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
    Rx = np.array([[1, 0, 0], [0, np.cos(x), -np.sin(x)], [0, np.sin(x), np.cos(x)]])
    return Rz @ Ry @ Rx
def pose_of(q):
    T = fk(q); return np.r_[eul_zyx(T[:3,:3]), T[:3,3]]
def pose2T(p):
    T = np.eye(4); T[:3,:3] = eul2R(p[:3]); T[:3,3] = p[3:]; return T
def rotvec(R):
    c = (np.trace(R) - 1) / 2; ang = np.arccos(np.clip(c, -1, 1))
    if ang < 1e-9: return np.zeros(3)
    ax = np.array([R[2,1]-R[1,2], R[0,2]-R[2,0], R[1,0]-R[0,1]]) / (2*np.sin(ang))
    return ax * ang
def jac(q, eps=1e-6):
    T0 = fk(q); J = np.zeros((6, 6))
    for i in range(6):
        dq = np.array(q, float); dq[i] += eps; T1 = fk(dq)
        J[:3, i] = (T1[:3,3] - T0[:3,3]) / eps
        J[3:, i] = rotvec(T1[:3,:3] @ T0[:3,:3].T) / eps
    return J
def ik_step(Tt, q0, iters=200):
    """Seeded damped least squares, no restarts (stand-in for inverseKinematics, AllowRandomRestart=false)."""
    q = np.array(q0, float)
    for _ in range(iters):
        T = fk(q)
        e = np.r_[Tt[:3,3] - T[:3,3], rotvec(Tt[:3,:3] @ T[:3,:3].T)]
        if np.linalg.norm(e) < 1e-10: break
        J = jac(q); lam = 1e-4
        dq = J.T @ np.linalg.solve(J @ J.T + lam*np.eye(6), e)
        n = np.linalg.norm(dq)
        if n > 0.5: dq *= 0.5 / n
        q = q + dq
    T = fk(q)
    err = np.linalg.norm(np.r_[Tt[:3,3] - T[:3,3], rotvec(Tt[:3,:3] @ T[:3,:3].T)])
    return q, err
if __name__ == '__main__':
    hw = [([19.53,-133.03,-84.9,-50.49,89.35,179.6],[1.9184,0.0115,3.1140,0.4421,0.0167,0.1092]),
          ([-0.08,-125.98,-98.96,-45.8,88.83,167.34],[1.7905,0.0170,-3.1245,0.3779,-0.1335,0.1051]),
          ([2.83,-174.1,-2.29,-91.89,85.61,184.98],[1.5308,0.0737,3.1050,0.5493,-0.1112,0.1010]),
          ([25.15,-138.03,-76.48,-55.71,87.5,215.74],[1.3858,0.0376,3.1192,0.4573,0.0655,0.1016]),
          ([17.61,-119.12,-96.06,-54.27,87.78,196.05],[1.5975,0.0345,3.1215,0.4020,-0.0136,0.1506])]
    np.set_printoptions(precision=4, suppress=True)
    for q, p in hw:
        print(pose_of(np.deg2rad(q)), p)
