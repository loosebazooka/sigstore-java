import org.gradle.api.publish.internal.PublicationInternal

plugins {
    id("build-logic.repositories")
    id("build-logic.java-library")
    id("build-logic.reproducible-builds")
    id("build-logic.publish-to-central")
    id("build-logic.signing")
}

java {
    withJavadocJar()
    withSourcesJar()
}

val localReleaseStagingRepository = layout.buildDirectory.dir("localReleaseStaging")

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
        }
    }

    repositories {
        maven {
            name = "localReleaseStaging"
            url = uri(localReleaseStagingRepository)
        }
    }
}

signing.sign(publishing.publications["mavenJava"])

val createReleaseBundle by tasks.registering(Sync::class) {
    description = "This task should be used by github actions to create release artifacts along with a slsa attestation"
    val releaseDir = layout.buildDirectory.dir("release")
    outputs.dir(releaseDir)

    from(localReleaseStagingRepository) {
        include("**/${project.version}/${project.name}-${project.version}*")
        exclude("**/*.sigstore.asc*")
        eachFile {
            path = name
        }
        includeEmptyDirs = false
    }

    into(releaseDir)

    dependsOn(tasks.named("publishMavenJavaPublicationToLocalReleaseStagingRepository"))
}
