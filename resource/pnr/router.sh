#!/usr/bin/tcsh -f

source ${projectpath}/qflow_vars.sh
source ${techdir}/${techname}.sh
cd ${projectpath}
source project_vars.sh

# logfile should exist, but just in case. . .
touch ${synthlog}

set lefpath=techdir/osu050_stdcells.lef
cd ${layoutdir}


# If there is a file called (project)_unroute.def, copy it
# to the primary .def file to be used by the router.  This
# overwrites any previously generated route solution.

if ( -f ${rootname}_unroute.def ) then
   cp ${rootname}_unroute.def ${rootname}.def
endif


  #------------------------------------------------------------------
  # Scripted qrouter.  Given qrouter with Tcl/Tk scripting capability,
  # create a script to perform the routing.  The script will allow
  # the graphics to display, keep the output to the console at a
  # minimum, and generate a file with congestion information in the
  # case of route failure.
  #------------------------------------------------------------------

   ${bindir}/qrouter -noc -s ${rootname}.cfg >>& router-log.txt
  # TODO CHECK EXISTS ${rootname}_route.def

#---------------------------------------------------------------------
# If qrouter generated a ".cinfo" file, then annotate the ".cel"
# file, re-run placement, and re-run routing.
#---------------------------------------------------------------------

 if ( -f ${rootname}.cinfo && ( -M ${rootname}.cinfo > -M ${rootname}.def )) then
    ${scriptdir}/decongest.tcl ${rootname} ${lefpath} ${fillcell} |& tee -a ${synthlog}
 endif

if ( -f ${rootname}_route.def ) then
   rm -f ${rootname}.def
   mv ${rootname}_route.def ${rootname}.def
endif
