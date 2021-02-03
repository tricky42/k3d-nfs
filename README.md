# Prerequisites
- K3D
- Helm
- kubectl

# In Short
I cant get `nfs-server-provisioner` to run in K3D and I dont understand why. When I deploy using the `local-path` provider from K3D to provide the PV for the NFS server, PVCs of storage class `nfs` can be provisioned (status: bound), but still pods trying to 
mount the volume reference by the PVC `nfs-for-pods` are not starting up due to: 
```
MountVolume.SetUp failed for volume "pvc-52c0d57a-b285-45b6-b04c-41175604b0d0" : mount failed: exit status 255 Mounting command: mount Mounting arguments: -t nfs -o vers=3 10.43.192.199:/export/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 /var/lib/kubelet/pods/c9e21798-76ad-404d-b089-c9fff88e0a86/volumes/kubernetes.io~nfs/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 Output: mount: mounting 10.43.192.199:/export/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 on /var/lib/kubelet/pods/c9e21798-76ad-404d-b089-c9fff88e0a86/volumes/kubernetes.io~nfs/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 failed: Connection refused

Unable to attach or mount volumes: unmounted volumes=[nfs-mount], unattached volumes=[nfs-mount default-token-t7qxd]: timed out waiting for the condition
```

To quickly reproduce this, just enter:
```
$ make all
```

# More details...
Below you see the squence of command to set everything up and the detailed output of the `kubectl` commands describing the involved Kubernetes objects...

``` shell
$ make all 
mkdir -p .k3d-volumes
k3d cluster create nfs-test --volume $(pwd)/.k3d-volumes:/data
WARN[0000] No node filter specified                     
INFO[0000] Prep: Network                                
INFO[0000] Network with name 'k3d-nfs-test' already exists with ID '780354d70a372a90d0112719019ec8fa940036ea07c4b5085be5241850d19667' 
INFO[0000] Created volume 'k3d-nfs-test-images'         
INFO[0001] Creating node 'k3d-nfs-test-server-0'        
INFO[0001] Creating LoadBalancer 'k3d-nfs-test-serverlb' 
INFO[0001] Starting cluster 'nfs-test'                  
INFO[0001] Starting Node 'k3d-nfs-test-server-0'        
INFO[0006] Starting Node 'k3d-nfs-test-serverlb'        
INFO[0007] (Optional) Trying to get IP of the docker host and inject it into the cluster as 'host.k3d.internal' for easy access 
INFO[0009] Successfully added host record to /etc/hosts in 2/2 nodes and to the CoreDNS ConfigMap 
INFO[0009] Cluster 'nfs-test' created successfully!     
INFO[0009] --kubeconfig-update-default=false --> sets --kubeconfig-switch-context=false 
INFO[0009] You can now use it like this:                
kubectl config use-context k3d-nfs-test
kubectl cluster-info
helm install nfs stable/nfs-server-provisioner -f nfs-values.yaml
WARNING: This chart is deprecated
NAME: nfs
LAST DEPLOYED: Wed Feb  3 17:11:22 2021
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
kubectl apply -f ./pvc-for-pods.yaml
persistentvolumeclaim/nfs-for-pods created
kubectl apply -f ./deployment-echo.yaml
deployment.apps/echo created

$ kubectl get pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-nfs-0     Bound    pvc-184409e8-30a7-4315-be3d-23c779e6881e   200Mi      RWO            local-path     8m35s
nfs-for-pods   Bound    pvc-52c0d57a-b285-45b6-b04c-41175604b0d0   20Mi       RWX            nfs            8m40s

$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-184409e8-30a7-4315-be3d-23c779e6881e   200Mi      RWO            Delete           Bound    default/data-nfs-0     local-path              8m51s
pvc-52c0d57a-b285-45b6-b04c-41175604b0d0   20Mi       RWX            Delete           Bound    default/nfs-for-pods   nfs                     8m28s

$ kubectl k describe pod/echo-87585c776-c2j7w 
Name:           echo-87585c776-c2j7w
Namespace:      default
Priority:       0
Node:           k3d-nfs-test-server-0/192.168.128.2
Start Time:     Wed, 03 Feb 2021 17:12:18 +0100
Labels:         app=echo
                pod-template-hash=87585c776
Annotations:    <none>
Status:         Pending
IP:             
IPs:            <none>
Controlled By:  ReplicaSet/echo-87585c776
Containers:
  echo:
    Container ID:  
    Image:         busybox
    ...
    Mounts:
      /data from nfs-mount (rw)
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
  ...
  Tolerations:     node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                 node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason            Age                   From               Message
  ----     ------            ----                  ----               -------
  Warning  FailedScheduling  10m                   default-scheduler  0/1 nodes are available: 1 pod has unbound immediate PersistentVolumeClaims.
  Warning  FailedScheduling  10m                   default-scheduler  0/1 nodes are available: 1 pod has unbound immediate PersistentVolumeClaims.
  Normal   Scheduled         9m45s                 default-scheduler  Successfully assigned default/echo-87585c776-c2j7w to k3d-nfs-test-server-0
  Warning  FailedMount       92s (x12 over 9m46s)  kubelet            MountVolume.SetUp failed for volume "pvc-52c0d57a-b285-45b6-b04c-41175604b0d0" : mount failed: exit status 255
Mounting command: mount
Mounting arguments: -t nfs -o vers=3 10.43.192.199:/export/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 /var/lib/kubelet/pods/c9e21798-76ad-404d-b089-c9fff88e0a86/volumes/kubernetes.io~nfs/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0
Output: mount: mounting 10.43.192.199:/export/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 on /var/lib/kubelet/pods/c9e21798-76ad-404d-b089-c9fff88e0a86/volumes/kubernetes.io~nfs/pvc-52c0d57a-b285-45b6-b04c-41175604b0d0 failed: Connection refused
  Warning  FailedMount  55s (x4 over 7m43s)  kubelet  Unable to attach or mount volumes: unmounted volumes=[nfs-mount], unattached volumes=[nfs-mount default-token-t7qxd]: timed out waiting for the condition
```


