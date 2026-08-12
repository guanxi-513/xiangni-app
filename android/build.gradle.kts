allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ── 全局强制所有 Flutter 插件使用 compileSdk = 36 ──
subprojects {
    afterEvaluate {
        try {
            val libExt = this.extensions.getByType<com.android.build.gradle.LibraryExtension>()
            libExt.compileSdk = 36
        } catch (_: Exception) {
            // 非 library 项目忽略
        }
    }
}

// ── 禁用 AAR metadata 检查（解决旧插件 compileSdk 不兼容问题）──
subprojects {
    afterEvaluate {
        // 禁用所有 AarMetadata 相关检查任务
        tasks.matching { it.name.contains("AarMetadata") || it.name.contains("aarMetadata") }.configureEach {
            enabled = false
        }
        
        // 创建所有可能缺失的 aar_metadata_check 子目录
        val aarMetaDir = project.layout.buildDirectory.dir("intermediates/aar_metadata_check")
        val variants = listOf("release", "debug")
        val tasks = listOf("checkReleaseAarMetadata", "checkDebugAarMetadata")
        for ((variant, task) in variants.zip(tasks)) {
            try {
                aarMetaDir.get().dir(variant).dir(task).asFile.mkdirs()
            } catch (_: Exception) {
            }
        }
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
