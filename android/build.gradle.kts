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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val configureAction = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val namespace = getNamespace.invoke(android)
                if (namespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val groupStr = project.group.toString()
                    val fallbackNamespace = if (groupStr.isNotEmpty()) groupStr else "com.example.${project.name.replace("-", "_")}"
                    setNamespace.invoke(android, fallbackNamespace)
                }
            } catch (e: Exception) {
                // Ignore if method not found or throws
            }
        }
    }

    if (state.executed) {
        configureAction()
    } else {
        afterEvaluate {
            configureAction()
        }
    }
}
