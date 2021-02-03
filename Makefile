.PHONY: k3d-up
k3d-up:
		mkdir -p .k3d-volumes
		k3d cluster create nfs-test --volume $$(pwd)/.k3d-volumes:/data

.PHONY: k3d-down
k3d-down:
		k3d cluster delete nfs-test


.PHONY: nfs-deploy
nfs-deploy:
		helm install nfs stable/nfs-server-provisioner -f nfs-values.yaml

.PHONY: nfs-delete
nfs-delete:
		helm delete nfs


.PHONY: pv-create
pv-create:
		kubectl apply -f pv-for-nfs.yaml

.PHONY: pv-delete
pv-delete:
		kubectl delete -f pv-for-nfs.yaml


.PHONY: echo-deploy
echo-deploy:
		kubectl apply -f ./pvc-for-pods.yaml
		kubectl apply -f ./deployment-echo.yaml

.PHONY: echo-delete
echo-delete:
		kubectl delete -f ./deployment-echo.yaml

.PHONY: all
all: k3d-up nfs-deploy echo-deploy
 		