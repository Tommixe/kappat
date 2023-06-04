## Credits
This repository is inspired by https://github.com/khuedoan/homelab

and combine the work of the following two amazing repositories trying to build a single stack to deploy a full functional k3s cluster in Proxmox: 
https://github.com/sdhibit/packer-proxmox-templates
https://github.com/NatiSayada/k3s-proxmox-terraform-ansible

## Deploy using make commands
*---TODO add details to each command---*

If you are using linux you can deploy the stack following these steps, the only prerequisite is to have docker installed.

1. Rename the file `all-variables.sample` to `all-variables` and update all the vars. 
2. Run `make tools` this will create a run a pre-configured nix-shell, run all other command inside this shell
3. Run `make sshkey`
4. Run `make config`
5. Run `make packer`
6. Run `make terraform` 
7. Run `make ansible` 
9. Run `make getargopwd` to get argocd initial password 

## Alternative deploy running separate scripts

## Proxmox images built with Packer

### Requirements
Requires Proxmox >= 1.6.6 which fixes proxmox boot order change in pve-6.2-15
https://git.proxmox.com/?p=qemu-server.git;a=commit;h=2141a802b843475be82e04d8c351d6f7cd1a339a
https://github.com/hashicorp/packer/issues/10252

Use Packer version <=1.8 if you want to use qcow2 disk format:
https://github.com/hashicorp/packer-plugin-proxmox/issues/92 

Install packer:
https://developer.hashicorp.com/packer/downloads
You can choose a specific Packer version to install using pkenv
https://github.com/iamhsa/pkenv

### Adding packer user with correct privileges or use api token id & secret (preferred)
``` bash
pveum useradd packer@pve
pveum passwd packer@pve
pveum roleadd Packer -privs "VM.Config.Disk VM.Config.CPU VM.Config.Memory Datastore.AllocateSpace Sys.Modify VM.Config.Options VM.Allocate VM.Audit VM.Console VM.Config.CDROM VM.Config.Network VM.PowerMgmt VM.Config.HWType VM.Monitor"
pveum aclmod / -user packer@pve -role Packer
```

In Proxmox create a new api token:

Datacenter -> Permission -> API Tokens -> Add

As user select an existing user, the same user's privileges will be provided to the token

### Fill in the variables file 
Specify all variables in the file `variables.auto.pkrvars`
All available variable are defined in the variables.pkr.hcl file

### Run Packer build
Cd in the packer-proxmox-templates folder to build the VM template i.e.:
```bash
cd packer-proxmox-templates/ubuntu-22.04.01-amd64
```
```bash
packer build .
```
The build will finish with the error "Cannot eject ISO from cdrom drive, ide2 is not present, or not a cdrom media" documented here
(https://github.com/hashicorp/packer-plugin-proxmox/issues/102)
but a new VM with the id specified in the variable file is created successfully in the selected proxmox host.

## Deploy k3s cluster with Terraform and Ansible
Move in the folder containing Terraform and Ansible scripts
```bash
cd k3s-proxmox-terraform-ansible
```

### terraform setup

The terraform file also creates a dynamic host file for Ansible, so we need to create the folder and files first

```bash
cp -R inventory/sample inventory/my-cluster
```

Rename the file `terraform/variables.tfvars.sample` to `terraform/variables.tfvars` and update all the vars.
There you can select how many nodes would you like to have on your cluster and configure the name of the base image.

It's also important to update the ssh key that is going to be used and proxmox host address.
Ansible in the next steps, will connect to the hosts deployed by Terraform using ssh.  Add the name and location of the private key to be used in the ```pvt_key``` variable and specify the content of the related public key in the ```admin_public_ssh_keys``` 

To run the Terrafom, you will need to cd into `terraform` and run:

```bash
cd terraform/
terraform init
terraform plan --var-file=variables.tfvars
terraform apply --var-file=variables.tfvars
```

it can take some time to create the servers on Proxmox but you can monitor them over Proxmox.
it should look like this now:

![alt text](pics/h0Ha98fXyO.png)

After you run the Terrafom file, your host.ini file should look like this:

```bash
[master]
192.168.3.200 Ansible_ssh_private_key_file=~/.ssh/proxk3s

[node]
192.168.3.202 Ansible_ssh_private_key_file=~/.ssh/proxk3s
192.168.3.201 Ansible_ssh_private_key_file=~/.ssh/proxk3s
192.168.3.198 Ansible_ssh_private_key_file=~/.ssh/proxk3s
192.168.3.203 Ansible_ssh_private_key_file=~/.ssh/proxk3s

[k3s_cluster:children]
master
node
```

## Ansible setup

First, update the var file in `inventory/my-cluster/group_vars/all.yml` and update the ```ansible_user``` with the user you input in variable ```admin_username```  in the file  `terraform/variables.tfvars`. 

You can choose if you would like to install metallb and argocd. if you are installing metallb, you should also specified an ip range for metallb.

For argocd you have two option:
1. Install argocd setting variable argocd to "true" and argocd_service_type to "LoadBalancer". In this case metallb will route the request directly to argocd service
2. Install argocd setting argocd to "false" and argocdingress to "true". In this case argocd will be behind traefik reverse proxy and an ingress object will be deployed to route the request to argocd service.

If you are running multiple clusters in your kubeconfig file, make sure to disable ```copy_kubeconfig```.

### Apps installation
If you want you can also automatically install application from a github repository.
In this repo you can find an example application in the folder ```apps```.

After the cluster is installed the repo that you specify in the variable `gitrepourl` is automatically added to ArgoCD.
If the repo is private during the run of the playbook you will be asked for the github private key of the github user specified in the variable `gitrepouser`.
If the repo is public or you are not adding any report just hit enter.

### Provisioning

Start provisioning of the cluster using the following command:

```bash
# cd to the project root folder (/k3s-proxmox-terraform-ansible)
cd ..

# run the playbook
ansible-playbook -i inventory/my-cluster/hosts.ini site.yml
```

It can a few minutes, but once its done, you should have a k3s cluster up and running.

### Kubeconfig

The ansible should already copy the file to your ~/.kube/config (if you enable the ```copy_kubeconfig``` in  ```inventory/my-cluster/group_vars/all.yml```), but if you are having issues you can scp and check the status again.

```bash
scp debian@master_ip:~/.kube/config ~/.kube/config
```

### Argocd
You can access ArgoCD server at the host name provided in the variable ```argocdhostname```.
Remember to add the this hostname in your local DNS server or in your /etc/hosts file.

To get argocd initial password run the following in your local terminal:

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Traefik dashboard

In case you are using Treafik you can access Traefik dashboard forwarding pod to localhost:

```
kubectl port-forward traefik-xxxx-xxx 9000:9000
```
Than on you browser you can go to http://localhost:9000
