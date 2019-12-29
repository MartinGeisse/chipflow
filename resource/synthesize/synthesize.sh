#!/usr/bin/tcsh -f

set projectpath=$argv[1]
set sourcename=$argv[2]
set rootname=${sourcename:h}

source ${projectpath}/qflow_vars.sh
source ${techdir}/${techname}.sh
cd ${projectpath}
source project_vars.sh

# Reset the logfile

set libertypath=techdir/osu05_stdcells.lib
set spicepath=techdir/osu050_stdcells.sp
set lefpath=techdir/osu050_stdcells.lef

cd ${sourcedir}






// TODO skipped for now:
// echo "Cleaning up output syntax" |& tee -a ${synthlog}
// ${scriptdir}/ypostproc.tcl yosys-out.blif sevenseg ${techdir}/${techname}.sh






#---------------------------------------------------------------------
# Remove backslashes, references to "$techmap", and
# make local input nodes of the form $0node<a:b><c> into the
# form node<c>_FF_INPUT
#---------------------------------------------------------------------

cat yosys-out_tmp.blif | sed \
	-e 's/\\\([^$]\)/\1/g' \
	-e 's/$techmap//g' \
	-e 's/$0\([^ \t<]*\)<[0-9]*:[0-9]*>\([^ \t]*\)/\1\2_FF_INPUT/g' \
	> ${synthdir}/sevenseg.blif

# Switch to synthdir for processing of the BDNET netlist
cd ${synthdir}




#---------------------------------------------------------------------
# Make a copy of the original blif file, as this will be overwritten
# by the fanout handling process
#---------------------------------------------------------------------

   cp sevenseg.blif sevenseg_bak.blif

#---------------------------------------------------------------------
# Check all gates for fanout load, and adjust gate strengths as
# necessary.  Iterate this step until all gates satisfy drive
# requirements.
#
# Use option "-c value" in fanout_options to force a value for the
# (maximum expected) output load, in fF (default is 30fF)
# Use option "-l value" in fanout_options to force a value for the
# maximum latency, in ps (default is 1000ps)
#---------------------------------------------------------------------

   rm -f sevenseg_nofanout
   touch sevenseg_nofanout
   if ($?gndnet) then
      echo $gndnet >> sevenseg_nofanout
   endif
   if ($?vddnet) then
      echo $vddnet >> sevenseg_nofanout
   endif

   if (! $?fanout_options) then
      set fanout_options=""
   endif

   echo "Running blifFanout (iterative)" |& tee -a ${synthlog}
   echo "" >> ${synthlog}
   if (-f ${libertypath} && -f ${bindir}/blifFanout ) then
      set nchanged=1000
      while ($nchanged > 0)
         mv sevenseg.blif tmp.blif
         if ("x${separator}" == "x") then
	    set sepoption=""
         else
	    set sepoption="-s ${separator}"
         endif
         if ("xBUFX2" == "x") then
	    set bufoption=""
         else
	    set bufoption="-b BUFX2 -i A -o Y"
         endif
         ${bindir}/blifFanout ${fanout_options} -I sevenseg_nofanout \
		-p ${libertypath} ${sepoption} ${bufoption} \
		tmp.blif sevenseg.blif >>& ${synthlog}
         set nchanged=$status
         echo "gates resized: $nchanged" |& tee -a ${synthlog}
      end
   else
      set nchanged=0
   endif

CHECK $nchanged >= 0, otherwise blifFanout failure
