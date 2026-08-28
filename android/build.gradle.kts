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

    // device_apps 2.2.0 is abandoned (2022) and predates AGP 8: no `namespace`,
    // compileSdk 30, minSdk 16. Patched here rather than in the pub cache, which
    // `flutter pub get` overwrites. A missing namespace is the marker for such a
    // plugin, so nothing that already builds is touched.
    // Registered from the root script so it runs before AGP's own afterEvaluate.
    // The line above force-evaluates `:app` on the first pass of this loop, so `:app`
    // is already evaluated when the loop reaches it -- skip it, it needs no fixup.
    if (!state.executed) {
        afterEvaluate {
            val legacy = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (legacy != null && legacy.namespace == null) {
                legacy.namespace = project.group.toString()
                legacy.compileSdkVersion(36)
                val app = project(":app").extensions.findByName("android")
                    as? com.android.build.gradle.BaseExtension
                app?.defaultConfig?.minSdk?.let { legacy.defaultConfig.minSdk = it }
            }

            // home_widget 0.9.3 still hard-codes Kotlin jvmTarget 1.8 in its own
            // android/build.gradle, but ships work-runtime-ktx/coroutines versions
            // built for JVM 11+, so its own Kotlin source fails to inline their
            // bytecode ("Cannot inline bytecode built with JVM target 11..."). It
            // resolves its OWN Kotlin Gradle Plugin via a private legacy buildscript
            // block, so its task types aren't the same class as ours -- use
            // reflection on the task's own `kotlinOptions`/`compilerOptions` rather
            // than a typed cast, so this works regardless of which Kotlin Gradle
            // Plugin version that module ends up applying.
            if (project.name == "home_widget") {
                legacy?.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                tasks.matching { it.name.startsWith("compile") && it.name.endsWith("Kotlin") }
                    .configureEach {
                        try {
                            val kotlinOptions = javaClass.getMethod("getKotlinOptions").invoke(this)
                            kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                                .invoke(kotlinOptions, "17")
                        } catch (_: ReflectiveOperationException) {
                            // Newer Kotlin Gradle Plugin (2.0+) dropped kotlinOptions for
                            // compilerOptions.jvmTarget -- not home_widget's case today.
                        }
                    }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

