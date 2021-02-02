# Prerequisites
- K3D
- Helm
- kubectl

# Test
``` shell
$ make k3d-up
mkdir -p .k3d-volumes
k3d cluster create nfs-test --volume $(pwd)/.k3d-volumes:/data
WARN[0000] No node filter specified
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-nfs-test'
INFO[0000] Created volume 'k3d-nfs-test-images'
INFO[0001] Creating node 'k3d-nfs-test-server-0'
INFO[0001] Creating LoadBalancer 'k3d-nfs-test-serverlb'
INFO[0001] Starting cluster 'nfs-test'
INFO[0001] Starting Node 'k3d-nfs-test-server-0'
INFO[0006] Starting Node 'k3d-nfs-test-serverlb'
INFO[0006] (Optional) Trying to get IP of the docker host and inject it into the cluster as 'host.k3d.internal' for easy access
INFO[0009] Successfully added host record to /etc/hosts in 2/2 nodes and to the CoreDNS ConfigMap
INFO[0009] Cluster 'nfs-test' created successfully!
INFO[0009] --kubeconfig-update-default=false --> sets --kubeconfig-switch-context=false
INFO[0010] You can now use it like this:
kubectl config use-context k3d-nfs-test
kubectl cluster-info

$ make nfs-deploy
helm install nfs stable/nfs-server-provisioner -f nfs-values.yaml
WARNING: This chart is deprecated
NAME: nfs
LAST DEPLOYED: Tue Feb  2 12:38:52 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The NFS Provisioner service has now been installed.

A storage class named 'nfs' has now been created
and is available to provision dynamic volumes.

You can use this storageclass by creating a `PersistentVolumeClaim` with the
correct storageClassName attribute. For example:

    ---
    kind: PersistentVolumeClaim
    apiVersion: v1
    metadata:
      name: test-dynamic-volume-claim
    spec:
      storageClassName: "nfs"
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 100Mi

## NFS Pod is pending as PVC is pending (missing PV)...
$ kubectl get pods
NAME    READY   STATUS    RESTARTS   AGE
nfs-0   0/1     Pending   0          30s

$ kubectl get pvc
NAME         STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-nfs-0   Pending                                                     33s 

## Create PV for NFS (using HostPath...)
$ make pv-create
kubectl apply -f pv-for-nfs.yaml
persistentvolume/nfs-pv-0 created

## Now PVC gets bound to PV
$ kubectl get pvc
NAME         STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-nfs-0   Bound    nfs-pv-0   200Mi      RWX                           91s

## and the nfs-0 pod is running
$ kubectl get pods
NAME    READY   STATUS    RESTARTS   AGE
nfs-0   1/1     Running   0          2m21s

$ kubectl describe pod/echo-87585c776-hh225
Name:           echo-87585c776-hh225
...
Containers:
  echo:
    Container ID:  
    Image:         busybox
    State:          Waiting
      Reason:       ContainerCreating
    Ready:          False
    Mounts:
      /data from nfs-mount (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-jg6rg (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  nfs-mount:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  nfs-for-pods
    ReadOnly:   false
Events:
  Type     Reason            Age              From               Message
  ----     ------            ----             ----               -------
  Warning  FailedScheduling  13s              default-scheduler  0/1 nodes are available: 1 pod has unbound immediate PersistentVolumeClaims.
  Normal   Scheduled         4s               default-scheduler  Successfully assigned default/echo-87585c776-hh225 to k3d-nfs-test-server-0
  Warning  FailedMount       0s (x4 over 4s)  kubelet            MountVolume.SetUp failed for volume "pvc-f43cdc20-6364-4105-98e5-a8760e180de5" : mount failed: exit status 255
Mounting command: mount
Mounting arguments: -t nfs -o vers=3 10.43.102.15:/export/pvc-f43cdc20-6364-4105-98e5-a8760e180de5 /var/lib/kubelet/pods/e04be839-faaf-4386-81ed-8251a392baf7/volumes/kubernetes.io~nfs/pvc-f43cdc20-6364-4105-98e5-a8760e180de5
Output: mount: mounting 10.43.102.15:/export/pvc-f43cdc20-6364-4105-98e5-a8760e180de5 on /var/lib/kubelet/pods/e04be839-faaf-4386-81ed-8251a392baf7/volumes/kubernetes.io~nfs/pvc-f43cdc20-6364-4105-98e5-a8760e180de5 failed: Connection refused
```


