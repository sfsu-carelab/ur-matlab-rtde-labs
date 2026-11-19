"""
OctoChunkInference: OctoInference (MathWorks vlapy wrapper, from SimplerEnv) plus one method,
step_chunk, that returns the WHOLE predicted action chunk (pred_action_horizon steps, 4 for
octo-base) instead of one temporally ensembled step. Used by UR_VLA_Octo_Prototype.m to
execute a chunk as one blended multi-waypoint move and re-observe afterwards.

Added 2026-11-19 for the SFSU UR3e labs. octoModel.py itself is untouched.
"""
import jax
import numpy as np
from transforms3d.euler import euler2axangle

from octoModel import OctoInference


class OctoChunkInference(OctoInference):
    def step_chunk(self, image: np.ndarray, task_description=None) -> dict:
        """Same observation handling as step(); returns every step of the predicted chunk.

        Returns a dict of numpy arrays, H = pred_action_horizon:
            'world_vector' (H, 3)  xyz translation delta per step [m]
            'rot_axangle'  (H, 3)  axis-angle rotation delta per step [rad]
            'gripper'      (H,)    +1 open, -1 close (binarized at 0.5 like widowx_bridge)
            'raw'          (H, 7)  denormalized raw actions
        The action ensembler is not used (and not updated), so alternating step() and
        step_chunk() on one object is not meaningful; use one or the other.
        """
        if task_description is not None and task_description != self.task_description:
            self.reset(task_description)
        assert image.dtype == np.uint8
        image = self._resize_image(image)
        self._add_image_to_history(image)
        images, pad_mask = self._obtain_image_history_and_mask()
        images, pad_mask = images[None], pad_mask[None]
        self.rng, key = jax.random.split(self.rng)
        if not self.automatic_task_creation:
            raise NotImplementedError("step_chunk supports the octo-base / octo-small checkpoints only")
        obs = {"image_primary": images, "timestep_pad_mask": pad_mask}
        norm = np.asarray(self.model.sample_actions(obs, self.task, rng=key))[0]   # (H, 7)
        assert norm.shape == (self.pred_action_horizon, 7)
        raw = norm * self.action_std[None] + self.action_mean[None]
        H = raw.shape[0]
        world = raw[:, :3] * self.action_scale
        rot = np.zeros((H, 3))
        for i in range(H):
            roll, pitch, yaw = np.asarray(raw[i, 3:6], dtype=np.float64)
            ax, ang = euler2axangle(roll, pitch, yaw)
            rot[i] = ax * ang * self.action_scale
        gripper = 2.0 * (raw[:, 6] > 0.5) - 1.0
        return {"world_vector": world, "rot_axangle": rot, "gripper": gripper, "raw": raw}
