This small repository contains a template for scripts facilitating coloring
in [VMD](https://www.ks.uiuc.edu/Research/vmd/), which changes during a
trajectory. The method presented here is based on storing the per-atom,
per-frame data in `.npy` files, which are easily written using `np.save`
from python, and then subsequently loading it into the `User` field in VMD.

In this repo, you can find:

- `loader.tcl` - The `.npy` parser and VMD loading helper in pure Tcl for
  portability
- `vis.vmd` - Customizable template for your own VMD visualizations.
- `write.py` - A minimal example for writing custom `.npy` files.
- `out.gro`, `out.xtc`, `data.npy` - Dummy data, so you can run
  `vmd -e vis.vmd` immediately after git cloning.

# Pre-requisites

**1. Data in .npy format**

It is assumed that per-frame, per-atom data of dimension (n_frames, n_atoms)
of dtype (u)int{8,16,32,64} and float{32,64} has been written to a `.npy` file
using Numpy's `np.save` function.

**2. Loading the molecule**

Note, this can also be done through the GUI or
through the CLI args. Do take care to **remove the extra frame** that can be
present in some situations, e.g. when loading a trajectory from a `.xtc`
file, and the topology **from a `.gro` file**. The data should match the
trajectory frames! This should be done before calling `load_into_user`.

```tcl
mol new "system.gro"
mol addfile "traj.xtc" waitfor all
# delete first frame for moleculeID 0
animate delete beg 0 end 0 skip 0 0
```

# How to use?

Clone the repository, and check out `vis -e vis.vmd` as an example.

For your own visualizations, put `loader.tcl` in the same folder, then load it
with `source "loader.tcl"`, then use the helper command:

```tcl
source "loader.tcl"
load_into_user "data.npy"
```

Load into user takes the molecule ID and representation ID as optional
arguments. 0 is default for both.

This will automatically load the data in "data.npy" into the user field
for the molecule, and set up the picked representation to color based
on the user field dynamically, using a discrete categories color ramp.

Read on for advanced features and limitations.

# Reference

**Loading a .npy array into a variable**

```tcl
set data [load_npy "data.npy"]
```

**Using custom selections.**

```tcl
set data [load_npy "data.npy"]
# which molecule/atoms to color
set sel [atomselect top all]
# Note: this is a helper defined in loader.tcl.
# args: selection, field, data
trajectory_set $sel user $data

# we don't need sel anymore
$sel delete
```

**Automatically update selections and colors every frame**

This can also be checked through the GUI, or through the commands below.
One makes sure selections based on User get re-evaluated every frame. The
other makes sure the color ramp values get updated based on User every frame.

```tcl
# tell VMD to update the coloring and selection every frame
mol selupdate 0 0 1
mol colupdate 0 0 1
```

**Customize the color palette**

For continuous data, feel free to use one of the built-in palettes.

For discrete data, there is a helper for making your own palettes
loosely inspired by [rampensau](https://meodai.github.io/rampensau/).


```tcl
# Note: this is also already defined in loader.tcl. 

proc discrete_ramp {} {
	set ramp [
		gen_ramp {
      # hue of index 0
			hStart 238.7
      # how many elements until hue cycles
			hLen 2.7
      # saturation min/max
			minSat 0.9
			maxSat 0.2
      # how many elements until saturation cycles
			sLen 9.5
      # light min/max
			minLight 0.8
			maxLight 0.35
      # how many elements until light cycles
			lLen 11.5
			n 1024
		}
	]
  # this is a helper for setting a list of colors at once
	vmd_set_colors [colorinfo num] [expr {[colorinfo num]+1024}] $ramp
}

discrete_ramp

# if using the discrete coloring, the ramp has 1024 discrete colors, and we
# want the integer numbers in the User field to map to neighboring colors
# for some extra visual harmony
mol scaleminmax 0 0 0 1023
```

# Limitations

- Tcl is used, as it is the most portable across VMD installations.
  Python can be unavailable inside VMD, depending on how it was compiled.
  This has slight performance implications.
- `.npy` files are easy to read/write, but they do not feature compression. For
  long-term data storage, they are not ideal.
- Tcl version 8.x, which is used in VMD, only supports strings up to 2 GB.
  `loader.npy` loads data in chunks per frame. In practice, this means
  that data for a single frame should be below 2 GB.
- Tcl's `binary scan` does not support unsigned integers, so those are
  loaded as signed integers to provide compatibility.
  When no number is large enough in the dataset to have the most significant
  bit set to `1`, this works well.
- The `.npy` reader in `loader.tcl` is pragmatic, meaning it can only read a
  subset of valid `.npy` files. Only explicitly little endian `.npy` files
  are supported. More than 2 dimensional `.npy` files are
  not supported.
