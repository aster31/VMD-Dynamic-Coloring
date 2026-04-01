# Copyright (c) 2026 University of Groningen
# Authors: Aster Kovacs, Bart Bruininks

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

proc load_npy { path } {
	## Pragmatic loader for .npy files
	## supports integers/floats that are 4/8 byte and 1D or 2D arrays
	## for 2D arrays: tries to read the file in chunks to avoid hitting the 2GB limit

	# Open file
	set fd [open $path r]
	fconfigure $fd -translation binary

	binary scan [read $fd 8] "a6cc" magic major minor

	if {$magic != "\x93NUMPY"} {
		error "File $path is not a valid NUMPY file."
	}

	# Check version number
	# v1 - 2 byte header length
	# v2< - 4 byte header length
	if {$major < 2} {
		binary scan [read $fd 2] "s" header_length
	} else {
		binary scan [read $fd 4] "i" header_length
	}

	# parse header
	set header [read $fd $header_length]

	# find data type in a pragmatic way
	if {![regexp -indices {'descr':[ ]*'} $header descr_loc]} {
		error "Header contained no 'descr', is your .npy correct?"
	}

	set descr_start [lindex $descr_loc 1]

	if {![regexp -start $descr_start {[<|][uif][1248]} $header format]} {
		error "Only integers of 8/16/32/64 bits or floats of 32/64 bits supported." 
	}

	# note: this is only incorrect for:
	# - unsigned u4+values above 2**31
	# - unsigned u8+values above 2**63
	# ==> this is likely to be correct for most data files
	# Tcl has no efficient way of doing unsigned binary scans
	if {$format == "<u4" || $format == "<i4"} {
		set scan_format "i*"
		set chunk_len 4
	} elseif {$format == "<u8" || $format == "<i8"} {
		set scan_format "w*"
		set chunk_len 8
	} elseif {$format == "<u2" || $format == "<i2"} {
		set scan_format "s*"
		set chunk_len 2
	} elseif {$format == "|u1" || $format == "|i1"} {
		set scan_format "c*"
		set chunk_len 1
	} elseif {$format == "<f4"} {
		set scan_format "f*"
		set chunk_len 4
	} elseif {$format == "<f8"} {
		set scan_format "d*"
		set chunk_len 8
	} else {
		# f2 or f1
		error "Only integers of 8/16/32/64 bits or floats of 32/64 bits supported." 
	}

	# find dimensions in a pragmatic way
	if {![regexp -indices {'shape':[ ]*\(} $header shape_loc]} {
		error "Header contained no 'shape', is your .npy correct?"
	}

	set shape_start [expr {[lindex $shape_loc 1] + 1}]
	if {[regexp -start $shape_start {\A[0-9]+[, ]*\)} $header dim]} {
		regexp {[0-9]+} $dim dim
		# 1D
		binary scan [read $fd] $scan_format result
		close $fd
		if {[llength $result] != $dim} {
			error ".npy shape incorrect. Got ([llength $result],), expect ($dim,)."
		}
		return $result
	} elseif {[regexp -start $shape_start {\A[0-9]+,[ ]*[0-9]+\)} $header dims]} {
		# 2D
		regexp -indices {[0-9]+} $dims dim1_ind
		set dim1 [string range $dims [lindex $dim1_ind 0] [lindex $dim1_ind 1]]
		regexp -start [expr {[lindex $dim1_ind 1] + 1}] {[0-9]+} $dims dim2

		set chunk_len [expr {$chunk_len * $dim2}]
		set result [list]

		for {set i 0} {$i < $dim1} {incr i} {
			binary scan [read $fd $chunk_len] $scan_format chunk
			lappend result $chunk
		}

		set rem [llength [read $fd]]
		if {$rem > 0} {
			error ".npy shape incorrect. Got shape ($dim1, $dim2). Number of remaining bytes not read: $rem."
		}
		
		close $fd
		return $result
	} else {
		close $fd
		error "Only 1D or 2D arrays are supported."
	}
}

proc trajectory_set { sel field data } {
	set n_frames [llength $data]; list

	for {set i 0} {$i < $n_frames} {incr i} {
		$sel frame $i
		$sel set $field [lindex $data $i]
	}
}

proc hsl_to_rgb { hue saturation light } {
	set C [expr {(1.-abs(2*$light-1.))*$saturation}]
	set X [expr {$C*(1.-abs(fmod($hue/60., 2.)-1.))}]
	set m [expr {$light-$C/2.}]
	if {$hue < 60.} {
		set R $C
		set G $X
		set B 0.
	} elseif {$hue < 120.} {
		set R $X
		set G $C
		set B 0.
	} elseif {$hue < 180.} {
		set R 0.
		set G $C
		set B $X
	} elseif {$hue < 240.} {
		set R 0.
		set G $X
		set B $C
	} elseif {$hue < 300.} {
		set R $X
		set G 0.
		set B $C
	} else {
		set R $C
		set G 0.
		set B $X
	}
	set R [expr {$R+$m}]
	set G [expr {$G+$m}]
	set B [expr {$B+$m}]

	return [list $R $G $B]	
}

proc get_or { dict key default } {
	if {[dict exists $dict $key]} {
		return [dict get $dict $key]
	} else {
		return $default
	}
}

proc gen_ramp { kwargs } {

	set valid_args {
		n 1
		hStart 1
		hLen 1
		hCycles 1
		minSat 1
		maxSat 1
		minLight 1
		maxLight 1
		hMap 1
		sMap 1
		lMap 1
		lCycles 1
		lLen 1
		sCycles 1
		sLen 1
	}

	dict for {key val} $kwargs {
		if {![dict exists $valid_args $key]} {
			error "Invalid argument to gen_ramp: $key."
		}
	}

	set n [get_or $kwargs n 8 ]
	set hStart [get_or $kwargs hStart 0. ]
	set sat_end [get_or $kwargs minSat 1. ]
	set sat_start [get_or $kwargs maxSat 0. ]
	set light_end [get_or $kwargs minLight 1. ]
	set light_start [get_or $kwargs maxLight 0. ]
	set hue_map [get_or $kwargs hMap {$x}]
	set sat_map [get_or $kwargs sMap {$x}]
	set light_map [get_or $kwargs lMap {$x}]


	if {[dict exists $kwargs hCycles]} {
		set h_len [expr {$n/[dict get $kwargs hCycles]}]
	} elseif {[dict exists $kwargs hLen]} {
		set h_len [dict get $kwargs hLen]
	} else {
		set h_len $n
	}

	
	if {[dict exists $kwargs lCycles]} {
		set l_len [expr {$n/[dict get $kwargs lCycles]}]
	} elseif {[dict exists $kwargs lLen]} {
		set l_len [dict get $kwargs lLen]
	} else {
		set l_len $n
	}
	if {[dict exists $kwargs sCycles]} {
		set s_len [expr {$n/[dict get $kwargs sCycles]}]
	} elseif {[dict exists $kwargs sLen]} {
		set s_len [dict get $kwargs sLen]
	} else {
		set s_len $n
	}

	set rgb [list]

	for {set i 0} {$i < $n} {incr i} {
		# calc HSL from sampling
		set x [expr {fmod($hStart+$i*360./$h_len, 360.)}]
		set hue [expr $hue_map]
		set x [expr {$sat_start+fmod($i, $s_len)*($sat_end-$sat_start)/($s_len-1)}]
		set saturation [expr $sat_map]
		set x [expr {$light_start+fmod($i, $l_len)*($light_end-$light_start)/($l_len-1)}]
		set light [expr $light_map]

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

proc discrete_ramp {} {
	set ramp [
		gen_ramp {
			hStart 348.7
			hLen 2.73
			minSat 0.9
			maxSat 0.3
			sLen 9.52
			minLight 0.75
			maxLight 0.35
			lLen 6.44
			n 1024
		}
	]
	vmd_set_colors [colorinfo num] [expr {[colorinfo num]+1024}] $ramp
}

proc load_into_user { data_path { molID 0 } { repID 0 } } {
	set data [load_npy $data_path]
	set sel [atomselect $molID all]
	trajectory_set $sel user $data
	$sel delete
	mol modcolor $repID $molID User
	mol selupdate $repID $molID 1
	mol colupdate $repID $molID 1
	discrete_ramp
	mol scaleminmax $repID $molID 0 1023
}
