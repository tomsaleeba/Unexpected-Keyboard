package Testy.buildTypes

import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.script

object asdf : BuildType({
    id = AbsoluteId("asdf")
    name = "somestep"

    steps {
        script {
            scriptContent = """
                set -x
                ls
                pwd
                which make
                make
            """.trimIndent()
            dockerImage = "circleci/android:api-30"
        }
    }
})

