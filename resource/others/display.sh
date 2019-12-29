#!/usr/bin/tcsh -f
#----------------------------------------------------------
# Qflow layout display script using magic-8.0
#----------------------------------------------------------
# Tim Edwards, April 2013
#----------------------------------------------------------

# Usage:  display.sh [options] <project_path> <source_name>

set projectpath=$argv1
set sourcename=$argv2
set rootname=${sourcename:h}

source ${projectpath}/qflow_vars.sh
source ${techdir}/${techname}.sh
cd ${projectpath}
source project_vars.sh



set lefpath=techdir/osu050_stdcells.lef
cp techdir/osu050.magicrc ${layoutdir}/.magicrc
cd ${layoutdir}

#---------------------------------------------------
# Create magic layout (.mag file) using the
# technology LEF file to determine route widths
# and other parameters.
#---------------------------------------------------


# The following script reads in the DEF file and modifies labels so
# that they are rotated outward from the cell, since DEF files don't
# indicate label geometry.

${bindir}/magic -dnull -noconsole <<EOF
drc off
box 0 0 0 0
snap int
lef read ${lefpath}
def read ${rootname}
select top cell
select area labels
setlabel font FreeSans
setlabel size 0.3um
box grow s -[box height]
box grow s 100
select area labels
setlabel rotate 90
setlabel just e
select top cell
box height 100
select area labels
setlabel rotate 270
setlabel just w
select top cell
box width 100
select area labels
setlabel just w
select top cell
box grow w -[box width]
box grow w 100
select area labels
setlabel just e
save ${sourcename}
quit -noprompt
EOF

# Create a script file for loading and displaying the
# layout.

set dispfile="${layoutdir}/load_${rootname}.tcl"
if ( ! -f ${dispfile} ) then
cat > ${dispfile} << EOF
lef read ${lefpath}
load ${sourcename}
select top cell
expand
EOF
endif





# For magic versions less than 8.1.102, only the .mag file can be loaded from the command line.  Otherwise, run the script.
# TODO: I have magic 8.0 rev 210

if ( version less than 8.1.102 ) then
   set dispfile = ${sourcename}
endif

# Run magic again, this time interactively.  The script
# exits when the user exits magic.

${bindir}/magic -d X11 ${dispfile}
