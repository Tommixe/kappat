.POSIX:
.PHONY: *
.EXPORT_ALL_VARIABLES:


tools:
	@docker run \
		--rm \
		--interactive \
		--tty \
		--network host \
		--volume "/var/run/docker.sock:/var/run/docker.sock" \
		--volume $(shell pwd):$(shell pwd) \
		--volume ${HOME}/.ssh:/root/.ssh \
		--volume ${HOME}/.kube:/root/.kube \
		--volume ${HOME}/.terraform.d:/root/.terraform.d \
		--volume kappat-tools-cache:/root/.cache \
		--volume kappat-tools-nix:/nix \
		--workdir $(shell pwd) \
		nixos/nix nix-shell

sshkey:
	ssh-keygen -t ed25519 -P '' -f ~/.ssh/kappat

config:
	python3 configure

packer:
	cd packer-proxmox-templates/ubuntu-22.04.01-amd64; \
	packer build .	

terraform:
	cd k3s-proxmox-terraform-ansible/terraform; \
	terraform init && \
	terraform plan --var-file=variables.tfvars && \
	terraform apply --var-file=variables.tfvars

ansible:
	cd k3s-proxmox-terraform-ansible; \
	ansible-playbook -i inventory/my-cluster/hosts.ini site.yml

getargopwd:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

cleanup:
	rm unsealed-secrets/gitrepoargo.yaml
	rm secrets/gitreapoargosealed.yaml
	rm packer-proxmox-templates/ubuntu-22.04.01-amd64/variables.auto.pkrvars.hcl
	rm k3s-proxmox-terraform-ansible/terraform/terraform-plugin-proxmox.log
	rm k3s-proxmox-terraform-ansible/terraform/*.tfstate
	rm k3s-proxmox-terraform-ansible/terraform/variables.tfvars
	rm k3s-proxmox-terraform-ansible/inventory/my-cluster/group_vars/all.yml
	rm k3s-proxmox-terraform-ansible/inventory/my-cluster/hosts.ini
		