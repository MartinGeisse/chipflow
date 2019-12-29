#!/usr/bin/tcsh -f

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
