#!/usr/bin/tcsh -f

# If there is a file called (project)_unroute.def, copy it
# to the primary .def file to be used by the router.  This
# overwrites any previously generated route solution.

if ( -f ${rootname}_unroute.def ) then
   cp ${rootname}_unroute.def ${rootname}.def
endif


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
