buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Google Services
        classpath("com.google.gms:google-services:4.3.15")
        // Gradle plugin de Android
        classpath("com.android.tools.build:gradle:8.1.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirigir build directories a un folder común
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Desugaring para Java 8+ (necesario para flutter_local_notifications)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
