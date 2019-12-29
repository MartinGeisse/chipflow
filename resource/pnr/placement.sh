#!/usr/bin/tcsh -f
#----------------------------------------------------------
# Placement script using GrayWolf
#
# This script assumes the existence of the pre-GrayWolf
# ".cel" and ".par" files.  It will run GrayWolf for the
# placement.
#----------------------------------------------------------

# Usage:  placement.sh $projectpath $sourcename
set rootname=${sourcename:h}

source ${projectpath}/qflow_vars.sh
source ${techdir}/${techname}.sh
cd ${projectpath}
source project_vars.sh

set spicepath=techdir/osu050_stdcells.sp
set lefpath=techdir/osu050_stdcells.lef

# logfile should exist, but just in case. . .
touch place-log.txt
cd ${layoutdir}






# Check if a .cel2 file exists and needs to be appended to .cel
# If the .cel2 file is newer than .cel, then truncate .cel and
# re-append.

if ( -f ${rootname}.cel2 ) then
   echo "Preparing pin placement hints from ${rootname}.cel2" |& tee -a place-log.txt
   if ( `grep -c padgroup ${rootname}.cel` == "0" ) then
      cat ${rootname}.cel2 >> ${rootname}.cel
   else if ( -M ${rootname}.cel2 > -M ${rootname}.cel ) then
      # Truncate .cel file to first line containing "padgroup"
      cat ${rootname}.cel | sed -e "/padgroup/Q" > ${rootname}_tmp.cel
      cat ${rootname}_tmp.cel ${rootname}.cel2 > ${rootname}.cel
      rm -f ${rootname}_tmp.cel
   endif
else
   echo -n "No ${rootname}.cel2 file found for project. . . " \
		|& tee -a place-log.txt
   echo "continuing without pin placement hints" |& tee -a place-log.txt
endif

#
# TODO adding power bus stripes was commented out in the original script since it is unfinished work
#

#-----------------------------------------------
# 1) Run GrayWolf
#-----------------------------------------------

if ( !( ${?graywolf_options} )) then
   if ( !( ${?DISPLAY} )) then
      set graywolf_options = "-n"
   else
      set graywolf_options = ""
   endif
endif

echo "Running GrayWolf placement" |& tee -a place-log.txt
   ${bindir}/graywolf ${graywolf_options} $rootname >>& place-log.txt
endif

#---------------------------------------------------------------------
# Spot check:  Did GrayWolf produce file ${rootname}.pin?
#---------------------------------------------------------------------

# TODO check exists: ${rootname}.pin

#---------------------------------------------------
# 2) Prepare DEF and .cfg files for qrouter
#---------------------------------------------------

# First prepare a simple .cfg file that can be used to point qrouter
# to the LEF files when generating layer information using the "-i" option.


 #------------------------------------------------------------------
 # Determine the version number and availability of scripting
 # in qrouter.
 #------------------------------------------------------------------

 set version=`${bindir}/qrouter -v 0 -h | tail -1`
 set major=`echo $version | cut -d. -f1`
 set minor=`echo $version | cut -d. -f2`
 set subv=`echo $version | cut -d. -f3`
 set scripting=`echo $version | cut -d. -f4`

 # Create the initial (bootstrap) configuration file

 if ( $scripting == "T" ) then
    echo "read_lef ${lefpath}" > ${rootname}.cfg
 else
    echo "lef ${lefpath}" > ${rootname}.cfg
 endif

 ${bindir}/qrouter -i ${rootname}.info -c ${rootname}.cfg

 #---------------------------------------------------------------------
 # Spot check:  Did qrouter produce file ${rootname}.info?
 #---------------------------------------------------------------------

 if ( !( -f ${rootname}.info || ( -M ${rootname}.info < -M ${rootname}.pin ))) then
    echo "qrouter (-i) failure:  No file ${rootname}.info." |& tee -a place-log.txt
    echo "Premature exit." |& tee -a place-log.txt
    echo "Synthesis flow stopped due to error condition." >> place-log.txt
    exit 1
 endif

 # Run getfillcell to determine which cell should be used for fill to
 # match the width specified for feedthroughs in the .par file.  If
 # nothing is returned by getfillcell, then either feedthroughs have
 # been disabled, or else we'll try passing $fillcell directly to
 # place2def

 echo "Running getfillcell.tcl" |& tee -a place-log.txt
 set usefillcell = `${scriptdir}/getfillcell.tcl $rootname \
${lefpath} $fillcell | grep fill= | cut -d= -f2`

 if ( "${usefillcell}" == "" ) then
    set usefillcell = $fillcell
 endif
 echo "Using cell ${usefillcell} for fill" |& tee -a place-log.txt

 # Run place2def to turn the GrayWolf output into a DEF file

 if ( ${?route_layers} ) then
    ${scriptdir}/place2def.tcl $rootname $usefillcell ${route_layers} \
   >>& place-log.txt
 else
    ${scriptdir}/place2def.tcl $rootname $usefillcell >>& place-log.txt
 endif

 #---------------------------------------------------------------------
 # Spot check:  Did place2def produce file ${rootname}.def?
 #---------------------------------------------------------------------

 if ( !( -f ${rootname}.def || ( -M ${rootname}.def < -M ${rootname}.pin ))) then
    echo "place2def failure:  No file ${rootname}.def." |& tee -a place-log.txt
    echo "Premature exit." |& tee -a place-log.txt
    echo "Synthesis flow stopped due to error condition." >> place-log.txt
    exit 1
 endif

 #---------------------------------------------------------------------
 # Add spacer cells to create a straight border on the right side
 #---------------------------------------------------------------------

 if ( -f ${scriptdir}/addspacers.tcl ) then

    if ( !( ${?addspacers_options} )) then
       set addspacers_options = ""
    endif

    echo "Running addspacers.tcl ${addspacers_options} ${rootname} ${lefpath} ${fillcell}" |& tee -a place-log.txt

    ${scriptdir}/addspacers.tcl ${addspacers_options} \
  ${rootname} ${lefpath} ${fillcell} >>& place-log.txt
    if ( -f ${rootname}_filled.def ) then
 mv ${rootname}_filled.def ${rootname}.def
 # Copy the .def file to a backup called "unroute"
 cp ${rootname}.def ${rootname}_unroute.def
    endif

    if ( -f ${rootname}.obsx ) then
       # If addspacers annotated the .obs (obstruction) file, then
       # overwrite the original.
 mv ${rootname}.obsx ${rootname}.obs
    endif
 else
    # Copy the .def file to a backup called "unroute"
    cp ${rootname}.def ${rootname}_unroute.def
 endif

 # If the user didn't specify a number of layers for routing as part of
 # the project variables, then the info file created by qrouter will have
 # as many lines as there are route layers defined in the technology LEF
 # file.

 if ( !( ${?route_layers} )) then
    set route_layers = `cat ${rootname}.info | grep -e horizontal -e vertical | wc -l`
 endif

 # Create the main configuration file

 # Variables "via_pattern" (none, normal, invert) and "via_stacks"
 # can be specified in the tech script, and are appended to the
 # qrouter configuration file.  via_stacks defaults to 2 if not
 # specified.  It can be overridden from the user's .cfg2 file.

 if (${scripting} == "T") then
    echo "# qrouter runtime script for project ${rootname}" > ${rootname}.cfg
    echo "" >> ${rootname}.cfg
    echo "verbose 1" >> ${rootname}.cfg
    echo "read_lef ${lefpath}" >> ${rootname}.cfg
    echo "catch {layers ${route_layers}}" >> ${rootname}.cfg
    if ( ${?via_pattern} ) then
       echo "" >> ${rootname}.cfg
       echo "via pattern ${via_pattern}" >> ${rootname}.cfg
    endif
    if (! ${?via_stacks} ) then
       set via_stacks=2
       echo "via stack ${via_stacks}" >> ${rootname}.cfg
    endif
    if ( ${?vddnet} ) then
 echo "vdd $vddnet" >> ${rootname}.cfg
    endif
    if ( ${?gndnet} ) then
 echo "gnd $gndnet" >> ${rootname}.cfg
    endif

 else
    echo "# qrouter configuration for project ${rootname}" > ${rootname}.cfg
    echo "" >> ${rootname}.cfg
    echo "lef ${lefpath}" >> ${rootname}.cfg
    echo "num_layers ${route_layers}" >> ${rootname}.cfg
    if ( ${?via_pattern} ) then
       echo "" >> ${rootname}.cfg
       echo "via pattern ${via_pattern}" >> ${rootname}.cfg
    endif
    if (! ${?via_stacks} ) then
       set via_stacks=2
       echo "stack ${via_stacks}" >> ${rootname}.cfg
    endif
 endif

 # Add obstruction fence around design, created by place2def.tcl
 # and modified by addspacers.tcl

 if ( -f ${rootname}.obs ) then
    cat ${rootname}.obs >> ${rootname}.cfg
 endif

 # Scripted version continues with the read-in of the DEF file

 if (${scripting} == "T") then
    echo "read_def ${rootname}.def" >> ${rootname}.cfg
 endif

 # If there is a file called ${rootname}.cfg2, then append it to the
 # ${rootname}.cfg file.  It will be used to define all routing behavior.
 # Otherwise, if using scripting, then append the appropriate routing
 # command or procedure based on whether this is a pre-congestion
 # estimate of routing or the final routing pass.

 if ( -f ${rootname}.cfg2 ) then
    cat ${rootname}.cfg2 >> ${rootname}.cfg
 else
    if (${scripting} == "T") then
 echo "qrouter::standard_route" >> ${rootname}.cfg
 # Standard route falls back to the interpreter on failure,
 # so make sure that qrouter actually exits.
 echo "quit" >> ${rootname}.cfg
    endif
 endif

 #------------------------------------------------------------------
 # Automatic optimization of buffer tree placement causes the
 # original BLIF netlist, with tentative buffer assignments, to
 # be invalid.  Use the blifanno.tcl script to back-annotate the
 # correct assignments into the original BLIF netlist, then
 # use that BLIF netlist to regenerate the SPICE and RTL verilog
 # netlists.
 #------------------------------------------------------------------

 ${scriptdir}/blifanno.tcl ${synthdir}/${rootname}.blif ${rootname}.def \
  ${synthdir}/${rootname}_anno.blif >>& place-log.txt

 #------------------------------------------------------------------
 # Spot check:  Did blifanno.tcl produce an output file?
 #------------------------------------------------------------------

 if ( !( -f ${synthdir}/${rootname}_anno.blif )) then
    echo "blifanno.tcl failure:  No file ${rootname}_anno.blif." \
  |& tee -a place-log.txt
    echo "RTL verilog and SPICE netlists may be invalid if there" \
  |& tee -a place-log.txt
    echo "were buffer trees optimized by placement." |& tee -a place-log.txt
    echo "Synthesis flow continuing, condition not fatal." >> place-log.txt
  else
    echo "" >> place-log.txt
    echo "Generating RTL verilog and SPICE netlist file in directory" \
  |& tee -a place-log.txt
    echo "   ${synthdir}" |& tee -a place-log.txt
    echo "Files:" |& tee -a place-log.txt
    echo "   Verilog: ${synthdir}/${rootname}.rtl.v" |& tee -a place-log.txt
    echo "   Verilog: ${synthdir}/${rootname}.rtlnopwr.v" |& tee -a place-log.txt
    echo "   Spice:   ${synthdir}/${rootname}.spc" |& tee -a place-log.txt
    echo "" >> place-log.txt

    cd ${synthdir}
    echo "Running blif2Verilog." |& tee -a place-log.txt
    ${bindir}/blif2Verilog -c -v ${vddnet} -g ${gndnet} \
  ${rootname}_anno.blif > ${rootname}.rtl.v

    ${bindir}/blif2Verilog -c -p -v ${vddnet} -g ${gndnet} \
  ${rootname}_anno.blif > ${rootname}.rtlnopwr.v

    echo "Running blif2BSpice." |& tee -a place-log.txt
    ${bindir}/blif2BSpice -i -p ${vddnet} -g ${gndnet} -l \
  ${spicepath} ${rootname}_anno.blif \
  > ${rootname}.spc

    #------------------------------------------------------------------
    # Spot check:  Did blif2Verilog or blif2BSpice exit with an error?
    #------------------------------------------------------------------

    if ( !( -f ${rootname}.rtl.v || \
  ( -M ${rootname}.rtl.v < -M ${rootname}.blif ))) then
 echo "blif2Verilog failure:  No file ${rootname}.rtl.v created." \
  |& tee -a place-log.txt
    endif

    if ( !( -f ${rootname}.rtlnopwr.v || \
  ( -M ${rootname}.rtlnopwr.v < -M ${rootname}.blif ))) then
 echo "blif2Verilog failure:  No file ${rootname}.rtlnopwr.v created." \
  |& tee -a place-log.txt
    endif

    if ( !( -f ${rootname}.spc || \
  ( -M ${rootname}.spc < -M ${rootname}.blif ))) then
 echo "blif2BSpice failure:  No file ${rootname}.spc created." \
  |& tee -a place-log.txt
    endif

    # Return to the layout directory
    cd ${layoutdir}

  endif

#---------------------------------------------------
# 4) Remove working files (except for the main
#    output files .pin, .pl1, and .pl2
#---------------------------------------------------

# remove unnecessary output files
rm -f ${rootname}.blk ${rootname}.gen ${rootname}.gsav ${rootname}.history
rm -f ${rootname}.log ${rootname}.mcel ${rootname}.mdat ${rootname}.mgeo
rm -f ${rootname}.mout ${rootname}.mpin ${rootname}.mpth ${rootname}.msav
rm -f ${rootname}.mver ${rootname}.mvio ${rootname}.stat ${rootname}.out
rm -f ${rootname}.pth ${rootname}.sav ${rootname}.scel ${rootname}.txt
