"""
OctoChunkInference: OctoInference (MathWorks vlapy wrapper, from SimplerEnv) plus one method,
step_chunk, that returns the WHOLE predicted action chunk (pred_action_horizon steps, 4 for
octo-base) instead of one temporally ensembled step. Used by UR_VLA_Octo_Prototype.m to
execute a chunk as one blended multi-waypoint move and re-observe afterwards.

Added 2026-11-19 for the SFSU UR3e labs. octoModel.py itself is untouched.
"""
from collections import deque

import jax
import numpy as np
import tensorflow as tf
from transforms3d.euler import euler2axangle

from octoModel import OctoInference


WRIST_IMAGE_SIZE = 128   # octo-base config: frame_transform resize_size wrist [128, 128]


class OctoChunkInference(OctoInference):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.wrist_history = deque(maxlen=self.horizon)

    def reset(self, task_description: str) -> None:
        super().reset(task_description)
        self.wrist_history.clear()

    def _resize_wrist(self, image: np.ndarray) -> np.ndarray:
        image = tf.image.resize(image, size=(WRIST_IMAGE_SIZE, WRIST_IMAGE_SIZE), method="lanczos3", antialias=True)
        return tf.cast(tf.clip_by_value(tf.round(image), 0, 255), tf.uint8).numpy()

    def step_chunk(self, image: np.ndarray, task_description=None, wrist_image=None) -> dict:
        """Same observation handling as step(); returns every step of the predicted chunk.

        image        uint8 (H, W, 3), the fixed third-person camera -> image_primary (256x256)
        wrist_image  uint8 (H, W, 3) or None, the camera behind the gripper -> image_wrist
                     (128x128). octo-base was pretrained with both tokenizers; without a
                     wrist image the wrist tokenizer is skipped (the "Skipping observation
                     tokenizer: obs_wrist" warning). Give it on every step or on none.

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
        if wrist_image is not None:
            assert wrist_image.dtype == np.uint8
            self.wrist_history.append(self._resize_wrist(wrist_image))
            if len(self.wrist_history) != len(self.image_history):
                raise ValueError("wrist_image must be given on every step of an episode, or on none")
            obs["image_wrist"] = np.stack(self.wrist_history, axis=0)[None]
        elif len(self.wrist_history) > 0:
            raise ValueError("this episode started with a wrist image; give one on every step")
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
