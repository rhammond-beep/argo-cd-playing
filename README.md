# argo-cd-playing
This is a testground repo while a get to grips with the tooling

All Notes about the functioning, mantainence, theoritcal and practical concepts relating to Argo CD go here!

## [A Crash Course Introduction](https://www.youtube.com/watch?v=MeU5_k9ssrs)

This section provides a high level descrption which explains the difference between ArgoCD and some other CI tool such as Jenkins 
or GitlabCI

ArgoCD is fundamentally a CD tool, which means that it automates proviosning of infra changes to a kuberenetes cluster without manual intervention.

Jenkins CI is designed to work with application code repositories, monitoring them for changes on specific branches.

When changes are detected, the a "Constant Integration" Pipeline will run, usually this consists of building the code, running tests and 
any other automated process bespoke to process needs, before a new docker image is built with the commit hash and pushed to an elastic container 
registry.

This is fundamentally a separate process to actually deploying the new container to a target environment. When using something like say, k8s, you would then go
to your deployment yaml file for the coorresponding service and change the "image" key pair value to coorrespond to the newly generated image tag.

We can think of the CD part as a natural continuation of the application software to it's final destination (usually some development or production server)

It was purposegully built for k8s!!

So how does it make the CD process more efficient?

Reverse the flow: (Pull, not push!)

ArgoCD gets deployed to the cluster, then set it to watch a given infrastructure repo

supports plain manifest files and helm.

This whole process is referred to as a "Git Ops" repository.

### Benefits of Argo CD

Everything is defined as code from one fundamental source of truth.

ArgoCD looks for delta's in both directions. I:E if someone makes manual changes in the cluster ArgoCD will capture that.

Anything that's done manually will get overriden by the config in the git. Garranting it as a source of truth.

This property can be overriden if necessary.

I:E git becomes the single point of integration between the cluster and developers. Giving all the advatages associated with version control
(Easy rollback and version management)

Contorl access to git repo as a way of managing who can provision changes to infrastructure.

Can think of ArgoCD as an extension of hte k8s API:
    - Uses existing k8s functionality
    - This enables much greater Visibility of the cluster.

