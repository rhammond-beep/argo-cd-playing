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

### Benefits of ArgoCD

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

### Multi-cluster setup with ArgoCD (Our Setup)

So we have a dedicated ArgoCD cluster which is in charge and responsible for provisioning to the other clusters.

### Running Locally

To initially setup the ARGO CD namespace for a given cluster, simply follow the instructions as presented on official [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd)

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# access ArgoCD UI
kubectl get svc -n argocd
kubectl port-forward svc/argocd-server 8080:443 -n argocd

# login with admin user and below token (as in documentation):
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### Structure of an application.yaml file

An application.yaml file specifies a set of configuration for a service for ArgoCD to monitor, this will usually be 
some meta data pertaining to a git-repository in which the service infrastructure is defined. Here is a brief description of the anatomy of 
an application.yaml file:

repoURL -> the public url in which the service to monitor lives
targetRevision -> the hash corresponding to the commit to checkout and deploy
path -> This is an important one, path defines where to find the given IaC as code definition (usually another application.yaml file, or some
other declarative language) is housed. The benefit of this is we can host many different service specifications within the same repository. (Allowing for one or 
many infrastructure repository definitions) 
    As a sidenote on this, I think all a "service" actually is, is a constant IP which acts as a concrete and unchanging frontdoor to a set of running pods, which are in turn proviosned/managed by a deployment specification. The reason for this, is we should expect that pods are destroyed and created a lot. At which point they are assigned a unique IP address within the cluster. If we have some downstream pods running somewhere else within the cluster; it's essential that they are able to discover the new pods while remaining resiliant to changing IP addresses of the endpoint pods. 

ArgoCD with poll the repository every 3 minutes. If we needed immediate changes, it's possible to configure 
    a webhook for instant results.

syncPolicy -> These set of attributes enables you to configure the synchronisation behaviour of the upsteram service repository 

## Configuring Users and RBAC

Users can be proviosned user the ArgoCD cli, simply run `argocd login <TARGET_INSTANCE>` where target instance is a publically reachable IP address.This will prompt an interactive login from which you will want to login using administrator credentials to ensure that you have the right level of privilage to add and remove users. 

RBAC feaure enables resrictions of access to Argo CD resources. An important thing to note is that ArgoCD does not
have it's own user management system and has only one built-in user, 'admin'. 

- A prerequisite for RBAC is either having SSO or local users configured. 
- Once this is done, additional RBAC roles may be defined, and sso groups or local isers can then be mapped to their roles.

- once installed ArgoCD has one built-in "admin" user that has full access to the entire system.
- Should only use admin for initial configuration.
- Shoud then switch to using either SSO or local user setup depending on usecase.


There are two main components where RBAC configuration can be defined:
    - global config map (argo-rbac-cm.yaml)
    - AppProject's roles

There are two basic built-in Roles:
    - role:readonly 
    - role:admin: unrestricted access to all resources

When checking out the default policy.csv file can see the induvidual policies which have been assigned to the two default groups:
admin and readonly.

    in this project we have two files which configure RBAC policy and users:
    './argocd/argocd-cm.yaml' and './argocd/argocd-rbac.cm.yaml' 

These are both config map resources which needs to be deployed into the given k8s environment. 

### RBAC Model Structure

Group: Enables an ArgoCD admin to assign authenticated users/groups to internal roles.

`Syntax: g,<user/group>, <role>`

- <user/group>: The entity to whom the role will be assigned. It can be a local user or a user authenticated with SSO. 
    when SSO is used, the user will be based on the 'sub' claims, whike the group is one of the values returned by the 
    scoped configuration
- <role>: The internal roles to which the entity will be assigned.

Policy: Assign permissions to a given entity.

`Syntax: p, <role/user/group>, <resource>, <action>, <object>, <effect>`

- <role/user/group>: The entity to whom the policy will be assigned
- <resource>: The type of resource on which the action will be performed
- <action>: The operation that is being performed on the given resource
- <object>: The object identifier representing the resource on which the action is performed. 
            Depending on the resource, the object's format will vary.
-<Effect>: Whether this policy should grant or restrict the operation on the target object (`allow` or `deny`)

Here is an example policy which would grant example-user access to 'get' any applications, but only be able to see logs in 'my-app' application 
as part of the 'example-project' project.

```
p, example-user, applications, get, *, allow
p, example-user, logs, get, example-project/my-app, allow

```

The `update` and `delete` actions,when granted on an application, will allow the user to perform
the operation on the application itself and all of it's resources. 

To do so, when the action if performed on the application's resource, the <action> will have the
`<action>/<group>/<kind>/<ns>/<name>` format

For instance, to grant access to example-user to only have the ability to delete pods in the prod-app Application, the policy could be:

`p, example-user, applications, delete/*/Pod/*/*/, default/prod-app allow`

