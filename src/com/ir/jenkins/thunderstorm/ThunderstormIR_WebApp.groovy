package com.ir.jenkins.thunderstorm

import com.nu.art.pipeline.modules.SlackModule
import com.nu.art.pipeline.modules.docker.DockerModule
import com.nu.art.pipeline.modules.git.GitModule
import com.nu.art.pipeline.thunderstorm.Pipeline_ThunderstormWebApp
import com.nu.art.pipeline.workflow.WorkflowModule
import com.nu.art.pipeline.workflow.variables.Var_Creds
import com.nu.art.pipeline.workflow.variables.Var_Env

class ThunderstormIR_WebApp<T extends ThunderstormIR_WebApp>
        extends Pipeline_ThunderstormWebApp<T> {

    public Var_Env Env_Branch = new Var_Env("BRANCH_NAME")
    public Var_Env Env_RegisterToken = new Var_Env("REGISTER_TOKEN")
    public Var_Creds Creds_RegisterToken = new Var_Creds("string", "google_function_register_token", Env_RegisterToken)

    String httpUrl
    String gitRepoUri
    def envProjects = [:]

    ThunderstormIR_WebApp(String name, Class<? extends WorkflowModule>... modules) {
        super(name, modules)
    }

    @Override
    protected void init() {
        String branch = Env_Branch.get()
        getModule(SlackModule.class).prepare()
        getModule(SlackModule.class).setDefaultChannel("backend")

        setRequiredCredentials(Creds_RegisterToken)
        setRepo(getModule(GitModule.class)
                .create(gitRepoUri)
                .setBranch(branch)
                .build())

        setDocker(getModule(DockerModule.class)
                .create("eu.gcr.io/ir-infrastructure-246111/jenkins-ci-python-env", "13-12-23-07h-14m")
                .build())

        String links = ("" +
                "<https://${envProjects.get(branch)}.firebaseapp.com|WebApp> | " +
                "<https://console.firebase.js.google.com/project/${envProjects.get(branch)}|Firebase> | " +
                "<${this.httpUrl}|Github>").toString()

        getModule(SlackModule.class).setOnSuccess(links)

        setEnv(branch)
    }

    void setGitRepoId(String repoId) {
        this.httpUrl = "https://github.com/${repoId}".toString()
        this.gitRepoUri = "git@github.com:${repoId}.git".toString()
    }

    void declareEnv(String env, String projectId) {
        envProjects.put(env, projectId)
    }

    @Override
    void pipeline() {
        String branch = Env_Branch.get()

        checkout({
            getModule(SlackModule.class).setOnSuccess(getRepo().getChangeLog().toSlackMessage())
        })
        addStage("Install & Build", { this.installAndBuild() })
		test()

        deploy()

        run("onDeploy", {
            String migrateURL = "https://us-central1-${envProjects.get(branch)}.cloudfunctions.net/ondeploy"
            workflow.sh """curl -H "x-secret: ${Env_RegisterToken.get()}" -H "x-proxy: jenkins-job" ${migrateURL}"""
        })
    }

    void installAndBuild()  {
        _sh("bash build-and-install.sh --set-env=${this.env} -fe=${this.fallEnv} --lint --install --debug")
    }
}
