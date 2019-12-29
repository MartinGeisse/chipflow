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

        // TODO: the original script checked for a .cel2 file to append to the .cel file. It is not clear to me
        // if any of the tools generates that file or if it was a chance for the user to specify parts of the .cel
        // file manually. The purpose given was "pin placement hints". Some truncating of the .cel file also
        // happened, possibly to be compatible with the output .cel file of a previous PNR pass.

        // TODO adding power bus stripes was commented out in the original script since it is unfinished work

        //
        // run placer and router in a loop until all congestion problems are solved
        //

        while (true) {
            File rootName = new File(celFile.getParent(), celFile.getName().substring(0, celFile.getName().length() - 4))

            // TODO possibly pass -n for "no graphics", not yet clear
            execute("${toolDirectory}/graywolf ${rootName} >>& graywolf-log.txt")
            if (checkMissingOutputFile(new File(rootName.getParent(), rootName.getName() + ".pin"), "graywolf")) {
                return
            }


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
