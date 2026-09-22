allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// google_sign_in_android ships Kotlin helpers (ResultUtils.kt) used from Java, but its
// Gradle script assumes AGP 9 built-in Kotlin and does not apply kotlin-android.
// With android.builtInKotlin=false (required until video_compress migrates), force
// the Kotlin Android plugin onto library modules that have Kotlin sources.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val hasKotlinSources = file("src/main/kotlin").exists()
        val hasKotlinPlugin =
            pluginManager.hasPlugin("org.jetbrains.kotlin.android") ||
                pluginManager.hasPlugin("kotlin-android")
        if (hasKotlinSources && !hasKotlinPlugin) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
