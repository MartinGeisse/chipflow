#!/usr/bin/tcsh -f

set projectpath='/home/martin/git-repos/chipflow'

source ${projectpath}/qflow_vars.sh
cd ${projectpath}
source project_vars.sh
cd ${layoutdir}
cd ${sourcedir}

rm -f sevenseg.blif
rm -f sevenseg.xml
rm -f sevenseg_tmp.blif
rm -f sevenseg_mapped.blif
rm -f sevenseg_mapped_tmp.blif
rm -f sevenseg.clk
rm -f sevenseg.enc
rm -f sevenseg.init
rm -f sevenseg_tmp.v

cd ${synthdir}
# rm -f sevenseg.blif
rm -f sevenseg_bak.blif
rm -f sevenseg_tmp.blif
rm -f sevenseg_orig.blif
rm -f sevenseg_nofanout

#----------------------------------------------------------
# Clean up the (excessively numerous) GrayWolf files
# Keep the input .cel and .par files, and the input
# _unroute.def file and the final output .def file.
#----------------------------------------------------------
cd ${layoutdir}
rm -f sevenseg.blk sevenseg.gen sevenseg.gsav sevenseg.history
rm -f sevenseg.log sevenseg.mcel sevenseg.mdat sevenseg.mgeo
rm -f sevenseg.mout sevenseg.mpin sevenseg.mpth sevenseg.msav
rm -f sevenseg.mver sevenseg.mvio sevenseg.stat sevenseg.out
rm -f sevenseg.pth sevenseg.sav sevenseg.scel
rm -f sevenseg.txt sevenseg.info
rm -f sevenseg.pin sevenseg.pl1 sevenseg.pl2
rm -f sevenseg.cfg
# rm -f sevenseg_unroute.def
rm -f cn
rm -f failed
