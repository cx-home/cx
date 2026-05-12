plugins {
    kotlin("jvm") version "2.3.20"
    application
}

group = "io.cxhome"
version = "0.6.0"

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
    }
}

application {
    mainClass.set("cx.examples.TransformKt")
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("net.java.dev.jna:jna:5.14.0")
    implementation("com.google.code.gson:gson:2.10.1")
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}

tasks.test {
    useJUnitPlatform()
}

tasks.register<JavaExec>("benchTime") {
    classpath = sourceSets.main.get().runtimeClasspath
    mainClass.set("cx.BenchTime")
}

tasks.register<JavaExec>("demo") {
    dependsOn("classes")
    classpath = sourceSets.main.get().runtimeClasspath
    mainClass.set("cx.DemoKt")
}

// ── Apache Arrow C-Data interop binding (Phase 7.74c-cont-bindings-multi-kotlin) ──
//
// Optional source-set under `src/arrow/kotlin` + `src/arrowTest/kotlin`,
// gated behind libcx_arrow + the arrow-c-data / arrow-vector JARs.
// Default `gradle assemble` and `gradle test` do NOT compile this source
// set, so they do not require arrow-c-data on the classpath. Mirrors
// Go's `-tags arrow`, Rust's `--features arrow`, Python's
// `cxlib[arrow]`, C#'s separate `cxlib_arrow.csproj` assembly, and
// Java's `-Parrow` Maven profile.
//
// Build: `gradle compileArrowKotlin`  (or `make build-kotlin-arrow`)
// Test:  `gradle arrowTest`           (or `make test-kotlin-arrow`)
val arrowVersion = "17.0.0"

sourceSets {
    create("arrow") {
        compileClasspath += sourceSets["main"].output
        runtimeClasspath += sourceSets["main"].output
    }
    create("arrowTest") {
        compileClasspath += sourceSets["main"].output + sourceSets["arrow"].output
        runtimeClasspath += sourceSets["main"].output + sourceSets["arrow"].output
    }
}

kotlin {
    sourceSets["arrow"].kotlin.srcDir("src/arrow/kotlin")
    sourceSets["arrowTest"].kotlin.srcDir("src/arrowTest/kotlin")
}

configurations {
    named("arrowImplementation")     { extendsFrom(configurations["implementation"]) }
    named("arrowRuntimeOnly")        { extendsFrom(configurations["runtimeOnly"]) }
    named("arrowTestImplementation") { extendsFrom(configurations["testImplementation"]) }
    named("arrowTestRuntimeOnly")    { extendsFrom(configurations["testRuntimeOnly"]) }
}

dependencies {
    "arrowImplementation"("org.apache.arrow:arrow-c-data:$arrowVersion")
    "arrowImplementation"("org.apache.arrow:arrow-vector:$arrowVersion")
    "arrowRuntimeOnly"   ("org.apache.arrow:arrow-memory-netty:$arrowVersion")

    "arrowTestImplementation"("org.junit.jupiter:junit-jupiter:5.10.0")
    "arrowTestImplementation"("org.apache.arrow:arrow-c-data:$arrowVersion")
    "arrowTestImplementation"("org.apache.arrow:arrow-vector:$arrowVersion")
    "arrowTestRuntimeOnly"   ("org.apache.arrow:arrow-memory-netty:$arrowVersion")
}

// Arrow Java needs add-opens for java.nio plus the netty reflection trick on JDK 17+.
val arrowJvmArgs = listOf(
    "--add-opens=java.base/java.nio=ALL-UNNAMED",
    "-Dio.netty.tryReflectionSetAccessible=true",
)

tasks.register<Test>("arrowTest") {
    description = "Runs Apache Arrow C-Data interop tests for cx.Arrow."
    group = "verification"
    testClassesDirs = sourceSets["arrowTest"].output.classesDirs
    classpath = sourceSets["arrowTest"].runtimeClasspath
    useJUnitPlatform()
    jvmArgs(arrowJvmArgs)
    shouldRunAfter("test")
}
