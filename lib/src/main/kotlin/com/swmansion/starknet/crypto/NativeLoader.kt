package com.swmansion.starknet.crypto

import java.net.URL
import java.nio.file.FileSystems
import java.nio.file.Files
import java.util.*

internal object NativeLoader {
    private val operatingSystem: SystemType by lazy {
        val system = System.getProperty("os.name", "generic")?.lowercase(Locale.ENGLISH) ?: throw UnknownOS()
        when {
            system.contains("mac") || system.contains("darwin") -> SystemType.MacOS
            system.contains("win") -> SystemType.Windows
            system.contains("nux") -> SystemType.Linux
            else -> SystemType.Other
        }
    }

    private val architecture: String by lazy {
        normalizeArchitecture(System.getProperty("os.arch"))
    }

    /**
     * Normalize architecture names to match the directory structure in the JAR.
     * Different JVM implementations report different arch names for the same platform.
     */
    private fun normalizeArchitecture(arch: String): String {
        return when (arch.lowercase(Locale.ENGLISH)) {
            "amd64", "x86_64", "x64" -> "x86_64" // Intel/AMD 64-bit
            "arm64", "aarch64" -> "aarch64" // ARM 64-bit
            else -> arch // Pass through unknown architectures
        }
    }

    fun load(name: String) = load(name, operatingSystem, architecture)

    private fun load(name: String, operatingSystem: SystemType, architecture: String) {
        try {
            // Used for tests, on android and in case someone wants to use a library from
            // a class path.
            System.loadLibrary(name)
        } catch (e: UnsatisfiedLinkError) {
            // Find the package bundled in this jar
            val path = getLibPath(operatingSystem, architecture, "lib" + name)
            val resource =
                NativeLoader::class.java.getResource(path) ?: throw UnsupportedPlatform(
                    operatingSystem.name,
                    architecture,
                )
            loadFromJar(name, resource)
        }
    }

    @Suppress("UnsafeDynamicallyLoadedCode")
    private fun loadFromJar(name: String, resource: URL) {
        // Android lint complains about it, but android should never reach this code
        val tmpDir = Files.createTempDirectory("$name-dir").toFile().apply {
            deleteOnExit()
        }
        val tmpFilePath = FileSystems.getDefault().getPath(tmpDir.absolutePath, name)
        resource.openStream().use { Files.copy(it, tmpFilePath) }
        System.load(tmpFilePath.toString())
    }

    private enum class SystemType {
        Windows, MacOS, Linux, Other
    }

    class UnsupportedPlatform(system: String, architecture: String) :
        RuntimeException("Unsupported platfrom $system:$architecture")

    class UnknownOS : RuntimeException("Failed to fetch OS name")

    private fun getLibPath(system: SystemType, architecture: String, name: String): String {
        return when (system) {
            SystemType.MacOS -> "/darwin/$name.dylib"
            SystemType.Linux -> "/linux/$architecture/$name.so"
            else -> throw UnsupportedPlatform(operatingSystem.name, architecture)
        }
    }
}
