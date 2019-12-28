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


#---------------------------------------------------------------------
# Spot check:  Did yosys produce file sevenseg_mapped.blif?
#---------------------------------------------------------------------

if ( !( -f sevenseg_mapped.blif )) then
   echo "outputprep failure:  No file sevenseg_mapped.blif." \
	|& tee -a ${synthlog}
   echo "Premature exit." |& tee -a ${synthlog}
   echo "Synthesis flow stopped due to error condition." >> ${synthlog}
   # Replace the old blif file, if we had moved it
   exit 1
endif

echo "Cleaning up output syntax" |& tee -a ${synthlog}
${scriptdir}/ypostproc.tcl sevenseg_mapped.blif sevenseg \
	${techdir}/${techname}.sh

#----------------------------------------------------------------------
# Add buffers in front of all outputs (for yosys versions before 0.2.0)
#----------------------------------------------------------------------

#---------------------------------------------------------------------
# The following definitions will replace "LOGIC0" and "LOGIC1"
# with buffers from gnd and vdd, respectively.  This takes care
# of technologies where tie-low and tie-high cells are not
# defined.
#---------------------------------------------------------------------

echo "Cleaning Up blif file syntax" |& tee -a ${synthlog}

set subs0a="/LOGIC0/s/O=/A=gnd Y=/"
set subs0b="/LOGIC0/s/LOGIC0/BUFX2/"

set subs1a="/LOGIC1/s/O=/A=vdd Y=/"
set subs1b="/LOGIC1/s/LOGIC1/BUFX2/"

#---------------------------------------------------------------------
# Remove backslashes, references to "$techmap", and
# make local input nodes of the form $0node<a:b><c> into the
# form node<c>_FF_INPUT
#---------------------------------------------------------------------

cat sevenseg_mapped_tmp.blif | sed \
	-e "$subs0a" -e "$subs0b" -e "$subs1a" -e "$subs1b" \
	-e 's/\\\([^$]\)/\1/g' \
	-e 's/$techmap//g' \
	-e 's/$0\([^ \t<]*\)<[0-9]*:[0-9]*>\([^ \t]*\)/\1\2_FF_INPUT/g' \
	> ${synthdir}/sevenseg.blif

# Switch to synthdir for processing of the BDNET netlist
cd ${synthdir}

#---------------------------------------------------------------------
# If "nofanout" is set, then don't run blifFanout.
#---------------------------------------------------------------------

if ($?nofanout) then
   set nchanged=0
else

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
endif

#---------------------------------------------------------------------
# Spot check:  Did blifFanout produce an error?
#---------------------------------------------------------------------

if ( $nchanged < 0 ) then
   echo "blifFanout failure.  See file ${synthlog} for error messages." \
	|& tee -a ${synthlog}
   echo "Premature exit." |& tee -a ${synthlog}
   echo "Synthesis flow stopped due to error condition." >> ${synthlog}
   exit 1
endif

echo "" >> ${synthlog}
echo "Generating RTL verilog and SPICE netlist file in directory" \
		|& tee -a ${synthlog}
echo "	 ${synthdir}" |& tee -a ${synthlog}
echo "Files:" |& tee -a ${synthlog}
echo "   Verilog: ${synthdir}/sevenseg.rtl.v" |& tee -a ${synthlog}
echo "   Verilog: ${synthdir}/sevenseg.rtlnopwr.v" |& tee -a ${synthlog}
echo "   Spice:   ${synthdir}/sevenseg.spc" |& tee -a ${synthlog}
echo "" >> ${synthlog}

echo "Running blif2Verilog." |& tee -a ${synthlog}
${bindir}/blif2Verilog -c -v ${vddnet} -g ${gndnet} sevenseg.blif \
	> sevenseg.rtl.v

${bindir}/blif2Verilog -c -p -v ${vddnet} -g ${gndnet} sevenseg.blif \
	> sevenseg.rtlnopwr.v

#---------------------------------------------------------------------
# Spot check:  Did blif2Verilog exit with an error?
# Note that these files are not critical to the main synthesis flow,
# so if they are missing, we flag a warning but do not exit.
#---------------------------------------------------------------------

if ( !( -f sevenseg.rtl.v || \
        ( -M sevenseg.rtl.v < -M sevenseg.blif ))) then
   echo "blif2Verilog failure:  No file sevenseg.rtl.v created." \
                |& tee -a ${synthlog}
endif

if ( !( -f sevenseg.rtlnopwr.v || \
        ( -M sevenseg.rtlnopwr.v < -M sevenseg.blif ))) then
   echo "blif2Verilog failure:  No file sevenseg.rtlnopwr.v created." \
                |& tee -a ${synthlog}
endif

#---------------------------------------------------------------------

echo "Running blif2BSpice." |& tee -a ${synthlog}
if ("x${spicefile}" == "x") then
    set spiceopt=""
else
    set spiceopt="-l ${spicepath}"
endif
${bindir}/blif2BSpice -i -p ${vddnet} -g ${gndnet} ${spiceopt} \
	sevenseg.blif > sevenseg.spc

#---------------------------------------------------------------------
# Spot check:  Did blif2BSpice exit with an error?
# Note that these files are not critical to the main synthesis flow,
# so if they are missing, we flag a warning but do not exit.
#---------------------------------------------------------------------

if ( !( -f sevenseg.spc || \
        ( -M sevenseg.spc < -M sevenseg.blif ))) then
   echo "blif2BSpice failure:  No file sevenseg.spc created." \
                |& tee -a ${synthlog}
else

   echo "Running spi2xspice.py" |& tee -a ${synthlog}
   if ("x${spicefile}" == "x") then
       set spiceopt=""
   else
       set spiceopt="-l ${spicepath}"
   endif
   ${scriptdir}/spi2xspice.py ${libertypath} sevenseg.spc \
		sevenseg.xspice
endif

if ( !( -f sevenseg.xspice || \
	( -M sevenseg.xspice < -M sevenseg.spc ))) then
   echo "spi2xspice.py failure:  No file sevenseg.xspice created." \
		|& tee -a ${synthlog}
endif

#---------------------------------------------------------------------

cd ${projectpath}
set endtime = `date`
echo "Synthesis script ended on $endtime" >> $synthlog
