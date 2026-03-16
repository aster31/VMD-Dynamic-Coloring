# Copyright (c) 2026 University of Groningen
# Authors: Aster Kovacs

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

proc hsl_to_rgb { hue saturation light } {
	set C [expr {(1.-abs(2*$light-1.))*$saturation}]
	set X [expr {$C*(1.-abs(fmod($hue/60., 2.)-1.))}]
	set m [expr {$light-$C/2.}]
	if {$hue < 60.} {
		set sR $C
		set sG $X
		set sB 0.
	} elseif {$hue < 120.} {
		set sR $X
		set sG $C
		set sB 0.
	} elseif {$hue < 180.} {
		set sR 0.
		set sG $C
		set sB $X
	} elseif {$hue < 240.} {
		set sR 0.
		set sG $X
		set sB $C
	} elseif {$hue < 300.} {
		set sR $X
		set sG 0.
		set sB $C
	} else {
		set sR $C
		set sG 0.
		set sB $X
	}
	set R [expr {$sR+$m}]
	set G [expr {$sG+$m}]
	set B [expr {$sB+$m}]

	return [list $R $G $B]	
}

proc gen_ramp { hStart hCycles minLight maxLight lCycles minSat maxSat sCycles n } {
	# HSV sampling
	set l_len [expr {$n/$lCycles}]
	set s_len [expr {$n/$sCycles}]

	# HSV to RGB
	set rgb [list]

	for {set i 0} {$i < $n} {incr i} {
		# calc HSL from sampling
		set hue [expr {fmod($hStart+$i*$hCycles*360./$n, 360.)}]
		set saturation [expr {$minSat+fmod($i, $s_len)*($maxSat-$minSat)/$s_len}]
		set light [expr {$minLight+fmod($i, $l_len)*($maxLight-$minLight)/$l_len}]

		lappend rgb [hsl_to_rgb $hue $saturation $light]
	}

	return $rgb
}

proc vmd_set_colors { from to ramp } {
	set n [expr {$to-$from}]
	if {[llength $ramp] != $n} {
		puts {$ramp length does not match $to-$from. $to is not inclusive! incorrect $n for ramp?}
		return
	}
	for {set i 0} {$i < $n} {incr i} {
		set colorID [expr {$i+$from}]
		set rgb [lindex $ramp $i]
		set R [lindex $rgb 0]
		set G [lindex $rgb 1]
		set B [lindex $rgb 2]
		color change rgb $colorID $R $G $B
	}
}

proc nice_colors { } {
	set ramp [
		gen_ramp 254.6 1.4 0.8 0.09 1. 0.4 0.93 1. 16
	]
	vmd_set_colors 0 16 $ramp
}

proc discrete_ramp {} {
	set ramp [
		gen_ramp 250. 113.77 0.6 0.3 146.3 0.1 0.9 60.2 1024
	]
	vmd_set_colors [colorinfo num] [expr {[colorinfo num]+1024}] $ramp
}
