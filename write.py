#!/usr/bin/env python3

import numpy as np
import mdtraj as md

t = md.load("out.xtc", top="out.gro")

xyz = t.xyz

n_frames, n_atoms, _ = xyz.shape

data = np.zeros((n_frames, n_atoms), dtype=np.int8)

for i, frame in enumerate(xyz):
    for j, atom in enumerate(frame):
        # dummy data based on the x coordinate of the atom
        data[i, j] = atom[0] / 0.5

np.save("data.npy", data)
