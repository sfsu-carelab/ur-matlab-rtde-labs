"""Does the policy see the block from this camera placement?
usage: python -I octo_erase_test.py <frame.png> <x0> <y0> <w> <h> [N]
Crops [x0 y0 w h] (MATLAB 1-based, as in UR_VLA_Octo_Prototype primary_crop), finds the red
block, pastes sheet over it, and samples the policy N times (seeds 0..N-1) for: block present,
block erased, wrong colour word. If the per-seed sign patterns are identical with the block
erased, the policy is not looking at the block.
"""
import sys
import numpy as np
sys.path.insert(0, r"C:\Users\924414657\vla-octo\vlapy")
from PIL import Image
import octoChunk

f = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.uint8)
x0, y0, w, h = [int(v) for v in sys.argv[2:6]]
N = int(sys.argv[6]) if len(sys.argv) > 6 else 8
img = f[y0 - 1:y0 - 1 + h, x0 - 1:x0 - 1 + w].copy()
red = (img[:, :, 0].astype(int) > 140) & (img[:, :, 1].astype(int) < 100) & (img[:, :, 2].astype(int) < 100)
ys, xs = np.where(red)
if red.sum() < 50:
    sys.exit("no red block found in the crop")
by0, by1, bx0, bx1 = max(ys.min() - 10, 0), ys.max() + 10, max(xs.min() - 10, 0), xs.max() + 10
print("red block bbox in crop: x %d..%d  y %d..%d  (%d px); crop is %dx%d" % (bx0, bx1, by0, by1, red.sum(), w, h))
noblock = img.copy()
src_y = by1 + 20 if by1 + 20 + (by1 - by0) <= h else by0 - 20 - (by1 - by0)
noblock[by0:by1, bx0:bx1] = img[src_y:src_y + (by1 - by0), bx0:bx1]
Image.fromarray(noblock).save(sys.argv[1][:-4] + "_noblock.png")
tests = [("block present, pick up the red block ", img, "pick up the red block"),
         ("block ERASED,  pick up the red block ", noblock, "pick up the red block"),
         ("block present, pick up the teal block", img, "pick up the teal block")]
for name, im, task in tests:
    rows = []
    for i in range(N):
        p = octoChunk.OctoChunkInference(init_rng=i)
        a = p.step_chunk(im, task)
        rows.append(np.concatenate([a["world_vector"].sum(axis=0) * 1000, [a["gripper"].min()]]))
    rows = np.array(rows)
    m, s = rows.mean(axis=0), rows.std(axis=0)
    print("%s  dx %+6.1f +- %4.1f   dy %+6.1f +- %4.1f   dz %+6.1f +- %4.1f mm   closes in %d/%d   dy signs %s"
          % (name, m[0], s[0], m[1], s[1], m[2], s[2], int((rows[:, 3] < 0).sum()), N,
             "".join("+" if r[1] > 0 else "-" for r in rows)))
