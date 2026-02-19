This small repository contains a template for scripts facilitating coloring
in [VMD](https://www.ks.uiuc.edu/Research/vmd/), which changes during a
trajectory. The method presented here is based on storing the per-atom,
per-frame data in `.npy` files, which are easily written using `np.save`
from python, and then subsequently loading it into the `User` field in VMD.

In this repo, you can find:

- `loader.tcl` - the `.npy` parser and VMD loading helper in pure Tcl for
  portability
- `vis.vmd` - customizable template for your own VMD visualizations,
  featuring discrete color categories and QoL enhancements.
- `write.py` - a minimal example for writing custom `.npy` files
- `out.gro`, `out.xtc`, `data.npy` - dummy data, so you can run
  `vmd -e vis.vmd` immediately after git cloning.

# How to use

Short version: download `loader.tcl` and `vis.vmd`, modify `vis.vmd` to your
liking.

Long version:

This section assumes per-frame, per-atom data of dimension (n_frames, n_atoms)
of dtype (u)int{8,16,32,64} and float{32,64} has been written to a `.npy` file.

First, load the library in VMD, making the commands it defines available.
Assuming `loader.tcl` has been downloaded into the current directory:

```tcl
source "loader.tcl"
```

Second, load the molecule. Note, this can also be done through the GUI or
through the CLI args. Do take care to remove the extra frame that can be
present in some situations, e.g. when loading a trajectory from a `.xtc`
file, and the topology from a `.gro` file.

```tcl
mol new "system.gro"
mol addfile "traj.xtc" waitfor all
# delete first frame for moleculeID 0
animate delete beg 0 end 0 skip 0 0
```

Third, load the per-frame, per-atom data.

```tcl
set data [load_npy "data.npy"]
```

Fourth, save the data into the "User" field.

```tcl
# which molecule/atoms to color
set sel [atomselect top all]
# args: selection, field, data
trajectory_set $sel user $data

# we don't need sel anymore
$sel delete
```

Fifth, set up VMD to dynamically update coloring based on the User field.
Two options are possible:

- For discrete categorical coloring, create a separate representation for
  each category, colored based on a colorID, and check "update selection every
  frame" for the representations. `vis.vmd` contains the script for this setup,
  since doing this through the GUI would be too much work. This
  setup is used for visualizing e.g. [MDVoxelSegmentation](https://github.com/marrink-lab/MDVoxelSegmentation).
- For continuous scalar coloring, or with discrete categorical coloring with
  not many distinct categories, select "User" as the coloring mode, select
  "Update color every frame", specify the desired range and select the preferred
  color palette in the second tab of the color menu.

# Limitations

From most to least relevant.

- Tcl is used as it is the most portable across VMD installations. Python can be
  unavailable inside VMD under some settings. This has slight performance
  implications.
- `.npy` files are easy to read/write, but they do not feature compression. For
  long-term data storage, they are not ideal.
- Tcl 8.x used in VMD only supports strings up to 2 GB. `loader.npy` loads
  data in chunks per frame. In practice, this means
  that data for a single frame should be below 2 GB.
- Tcl's `binary scan` seems to not support unsigned integers, so those are
  loaded as signed integers to provide compatibility in many cases when
  no number is large enough in the dataset to have the most significant bit
  set to `1`.
- The `.npy` reader in `loader.tcl` is pragmatic, meaning it can only read a
  subset of valid `.npy` files. Only explicitly little endian `.npy` files
  are supported. More than 2 dimensional `.npy` files are
  not supported.
