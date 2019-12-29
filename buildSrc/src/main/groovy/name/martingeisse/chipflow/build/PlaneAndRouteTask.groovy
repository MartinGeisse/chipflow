package name.martingeisse.chipflow.build

import org.apache.commons.io.FileUtils
import org.gradle.api.tasks.*

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

        //
        // clean previous results
        //

        FileUtils.deleteDirectory(outputDirectory)
        outputDirectory.mkdirs()

        //
        // convert .blif to .cel
        //

        File synthesizedBlifFile = new File(inputDirectory, "synthesized.blif")
        File celFile = new File(outputDirectory, "input.cel")
        execute("${scriptDirectory}/blif2cel.tcl --blif ${synthesizedBlifFile} --lef ${technologyLefFile} --cel ${celFile}")
        if (checkMissingOutputFile(celFile, "blif2cel.tcl")) {
            return
        }

        //
        // "initial density" support
        //

        // TODO: the script code does not seem to handle both initial density and router congestion info at the
        // same time, so I'll leave this commented out for now. It seems more like a workaround than a real solution
        // anyway since info from the router is much more valuable.

        /*
        if ( ${?initial_density} ) then
        echo "Running decongest to set initial density of ${initial_density}"
        ${scriptdir}/decongest.tcl ${rootname} ${lefpath} ${fillcell} ${initial_density} |& tee -a place-log.txt
        cp ${rootname}.cel ${rootname}.cel.bak
        mv ${rootname}.acel ${rootname}.cel
        endif
        */

        //
        // run placer and router in a loop until all congestion problems are solved
        //

        while (true) {

            // TODO placer

            // TODO router
            File acelOutputFile

            if (!acelOutputFile.exists()) {
                break;
            }

            celFile.delete()
            acelOutputFile.renameTo(celFile)

        }

    }

}
