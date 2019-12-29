package name.martingeisse.chipflow.build

import org.apache.commons.io.FileUtils
import org.gradle.api.tasks.*

import java.nio.file.Files

class PlaneAndRouteTask extends MyTaskBase {

    @InputDirectory
    File inputDirectory = project.file("${project.buildDir}/chipflow/synthesize");

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
    File outputDirectory = project.file("${project.buildDir}/chipflow/pnr");

    @TaskAction
    void run() {
        // TODO multiple passes based on .acel file
        runSinglePass()
    }

    void runSinglePass() {

        //
        // clean previous results
        //

        FileUtils.deleteDirectory(outputDirectory)
        outputDirectory.mkdirs()

        //
        // convert .blif to .cel
        //

        File synthesizedBlifFile = new File(inputDirectory, "synthesized.blif")
        File celInputFile = new File(outputDirectory, "input.cel")
        execute("${scriptDirectory}/blif2cel.tcl --blif ${synthesizedBlifFile} --lef ${technologyLefFile} --cel ${celInputFile}")
        if (checkMissingOutputFile(celInputFile, "blif2cel.tcl")) {
            return
        }

    }

}
