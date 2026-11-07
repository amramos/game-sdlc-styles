"""Find the membrane triangles image-to-3D stretched between the windmill's sail tips: in the sail
plane, with vertices on two neighbouring sail arms (a spar joins opposite arms, so it stays)."""
import numpy as np
def membrane(P, T, hub=(0.0, 0.133)):
    V = P[T]
    ang = np.degrees(np.arctan2(V[:, :, 1] - hub[1], V[:, :, 0] - hub[0]))
    arm = np.floor((ang % 360) / 90).astype(int)          # arms sit at 45, 135, 225, 315 degrees
    r = np.hypot(V[:, :, 0] - hub[0], V[:, :, 1] - hub[1])
    adj = np.zeros(len(T), bool)
    for a, b in [(0, 1), (1, 2), (0, 2)]:
        d = (arm[:, a] - arm[:, b]) % 4
        adj |= (d == 1) | (d == 3)
    return adj & (r.min(1) > 0.08) & (V[:, :, 2].min(1) > 0.1) & (V[:, :, 1].min(1) > -0.25)
