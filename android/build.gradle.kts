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

    project.plugins.withId("com.android.library") {
        val androidExtension = project.extensions.getByName("android")
                as com.android.build.gradle.LibraryExtension
        androidExtension.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }

    project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
