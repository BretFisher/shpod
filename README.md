# shpod

[![Docker Build](https://github.com/BretFisher/shpod/actions/workflows/call-docker-build.yaml/badge.svg)](https://github.com/BretFisher/shpod/actions/workflows/call-docker-build.yaml)

**TL,DR:** `curl https://k8smastery.com/shpod.sh | sh`

Thanks to [@jpetazzo](https://github.com/jpetazzo) for this fantastic open source!

## What's this?

`shpod` is a container image based on the Alpine distribution and includes a bunch of tools useful when working with containers,
Docker, and Kubernetes.

It includes:

- ab (ApacheBench)
- bash
- crane
- curl
- Docker CLI
- Docker Compose
- envsubst
- git
- Helm
- jid
- jq
- kubectl
- kubectx + kubens
- kube-linter
- kube-ps1
- kubeseal
- kustomize
- ngrok
- popeye
- regctl
- ship
- skaffold
- skopeo
- SSH
- stern
- tilt
- tmux
- yq

It also includes completion for most of these tools.

Its goal is to provide a normalized environment, to go
with the training materials at [kubernetesmastery.com](https://kubernetesmastery.com),
so that you can get all the tools you need regardless
of your exact Kubernetes setup.

To use it, you need a Kubernetes cluster. You can use Minikube,
microk8s, Docker Desktop, AKS, EKS, GKE, or anything you like.

If it runs with a pseudo-terminal, it will spawn a shell, and you
can attach to that shell. If it runs without a pseudo-terminal,
it will start an SSH server, and you can connect to that SSH
server to obtain the shell.

## Using with a pseudo-terminal

Run it in a Pod and attach directly to it:

```bash
kubectl run shpod --restart=Never --rm -it --image=bretfisher/shpod
```

This should give you a shell in a pod, with all the tools installed.
Most Kubernetes commands won't work (you will get permission errors)
until you create an appropriate RoleBinding or ClusterRoleBinding
(see below for details).

## Using without a pseudo-terminal

Run as a Pod (or Deployment), then expose (or port-forward) to port
22 in that Pod, and connect with an SSH client:

```bash
kubectl run shpod --image=bretfisher/shpod
kubectl wait pod shpod --for=condition=ready
kubectl port-forward pod/shpod 2222:22
ssh -l k8s -p 2222 localhost # the default password is "k8s"
```

Note: you can change the password by setting the `PASSWORD`
environment variable.

## Granting permissions

By default, shpod uses the ServiceAccount of the Pod that it's
running in; and by default (on most clusters) that ServiceAccount
won't have much permissions, meaning that you will get errors like
the following one:

```bash
$ kubectl get pods
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" cannot list resource "pods" in API group "" in the namespace "default"
```

If you want to use Kubernetes commands within shpod, you need
to give permissions to that ServiceAccount.

Assuming that you are running shpod in the `default` namespace
and with the `default` ServiceAccount, you can run the following
command to give `cluster-admin` privileges (=all privileges) to
the commands running in shpod:

```bash
kubectl create clusterrolebinding shpod \
        --clusterrole=shpod \
        --serviceaccount=default:default
```

You can also use the one-liner below.

## One-liner usage

The [shpod.sh](shpod.sh) script will:

- apply the [shpod.yaml](shpod.yaml) manifest to your cluster,
- wait for the pod `shpod` to be ready,
- attach to that pod,
- delete resources created by the manifest when you exit the pod.

The manifest will:

- create the `shpod` Namespace,
- create the `shpod` ServiceAccount in that Namespace,
- create the `shpod` ClusterRoleBinding giving `cluster-admin`
  privileges to that ServiceAccount,
- create a Pod named `shpod`, using that ServiceAccount, with
  a terminal (so that you can attach to that Pod and get a shell).

To execute it:

```bash
curl https://k8smastery.com/shpod.sh | sh
```

(Note: It used to be available at shpod.sh and shpod.me, but these
became pretty expensive so I decided to drop them. If you were using
them and want something fast to type, switch to shpod.in!)

If you don't like `curl|sh`, and/or if you want to execute things
step by step, check the next section.

## Step-by-step usage

1. Deploy the shpod pod:

   ```bash
   kubectl apply -f https://k8smastery.com/shpod.yaml
   ```

2. Attach to the shpod pod:

   ```bash
   kubectl attach --namespace=shpod -ti shpod
   ```

3. Enjoy!

## Clean up

If you are using the shell script above, when you exit shpod,
the script will delete the resources that were created.

If you want to delete the resources manually, you can use
`kubectl delete -f shpod.yaml`, or delete the namespace `shpod`
and the ClusterRoleBinding with the same name:

```bash
kubectl delete clusterrolebinding,ns shpod
```

## Opening multiple sessions

Shpod tries to detect if it is already running; and if it's the case,
it will try to start another process using `kubectl exec`. Note that
if the first shpod process exits, Kubernetes will terminate all the
other processes.

## Special handling of kubeconfig

If you have a ConfigMap named `kubeconfig` in the Namespace
where shpod is running, it will extract the first file from
that ConfigMap and use it to populate `~/.kube/config`.

This lets you inject a custom kubeconfig file into shpod.

## Multi-arch support

Shpod supports both Intel and ARM 64 bits architectures. The Dockerfile
in this repository should be able to support other architectures fairly
easily. If a given tool isn't available on the target architecture,
a dummy placeholder will be installed instead.
