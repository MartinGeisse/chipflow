package name.martingeisse.chipflow.build

import org.gradle.api.DefaultTask

class MyTaskBase extends DefaultTask {

    boolean checkMissingOutputFile(File file, String expectedProducer) {
        if (!file.exists()) {
            getLogger().error("${producer} did not produce output file: " + file)
            return true
        } else {
            return false
        }
    }

}
