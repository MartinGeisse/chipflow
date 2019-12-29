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


# Timestamp handling:  If the .mag file is more recent
# than the .def file, then print a message and do not
# overwrite.

set docreate=1
if ( -f ${rootname}.def && -f ${rootname}.mag) then
   set defstamp=`stat --format="%Y" ${rootname}.def`
   set magstamp=`stat --format="%Y" ${rootname}.mag`
   if ( $magstamp > $defstamp ) then
      echo "Magic database file ${rootname}.mag is more recent than DEF file."
      echo "If you want to recreate the .mag file, remove or rename the existing one."
      set docreate=0
   endif
endif

set dispfile="${layoutdir}/load_${rootname}.tcl"

# The following script reads in the DEF file and modifies labels so
# that they are rotated outward from the cell, since DEF files don't
# indicate label geometry.

if ( ${docreate} == 1) then
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

if ( ! -f ${dispfile} ) then
cat > ${dispfile} << EOF
lef read ${lefpath}
load ${sourcename}
select top cell
expand
EOF
endif

endif

# Run magic and query what graphics device types are
# available.  Use OpenGL if available, fall back on
# X11, or else exit with a message

# support option to hardwire X11, don't want OGL thru x2go, etc.: too slow or corrupts the desktop session somehow.
# Even JUST "magic -noconsole -d" to QUERY the displays, may corrupt an x2go xfce desktop session somehow.

set magicogl=0
set magicx11=0

if ( ! $?magic_display ) then
  ${bindir}/magic -noconsole -d <<EOF >& .magic_displays
exit
EOF

  set magicogl=`cat .magic_displays | grep OGL | wc -l`
  set magicx11=`cat .magic_displays | grep X11 | wc -l`

  rm -f .magic_displays
endif

# Get the version of magic

${bindir}/magic -noconsole --version <<EOF >& .magic_version
exit
EOF

set magic_major=`cat .magic_version | cut -d. -f1`
set magic_minor=`cat .magic_version | cut -d. -f2`
set magic_rev=`cat .magic_version | cut -d. -f3`

rm -f .magic_version

# For magic versions less than 8.1.102, only the .mag file can
# be loaded from the command line.  Otherwise, run the script.

if ( ${magic_major} < 8 || ( ${magic_major} == 8 && ${magic_minor} < 1 ) || ( ${magic_major} == 8 && ${magic_minor} == 1 && ${magic_rev} < 102 ) ) then
   set dispfile = ${sourcename}
endif

# Run magic again, this time interactively.  The script
# exits when the user exits magic.

if ( $?magic_display ) then
   ${bindir}/magic -d ${magic_display} ${dispfile}
else if ( ${magicogl} >= 1 ) then
   ${bindir}/magic -d OGL ${dispfile}
else if ( ${magicx11} >= 1) then
   ${bindir}/magic -d X11 ${dispfile}
else
   echo "Magic does not support OpenGL or X11 graphics on this host."
endif

#------------------------------------------------------------
# Done!
#------------------------------------------------------------
