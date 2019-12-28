#!/usr/bin/tclsh
#-------------------------------------------------------------------------
# ypostproc --- post-process a mapped .blif file generated by yosys
#
# Note that this file handles mapped blif files ONLY.  The only statements
# allowed in the file are ".model", ".inputs", ".outputs", ".latch",
# ".gate" (or ".subckt"), and ".end".
#
# Lines using "$false" or "$true" are replaced with the net names for
# power and ground buses in the tech script (to be expanded to handle
# TIEHI and TIELO cells, if available in the standard cell set)
#
#-------------------------------------------------------------------------
# Written by Tim Edwards October 8-9, 2013
# Open Circuit Design
# Modified for yosys, October 24, 2013
#-------------------------------------------------------------------------


#
# Note: variables from ${techdir}/${techname}.sh are available!
#


if [catch {open yosys-out.blif r} bnet] {
   puts stderr "Error: can't open file yosys-out.blif for reading!"
   exit 1
}

if [catch {open postproc-out.blif w} onet] {
   puts stderr "Error: can't open file postproc-out.blif for writing!"
   exit 1
}

#-------------------------------------------------------------
# Yosys first pass of the blif file
# Look for all ".names x y" records and remember y as an
# alias for x.
#-------------------------------------------------------------

while {[gets $bnet line] >= 0} {
   set line [string map {\[ \< \] \>} $line]
   if [regexp {^.names[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]*$} $line lmatch signame sigalias] {
      # Technically, should check if the next line is "1 1" but I don't think there are
      # any exceptions in yosys output.
      if [catch {set ${signame}(alias)}] {
	 set ${signame}(alias) {}
      }
      lappend ${signame}(alias) $sigalias
   }
}
seek $bnet 0

#-------------------------------------------------------------
# Now post-process the blif file
# The main thing to remember is that internal signals will be
# outputs of flops, but external pin names have to be translated
# to their internal names by looking at the OUTPUT section.
#-------------------------------------------------------------

set cycle 0
while {[gets $bnet line] >= 0} {
   set line [string map {\[ \< \] \> \.subckt \.gate} $line]
   if [regexp {^.gate} $line lmatch] {
      break
   } elseif [regexp {^.names} $line lmatch] {
      break
   } elseif [regexp {^.latch} $line lmatch] {
      break
   }
   puts $onet $line
}

# Replace all .latch statements with .gate, with the appropriate gate type and pins,
# and copy all .gate statements as-is.

while {1} {

   # All lines starting with ".names" are converted into buffers.  These should be
   # pruned. . . 

   if [regexp {^.names} $line lmatch] {
      if {[regexp {\$true$} $line lmatch]} {
         set line [string map [subst {\\\$false $gndnet \\\$true $vddnet}] $line]
	 if [regexp {^.names[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]*$} $line lmatch sigin sigout] {
	    puts $onet ".gate BUFX2 A=${sigin} Y=${sigout}"
         }
         gets $bnet line
      }
   } else {
      set line [string map [subst {\\\$false $gndnet \\\$true $vddnet}] $line]
      puts $onet $line
   }
   if [regexp {^.end} $line lmatch] break

   if {[gets $bnet line] < 0} break
   set line [string map {\[ \< \] \> \.subckt \.gate} $line]
}

close $bnet
