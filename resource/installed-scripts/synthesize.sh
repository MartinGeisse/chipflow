#!/usr/bin/tcsh -f

set projectpath=$argv[1]
set sourcename=$argv[2]
set rootname=${sourcename:h}

source ${projectpath}/qflow_vars.sh
source ${techdir}/${techname}.sh
cd ${projectpath}
source project_vars.sh

# Reset the logfile
rm -f ${synthlog} >& /dev/null
touch ${synthlog}

set libertypath=techdir/osu05_stdcells.lib
set spicepath=techdir/osu050_stdcells.sp
set lefpath=techdir/osu050_stdcells.lef

cd ${sourcedir}

# done: generate yosys script head



cat >> ${rootname}.ys << EOF
# Cleanup
opt
clean
rename -enumerate
write_blif ${blif_opts} -buf BUFX2 A Y ${rootname}_mapped.blif
EOF


#---------------------------------------------------------------------
# Yosys synthesis
#---------------------------------------------------------------------

# If there is a file ${rootname}_mapped.blif, move it to a temporary
# place so we can see if yosys generates a new one or not.

if ( -f ${rootname}_mapped.blif ) then
   mv ${rootname}_mapped.blif ${rootname}_mapped_orig.blif
endif

eval ${bindir}/yosys -s ${rootname}.ys |& tee -a ${synthlog}

#---------------------------------------------------------------------
# Spot check:  Did yosys produce file ${rootname}_mapped.blif?
#---------------------------------------------------------------------

if ( !( -f ${rootname}_mapped.blif )) then
   echo "outputprep failure:  No file ${rootname}_mapped.blif." \
	|& tee -a ${synthlog}
   echo "Premature exit." |& tee -a ${synthlog}
   echo "Synthesis flow stopped due to error condition." >> ${synthlog}
   # Replace the old blif file, if we had moved it
   if ( -f ${rootname}_mapped_orig.blif ) then
      mv ${rootname}_mapped_orig.blif ${rootname}_mapped.blif
   endif
   exit 1
else
   # Remove the old blif file, if we had moved it
   if ( -f ${rootname}_mapped_orig.blif ) then
      rm ${rootname}_mapped_orig.blif
   endif
endif

echo "Cleaning up output syntax" |& tee -a ${synthlog}
${scriptdir}/ypostproc.tcl ${rootname}_mapped.blif ${rootname} \
	${techdir}/${techname}.sh

#----------------------------------------------------------------------
# Add buffers in front of all outputs (for yosys versions before 0.2.0)
#----------------------------------------------------------------------

# Buffers already handled within yosys
set final_blif = "${rootname}_mapped_tmp.blif"

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

cat ${final_blif} | sed \
	-e "$subs0a" -e "$subs0b" -e "$subs1a" -e "$subs1b" \
	-e 's/\\\([^$]\)/\1/g' \
	-e 's/$techmap//g' \
	-e 's/$0\([^ \t<]*\)<[0-9]*:[0-9]*>\([^ \t]*\)/\1\2_FF_INPUT/g' \
	> ${synthdir}/${rootname}.blif

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

   cp ${rootname}.blif ${rootname}_bak.blif

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

   rm -f ${rootname}_nofanout
   touch ${rootname}_nofanout
   if ($?gndnet) then
      echo $gndnet >> ${rootname}_nofanout
   endif
   if ($?vddnet) then
      echo $vddnet >> ${rootname}_nofanout
   endif

   if (! $?fanout_options) then
      set fanout_options=""
   endif

   echo "Running blifFanout (iterative)" |& tee -a ${synthlog}
   echo "" >> ${synthlog}
   if (-f ${libertypath} && -f ${bindir}/blifFanout ) then
      set nchanged=1000
      while ($nchanged > 0)
         mv ${rootname}.blif tmp.blif
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
         ${bindir}/blifFanout ${fanout_options} -I ${rootname}_nofanout \
		-p ${libertypath} ${sepoption} ${bufoption} \
		tmp.blif ${rootname}.blif >>& ${synthlog}
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
echo "   Verilog: ${synthdir}/${rootname}.rtl.v" |& tee -a ${synthlog}
echo "   Verilog: ${synthdir}/${rootname}.rtlnopwr.v" |& tee -a ${synthlog}
echo "   Spice:   ${synthdir}/${rootname}.spc" |& tee -a ${synthlog}
echo "" >> ${synthlog}

echo "Running blif2Verilog." |& tee -a ${synthlog}
${bindir}/blif2Verilog -c -v ${vddnet} -g ${gndnet} ${rootname}.blif \
	> ${rootname}.rtl.v

${bindir}/blif2Verilog -c -p -v ${vddnet} -g ${gndnet} ${rootname}.blif \
	> ${rootname}.rtlnopwr.v

#---------------------------------------------------------------------
# Spot check:  Did blif2Verilog exit with an error?
# Note that these files are not critical to the main synthesis flow,
# so if they are missing, we flag a warning but do not exit.
#---------------------------------------------------------------------

if ( !( -f ${rootname}.rtl.v || \
        ( -M ${rootname}.rtl.v < -M ${rootname}.blif ))) then
   echo "blif2Verilog failure:  No file ${rootname}.rtl.v created." \
                |& tee -a ${synthlog}
endif

if ( !( -f ${rootname}.rtlnopwr.v || \
        ( -M ${rootname}.rtlnopwr.v < -M ${rootname}.blif ))) then
   echo "blif2Verilog failure:  No file ${rootname}.rtlnopwr.v created." \
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
	${rootname}.blif > ${rootname}.spc

#---------------------------------------------------------------------
# Spot check:  Did blif2BSpice exit with an error?
# Note that these files are not critical to the main synthesis flow,
# so if they are missing, we flag a warning but do not exit.
#---------------------------------------------------------------------

if ( !( -f ${rootname}.spc || \
        ( -M ${rootname}.spc < -M ${rootname}.blif ))) then
   echo "blif2BSpice failure:  No file ${rootname}.spc created." \
                |& tee -a ${synthlog}
else

   echo "Running spi2xspice.py" |& tee -a ${synthlog}
   if ("x${spicefile}" == "x") then
       set spiceopt=""
   else
       set spiceopt="-l ${spicepath}"
   endif
   ${scriptdir}/spi2xspice.py ${libertypath} ${rootname}.spc \
		${rootname}.xspice
endif

if ( !( -f ${rootname}.xspice || \
	( -M ${rootname}.xspice < -M ${rootname}.spc ))) then
   echo "spi2xspice.py failure:  No file ${rootname}.xspice created." \
		|& tee -a ${synthlog}
endif

#---------------------------------------------------------------------

cd ${projectpath}
set endtime = `date`
echo "Synthesis script ended on $endtime" >> $synthlog
