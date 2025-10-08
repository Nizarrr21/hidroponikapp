package io.flutter.plugins.gradle

import org.gradle.api.Project
import org.gradle.api.file.Directory
import org.gradle.api.provider.Provider
import java.io.File
import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermission

open class FlutterPlugin {
    companion object {
        fun fixPermissions(project: Project, directory: Provider<Directory>) {
            try {
                val dir = directory.get().asFile
                if (dir.exists()) {
                    Files.walk(dir.toPath()).forEach { path ->
                        try {
                            val file = path.toFile()
                            if (file.isFile) {
                                file.setExecutable(true, true)
                                file.setReadable(true, false)
                                file.setWritable(true, true)
                            }
                        } catch (e: Exception) {
                            project.logger.warn("Failed to set permissions for ${path}: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                project.logger.warn("Failed to walk directory: ${e.message}")
            }
        }
    }
}