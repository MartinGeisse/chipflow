package name.martingeisse.chipflow.build

import org.gradle.api.DefaultTask

class MyTaskBase extends DefaultTask {

    boolean checkMissingOutputFile(File file, String expectedProducer) {
        if (!file.exists()) {
            getLogger().error("${expectedProducer} did not produce output file: " + file)
            return true
        } else {
            return false
        }
    }

    boolean execute(String command) {
        ProcessBuilder builder = new ProcessBuilder("bash", "-c", command)
        builder.redirectOutput(ProcessBuilder.Redirect.INHERIT)
        builder.redirectError(ProcessBuilder.Redirect.INHERIT)
        int exitCode = builder.start().waitFor()
        return (exitCode != 0)
    }

}
