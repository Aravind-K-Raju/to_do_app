allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.evaluationDependsOn(":app")

    // Only redirect the :app module's build directory.
    // Plugin subprojects keep their default build dirs to avoid cross-drive path issues.
    if (project.name == "app") {
        project.layout.buildDirectory.value(newBuildDir.dir(project.name))
    }

    // Dynamically align Kotlin's JVM target with Java compatibility settings lazily during task configuration
    // to bypass Gradle evaluation lifecycle finalization restrictions
    project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        var targetCompat = "1.8"
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val target = compileOptions.javaClass.getMethod("getTargetCompatibility").invoke(compileOptions)
                if (target != null) {
                    targetCompat = target.toString()
                }
            } catch (e: Exception) {
                // Clean fallback to "1.8" if reflection fails or property is null
            }
        }
        kotlinOptions {
            jvmTarget = targetCompat
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
