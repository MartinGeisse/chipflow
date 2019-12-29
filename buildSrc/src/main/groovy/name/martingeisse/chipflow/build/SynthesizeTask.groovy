package name.martingeisse.chipflow.build

import org.apache.commons.io.FileUtils
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction

import java.nio.file.Files

class SynthesizeTask extends MyTaskBase {

    @InputDirectory
    File verilogDirectory = getProject().file("src/verilog");

    @Input
    String toplevelModule;

    @InputDirectory
    File toolDirectory = new File("/usr/lib/qflow/bin");

    @InputDirectory
    File scriptDirectory = new File("/usr/lib/qflow/scripts");

    @InputFile
    File technologyLibertyFile

    @InputFile
    File technologySpiceFile

    @InputFile
    File technologyLefFile

    @OutputDirectory
    File outputDirectory = project.file("${project.buildDir}/chipflow/synthesize");

    @TaskAction
    void run() {

        //
        // clean previous results
        //

        FileUtils.deleteDirectory(outputDirectory)
        outputDirectory.mkdirs()

        //
        // build synthesis script
        //

        File yosysScript = new File(outputDirectory, "synthesis.yosys");
        File yosysOutputFile = new File(outputDirectory, "yosys-out.blif")
        yosysScript.withPrintWriter("ISO-8859-1", { out ->
            out.println()
            out.println("# read input files")
            out.println("read_liberty -lib -ignore_miss_dir -setattr blackbox ${technologyLibertyFile}")
            for (File file : verilogDirectory.listFiles()) {
                if (file.isFile() && file.getName().endsWith(".v")) {
                    out.println("read_verilog ${file}")
                }
            }
            out.println()
            out.println("# High-level synthesis")
            out.println("synth -top ${toplevelModule}")
            out.println()
            out.println("# Map register flops")
            out.println("dfflibmap -liberty ${technologyLibertyFile}")
            out.println("opt")
            out.println()
            out.println("# Map combinatorial cells, standard script")
            out.println("abc -exe /usr/lib/qflow/bin/yosys-abc -liberty ${technologyLibertyFile} -script +strash;scorr;ifraig;retime,{D};strash;dch,-f;map,-M,1,{D}")
            out.println("flatten")
            // remove buffers which were left to preserve internal net names for probing
            out.println("clean -purge")
            // Output buffering, if not specifically prevented
            out.println("iopadmap -outpad BUFX2 A:Y -bits")
            out.println("# Cleanup")
            out.println("opt")
            out.println("clean")
            out.println("rename -enumerate")
            out.println("write_blif -buf BUFX2 A Y ${yosysOutputFile}")
        });

        //
        // run yosys
        //

        File yosysLogfile = new File(outputDirectory, "yosys-log.txt");
        execute("${toolDirectory}/yosys -s ${yosysScript} &> ${yosysLogfile}")
        if (checkMissingOutputFile(yosysOutputFile, "yosys")) {
            return
        }

        //
        // post-process yosys output (originally in ypostproc.tcl)
        //

        // File postProcessingOutputFile = new File(outputDirectory, "postproc-out.blif");

        // TODO the original script generates and alias map but then does not use it. Here is the code for that:
//        synthesisOutputFile.eachLine {line ->
//            line = line.replace('[', '<').replace(']', '>')
//            String[] segments = StringUtils.split(line);
//            if (segments.length == 3 && segments[0] == '.names') {
//                /*
//                   set line [string map {\[ \< \] \>} $line]
//                   if [regexp {^.names[ \t]+([^ \t]+)[ \t]+([^ \t]+)[ \t]*$} $line lmatch signame sigalias] {
//                      # Technically, should check if the next line is "1 1" but I don't think there are
//                      # any exceptions in yosys output.
//                      if [catch {set ${signame}(alias)}] {
//                     set ${signame}(alias) {}
//                      }
//                      lappend ${signame}(alias) $sigalias
//                   }
//                 */
//            }
//        }

        // TODO rest of ypostproc.tcl

        //
        // tie-high and tie-low replacement from the qflow scripts is skipped here
        //

        /*
            Constant 0 and 1 should not be connected to VDD and GND directly since noise in the power supply would then cause the
            connected transistors to switch wrongly. Tie-low and tie-high cells are designed to prevent that, effectively
            working similar to a diode.

            The original qflow scripts tried to use a trick for technologies that are lacking tie-low and tie-high cells: Use
            a buffer instead whose input is connected to VDD or GND. Unfortunately, that script does not explain how the
            original problem is solved by that trick, and I suspect that it is similarly susceptible to noise as just connecting
            the actual output to VDD or GND. So I'll demand instead that proper tie-low / tie-high cells are available -- they
            are not that complicated to build, after all.

            Implementation-wise, for example a tie-high is a (transistor-implemented) pull-down resistor connected to the gate of
            a PMOS transistor that connects VDD to the output, providing a strong and noise-resistant 1.
         */

        //
        // declare this the final output of synthesis
        //

        File finalBlifFile = new File(outputDirectory, "synthesized.blif");
        Files.copy(yosysOutputFile.toPath(), finalBlifFile.toPath())

        //
        // produce output files in various formats
        //

        File outputVerilogFile = new File(outputDirectory, "synthesized.v")
        execute("${toolDirectory}/blif2Verilog -c -v vdd -g gnd ${finalBlifFile} > ${outputVerilogFile}")
        if (checkMissingOutputFile(outputVerilogFile, "blif2Verilog")) {
            return
        }

        File outputVerilogNopowerFile = new File(outputDirectory, "synthesized-nopower.v")
        execute("${toolDirectory}/blif2Verilog -c -p -v vdd -g gnd ${finalBlifFile} > ${outputVerilogNopowerFile}")
        if (checkMissingOutputFile(outputVerilogNopowerFile, "blif2Verilog")) {
            return
        }

        File outputBSpiceFile = new File(outputDirectory, "synthesized.spc")
        execute("${toolDirectory}/blif2BSpice -i -p vdd -g gnd -l ${technologySpiceFile} ${finalBlifFile} > ${outputBSpiceFile}")
        if (checkMissingOutputFile(outputBSpiceFile, "blif2BSpice")) {
            return
        }

        File outputXSpiceFile = new File(outputDirectory, "synthesized.xspice")
        execute("${scriptDirectory}/spi2xspice.py ${technologyLibertyFile} ${outputBSpiceFile} ${outputXSpiceFile}")
        if (checkMissingOutputFile(outputXSpiceFile, "spi2xspice.py")) {
            return
        }

        //
        // run post-synthesis timing analysis
        //

        File vestaLogfile = new File(outputDirectory, "vesta.txt")
        execute("${toolDirectory}/vesta --period 1E5 ${outputVerilogNopowerFile} ${technologyLibertyFile} &> ${vestaLogfile}")
        if (checkMissingOutputFile(vestaLogfile, "vesta")) {
            return
        }

    }

}
