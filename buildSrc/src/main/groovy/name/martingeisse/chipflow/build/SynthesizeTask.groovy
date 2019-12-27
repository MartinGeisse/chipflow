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

        String filename = new Random().nextInt(100) + ".txt"
        FileUtils.writeStringToFile(new File(outputDirectory, filename), "foo", StandardCharsets.ISO_8859_1)
    }

}
