package name.martingeisse.chipflow.build

import org.apache.commons.io.FileUtils
import org.apache.commons.io.IOUtils
import org.apache.commons.lang3.StringUtils
import org.gradle.api.DefaultTask
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction

import java.nio.charset.StandardCharsets

class SynthesizeTask extends MyTaskBase {

    @InputDirectory
    File verilogDirectory = getProject().file("src/verilog");

    @Input
    String toplevelModule;

    @OutputDirectory
    File outputDirectory = project.file("${project.buildDir}/chipflow/synthesize");

    @InputFile
    File technologyLibertyFile

    @InputFile
    File technologySpiceFile

    @InputFile
    File technologyLefFile

    @TaskAction
    void run() {

        // clean previous results
        FileUtils.deleteDirectory(outputDirectory)
        outputDirectory.mkdirs()

        // build synthesis script
        File synthesisScript = new File(outputDirectory, "synthesis.yosys");
        File synthesisOutputFile = new File(outputDirectory, "yosys-out.blif")
        synthesisScript.withPrintWriter("ISO-8859-1", { out ->
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
            out.println("write_blif -buf BUFX2 A Y ${synthesisOutputFile}")
        });

        // run yosys
        File synthesisLogfile = new File(outputDirectory, "log.txt");
        synthesisLogfile.withWriter {}
        "yosys -s synthesis.yosys |& tee -a ${synthesisLogfile}".execute().waitFor()
        if (checkMissingOutputFile(synthesisOutputFile, "yosys")) {
            return
        }

        // post-process yosys output (originally in ypostproc.tcl)
        // TODO the generated alias map is never used in that script!
//        File postProcessingOutputFile = new File(outputDirectory, "postproc-out.blif");
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


    }

}
