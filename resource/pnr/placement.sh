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










 #------------------------------------------------------------------
 # Automatic optimization of buffer tree placement causes the
 # original BLIF netlist, with tentative buffer assignments, to
 # be invalid.  Use the blifanno.tcl script to back-annotate the
 # correct assignments into the original BLIF netlist, then
 # use that BLIF netlist to regenerate the SPICE and RTL verilog
 # netlists.
 #------------------------------------------------------------------

 ${scriptdir}/blifanno.tcl ${synthdir}/${rootname}.blif ${rootname}.def ${synthdir}/${rootname}_anno.blif >>& place-log.txt

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
