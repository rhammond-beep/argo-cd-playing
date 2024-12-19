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

## RBAC Roles Policy Provisioning/Configuration

- So it seems like the default readonly policy just get applied to everyone and you cannont 
take away whatever policies have been specified in the default, hence we should probably define something very restrictive and then 
layer permissions on top of that, a straight quote from the documentation:

 ```
Restricting Default Permissions

All authenticated users get at least the permissions granted by the default policies. This access cannot be blocked by a deny rule. It is recommended to create a new role:authenticated with the minimum set of permissions possible, then grant permissions to individual roles as needed.

```
I've added in a default "authenticated" role which contains a smaller set of readonly permissions than what comes out of the box.

This also means that the given users in question can't see other user accounts.

So on the journey to figure out how to get this webshell working, I've stumbled into the "Role" resource, this is an element of k8s which
I am fundamentally unaware of, so we'll be runinng down this road.

I think the problem is that the argocd service doesn't have the correct permission to go into the namespace and exec into pods, it can only 
do that with pods running in it's own namespace. 

## [k8s Reading](https://kubernetes.io/docs/concepts/overview/) - Might as well start at the beginning here

Kubernetes is a portable, extensible, open source platform for managing containerised workloads and serviecs, that facilitates both declarative configuration and automation. 

The name Kuberenetes originates form Greek, meaning helmsman or pilot.

Why we need k8s:

1) Service discovery and load balancing
2) Storage orchestration 
3) Automated rollout and rollbacks 
4) Automated Bin Packing
5) Self-healing
6) Secret and configuration management
7) Batch execution 
8) Horizontal Scaling
9) IPv4 and IPv6 Dual stack

### Objects 

k8s objects are persistent entities in the kubernetes sustem. k8s uses these entities to represent the state of your cluster.
Specifically they can describe:

1) What contarised applications are running (and on what nodes)
2) The resources avaliable to those applications
3) The policies around how those applications behave, such as restart policies, upgrades and fault-tolerance

A k8s object is a "record of intent". Once you have ordered that an object should exist (through some declarative specification to the control plane)
the k8s system will work to ensure that such an object exists (to run the gap between actual and desired state)

To work with k8s objects, we use the Kuberenetes API; the core element of the control plane.

In k8s, a "Deployment" is an object that represents an application running on our cluster. When such a deployment is created, you might choose to set the `spec` to specify that three pod replicas of the application will run at a given time. 

When you create a k8s object, you must provide the objecct spec that describes it's desired state (the fields pertaining to each spec can and do vary), 
as well as some general metadata about the object such as it's name. 

#### Controllers

Controllers are control loops that watch the state of the cluster, then make or request changes where needed. Each controller tries to move the current 
state towards the desired state.

A controller tracks at least one k8s resource type; in it's mission to improve the state of a cluster by reponsding to internal or external signals (routed through 
the k8s API), a controller might carry out some action itself. More commonly however, a controller will send messages to the API server that have nice side-effects. 

The Job controller is an example of a built in controller. Built-in controllers manage state by interacting with the cluster API server.

As a tenent of its design, Kubernetes uses lots of controllers that each manage some definitive aspect of cluster state. More commonly, a particular control loop 
(controller) uses one kind of resource as its desired state, and has different kind of resource that it manages to make that desired state happen. For example, a cotroller for "jobs" tracks Job objects (to discover new work) and Pod objects (to run the jobs, and then to see when the work is finished). In this case something else creates the Jobs, the Job controller creates Pods.

It tends to be more useful to have many smaller, simpler controllers rather one, monolithic set of control loops that are inter-linked. Controllers can fail, so k8s is designed to account for this.

There can be several controllers that create or update the same kind of object. Behind the scenes, kuberenetes controllers make sure that they only pay attention to the resources linked to their controlling resource.

As an example: Can have Deployments and Jobs; these both will create Pods. The Job controller does not delete the Pods that your Deployment created, because there is information (labels) the controllers can use to tell those pods apart.


## Service Accounts

A service account is a type of non-human account that, in k8s, provides a distinct identity within a kubernetes cluster.
Application Pods, system components and entities inside and outside the cluster can use a specific ServiceAccounts' credentials to identify as that ServiceAccount. This identity is useful in a varierty of situations, including authenticating to the API server or implementing identity-based security policies. 

Service accounts are:

- Namespaced
- Lightweight 
- Portable 

User accounts are authenticated human users in the cluster; service accounts are inherintly different given that they represent an underlying machine/automated entity wishing to perform some action.

When you create a cluster, Kuberenetes automatically creates a ServiceAccount object named "default" for every namespace in your cluster. The default service accounts in each namespace gets no permissions by default other than the default API discovery permissions that k8s grants to alll authenticated principles if RBAC is enabled. 

If you deploy a pod in a namespace, and you don't manually assign a ServiceAccount to the pods, k8s will assign the default ServiceACcount for the namespace to the pod.

Use Cases:

As a general guideline, you can use service accounts to provide identities in the following scenarios:

1) Your pods need ot comunicate with the k8s API server, for example:
    - you're running ArgoCD within your cluster to manage deploying images as part of a gitops Continous delivery pipeline 
        the pod running the argocd service will need to talk to the k8s API to schedule jobs provisioning new resources or editing existing deploymnets/services/Any 
        k8s object for which the upstream repostiory ArgoCD is tasked with deploying.
    - Granting cross-namespace access, such as allowing a Pod in namespace "example" to read, list and watch for Lease objects in the kube-node-lease namespace.
    - Pods need to communicate with some external service. 
    - Authenticating a private image registry 

To use a k8s service account, do the following:
1) create a ServiceAccount Object using kubectl or a manifest that defines the object
2) grant permissions to the ServiceAccount object using an authorization mechanism such as RBAC
3) Assign the ServiceAccount object to Pods during the Pod creation

It looks like I might have to read through the following articles to get more of an idea of what I need/don't need:
    1) [Configure Service Account for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
    2) [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) 

It ended up being easy, all I had to do was edit the clusterRole resource with `kubectl edit clusterRole argocd-server`, 
adding in the following attributes:

```
- apiGroups:
  - ""
  resources:
  - pods/exec
  verbs:
  - create
```
Assuming the exec.enabled: "true" is present in the config map resource, we are chilling!!

So what is a cluster role then - a non-namespaced resource!! As I thought, so this role is avaliable across namespaces and clusters!!

## SSO approach

- Can Connect to Authentication provider using OpenID Connect. <- What we want Dex is a tool used to integrate with protocols which don't natively support OIDC
- The way this is configured is using a ConfigMap in ArgoCD (We can just add in the settings for the existing one)
- will need to read the [integration-article](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#existing-oidc-provider) at some stage today 

Initially going through an old way of doing it using Dex - *DEX IS NOT SUPPORTED*

Define RBAC roles within an actual project manifest, is this something that we acutally need to do? I wouldn't have thought so.
We either want to grant readonly access to all cross-project applications, or admin access.

It's cool that we can define AppProject as a resource type to apply into ArgoCD, from which point you can define policies as an attribute on the project. Presumably these privilages are addative on top of whatever we define in the global RBAC config map?

Requesting Additional ID token clamins 

- Not all OIDC providers support a special "groups" scope: Microsoft being one of those providers; I:E - will return group membership with the default requestedScopes

Retrieving Groups when not in the token:

Some ODIC providers don't return the group information for a user in the ID token, even if explicitly request using the "requestedIDTokenClamins setting (Okta for example). Conversely, they provide the groups on the user info endpoint. With the groups on the userinfo endpoint instead. With the following config. ArgoCD queries the user info endpoint during login for group information for a user:

```
oidc.config | 
    enableUserInfoGroups: true
    userInforPath: /userInfo
    userInforCacheExpiration: "15m"
```
As a nice little side bonus, we can also configure a custom logout URL for our OIDC provider:

Optionally, if our OIDC provider exposes a logout API and we wish to configure a custom logout URL for the purposes of invalidating any active session post logout, you can do so by specifying it as follows:

```
  oidc.config: |
    name: example-OIDC-provider
    issuer: https://example-OIDC-provider.example.com
    clientID: xxxxxxxxx
    clientSecret: xxxxxxxxx
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims: {"groups": {"essential": true}}
    logoutURL: https://example-OIDC-provider.example.com/logout?id_token_hint={{token}}
```

*Will need to check this with Mike to see if we acutally need this*

## [Okta Dev on OAuth2 and OpenID Connect Protocols](https://www.youtube.com/watch?v=996OiexHze0&ab_channel=OktaDev)

Could use with a refresh on OIDC, so taking one now with Nate on the good old 1.5x speed.

Single sign on across sites can be implemeneted with a protocol called SAML. (One master account across multiple sites), 
This seems like it was the prominent way of solving the problem before OIDC connect standard and implementations became avaliable.

OAuth-flow is really good at solving the delegated authorization problem! Some app wants to access data on your behalf, You as the resource
owner can specify a set of scopes which define what exactly the 3rd party app can do on your behalf. 

The most common kind of flow here would be the authorization code flow. It's also pretty secure and can be broken down as follows:

1) user goes to login to a given app.
2) they choose an option such as "sign in with google, miscrosoft, github account etc..."
3) Prompt the user with what permissions the app requires (access to email address, contacts etc...)
4) User accepts which then informs the information the 3rd party app goes to the IP provider with.
5) User is re-directed to the 3rd party site to login (sometimes, depending on the IP policy, a login can be cached for a very long time, so might not need to login for some time)
6) After user has logged in, call the provided callback URL with an authorisation code. 
7) 3rd party app then uses the authorization code to talk to the upstream IP server to then get a JWT token with the claims dispensed. This token is signed by the IP/Authorization Server so if it is tampered with to add extra claims, the signature will be invalid and the IP will reject an attempted operation.
8) I believe code exchange is done on the backchannel (so the browser can't see, I:E no maclicious code can try and nab the code and get the token before 3rd party ap can perform the desired transaction)

Oauth2 seems to be the primary protocol to perform delegated authorization. 

OAuth2 was never designed for authentication! Problems with the protocol:

1) No standardised way of getting the user's information
2) Every implementation is different (lack of standard approach)
3) No common set of scopes.

Oauth 2.0 terminology:

- Resource Owner: The person who owns the data in which the 3rd party app is trying to get access to
- Client: The 3rd party app
- Authorization Server: The stateful server which Implements the OAuth2 flow 
- Resource Server: The server containing the protected resources in which the client wants a valid claim to access
- Authorization grant: The set of things the client is allowed to do
- Redirect URI: Where to redirect to on success login (Usually points back to some URL within the client domain)
- Access Token: The token containing a list of clamins regarding who the client it and what it's allowed to do. (Encodes this information into the request being made to the resource server)


In our case Azure SSO is being used primarily the authentication mechanism; we can think of this as the "Authentication and Authorization Server" in which OAuth2 flows are argumented to perform. In the context of our usecase, ArgoCD knows how the policies assigned to the groups in which the user is derrived from, needs to be applied. Fundamentally Azure Performs the functionality of Authentication, I:E confirming that the user is who they say they are in the form of a JWT token, and authorization, by also providing the groups either through the userInfo endpoint or as directly part of the token. But then ArgoCD understands what the user can do with those authenticated claims (The set of allows actions to perform with ArgoCD). This leads us to an interesting problem: What is the authorization server in this case? Based on my above definition it must be Azure OpenID service.

- I believe that purposes ArgoCD is the Resource Server. Because that's the thing the client (in this case you, me or someone on the engineering team's web-browser, that is going to get access to the ArgoCD platform) and we configure what policies are applied to specific groups on ArgoCD as well. Azure SSO just verfies that the user is who they say they are, and dispenses what they can do in the form of groups, ArgoCD will figure out based on the groups they belong to, what exactly they can do.

OpenID Connect is for authentication! As I thought - Small layer on top of OAuth 2 Adding:

1) ID Token
2) UserInfo endpoint for getting more user info
3) Standarised set of scopes
4) Standarised implementation.

