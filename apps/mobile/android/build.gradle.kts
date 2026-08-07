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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "irondash_engine_context" || name == "super_native_extensions") {
        afterEvaluate {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                // These released plugins still declare API 31, while their
                // current AndroidX dependencies require API 34 or newer.
                // Compile them against the app's installed SDK without
                // changing the application's minimum supported Android API.
                compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
