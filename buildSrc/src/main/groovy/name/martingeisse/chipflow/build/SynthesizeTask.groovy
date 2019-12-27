package name.martingeisse.chipflow.build

import org.apache.commons.io.FileUtils
import org.apache.commons.io.IOUtils
import org.gradle.api.DefaultTask
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputDirectory
import org.gradle.api.tasks.TaskAction

import java.nio.charset.StandardCharsets

class SynthesizeTask extends DefaultTask {

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
        synthesisScript.withPrintWriter("ISO-8859-1", { out ->
            out.println()
            out.println("# read input files")
            out.println("read_liberty -lib -ignore_miss_dir -setattr blackbox " + technologyLibertyFile)
            for (File file : verilogDirectory.listFiles()) {
                if (file.isFile() && file.getName().endsWith(".v")) {
                    out.println("read_verilog " + file)
                }
            }
            out.println()
            out.println("# High-level synthesis")
            out.println("synth -top " + toplevelModule)
            out.println()
            out.println("# Map register flops")
            out.println("dfflibmap -liberty " + technologyLibertyFile)
            out.println("opt")
            out.println()
        });

    }

}
