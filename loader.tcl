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

	set shape_start [expr [lindex $shape_loc 1] + 1]
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
		regexp -start [expr [lindex $dim1_ind 1] + 1] {[0-9]+} $dims dim2

		set chunk_len [expr $chunk_len * $dim2]
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
