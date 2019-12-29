package name.martingeisse.chipflow.build

import org.apache.commons.io.FileUtils
import org.gradle.api.tasks.*

class PlaneAndRouteTask extends MyTaskBase {

    @InputDirectory
    File inputDirectory = project.file("${project.buildDir}/chipflow/synthesize")

    @Input
    String toplevelModule;

    @InputDirectory
    File toolDirectory = new File("/usr/lib/qflow/bin");

    @InputDirectory
    File scriptDirectory = new File("/usr/lib/qflow/scripts")

    @InputFile
    File technologyLibertyFile

    @InputFile
    File technologySpiceFile

    @InputFile
    File technologyLefFile

    @OutputDirectory
    File outputDirectory = project.file("${project.buildDir}/chipflow/pnr")

    @TaskAction
    void run() {

        //
        // clean previous results
        //

        FileUtils.deleteDirectory(outputDirectory)
        outputDirectory.mkdirs()

        //
        // some tools derive file names implicitly from a root name, so use a common one
        //

        File rootFile = new File(outputDirectory, "design")

        //
        // Use a common log file for all tools. Separate logfiles are not useful since we have to call the P and R
        // tools repeatedly,
        //

        File logfile = new File(outputDirectory, "pnr-log.txt")

        //
        // convert .blif to .cel
        //

        File synthesizedBlifFile = new File(inputDirectory, "synthesized.blif")
        File celFile = new File(outputDirectory, "design.cel")
        execute("${scriptDirectory}/blif2cel.tcl --blif ${synthesizedBlifFile} --lef ${technologyLefFile} --cel ${celFile} >>& ${logfile}")
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
        // get router information
        //

        File routerConfigurationFile = new File(outputDirectory, "design.cfg")
        routerConfigurationFile.withPrintWriter { out ->
            out.println("read_lef ${technologyLefFile}")
        }
        File routerInfoFile = new File(outputDirectory, "design.info")
        execute("${scriptDirectory}/qrouter -i ${routerInfoFile} -c ${routerConfigurationFile} >>& ${logfile}")
        if (checkMissingOutputFile(routerInfoFile, "router (info)")) {
            return
        }
        int routingLayers = 0
        routerInfoFile.eachLine {line ->
            if (line.contains("horizontal") && line.contains("vertical")) {
                routingLayers++
            }
        }


        // TODO fill cell is called FILL, width is 240 whatevers. The whole getfillcell scheme from the original script
        // seems dubious at best.

        //
        // run placer and router in a loop until all congestion problems are solved
        //

        while (true) {
            File designDefFile = new File(outputDirectory, "design.def")
            File designObsFile = new File(outputDirectory, "design.obs")

            // TODO it is currently unclear to me whether a second iteration should use the DEF file from the router
            // or the original one. This was really hard to see from the original scripts.

            //
            // placement
            //

            // TODO possibly pass -n for "no graphics", not yet clear
            execute("${toolDirectory}/graywolf ${rootFile} >>& ${logfile}")
            if (checkMissingOutputFile(new File(outputDirectory, "design.pin"), "graywolf")) {
                return
            }

            execute("${scriptDirectory}/place2def.tcl ${rootFile} FILL >>& ${logfile}")
            if (checkMissingOutputFile(designDefFile, "place2def.tcl")) {
                return
            }

            execute("${scriptDirectory}/addspacers.tcl -stripe 5 200 PG -nostretch ${rootFile} ${technologyLefFile} FILL >>& ${logfile}")
            File designFilledDefFile = new File(outputDirectory, "design_filled.def")
            if (designFilledDefFile.exists()) {
                designDefFile.delete()
                designFilledDefFile.renameTo(designDefFile)
            }
            File designObsxFile = new File(outputDirectory, "design.obsx")
            if (designObsxFile.exists()) {
                designObsFile.delete()
                designObsxFile.renameTo(designObsFile)
            }



            //
            // router
            //

            File routerScript = new File(outputDirectory, "design.cfg");
            routerScript.withPrintWriter("ISO-8859-1", { out ->
                out.println("verbose 1")
                out.println("read_lef ${technologyLefFile}")
                out.println("catch {layers ${routingLayers}}")
                // out.println("via pattern ${via_pattern}") // TODO "via_pattern" (none, normal, invert)
                out.println("via stack 2")
                out.println("vdd vdd")
                out.println("gnd gnd")
            })





            //
            // ??? TODO
            //

            File acelOutputFile

            if (!acelOutputFile.exists()) {
                break;
            }

            celFile.delete()
            acelOutputFile.renameTo(celFile)

        }

    }

}
