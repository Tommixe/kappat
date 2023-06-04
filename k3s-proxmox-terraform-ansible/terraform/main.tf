resource "proxmox_vm_qemu" "proxmox_vm_master" {
  count       = var.num_k3s_masters
  name        = "k3s-master-${count.index}"
  target_node = var.pm_node_name
  clone       = var.tamplate_vm_name
  os_type     = "cloud-init"
  agent       = 1
  memory      = var.num_k3s_masters_mem
  cores       = var.master_cores
  sockets     = var.master_sockets

  ipconfig0 = "ip=${var.master_ips[count.index]}/${var.networkrange},gw=${var.gateway}"

  # Cloud-Init Drive
  ciuser     = var.admin_username
  cipassword = var.admin_password
  sshkeys    = <<-EOF
  %{for key in var.admin_public_ssh_keys~}
  ${key}
  %{endfor~}
  EOF

  lifecycle {
    ignore_changes = [
      #ciuser,
      #sshkeys,
      disk,
      network
    ]
  }

}

resource "proxmox_vm_qemu" "proxmox_vm_workers" {
  count       = var.num_k3s_nodes
  name        = "k3s-worker-${count.index}"
  target_node = var.pm_node_name
  clone       = var.tamplate_vm_name
  os_type     = "cloud-init"
  agent       = 1
  memory      = var.num_k3s_nodes_mem
  cores       = var.node_cores
  sockets     = var.node_sockets

  ipconfig0 = "ip=${var.worker_ips[count.index]}/${var.networkrange},gw=${var.gateway}"

  # Cloud-Init Drive
  ciuser     = var.admin_username
  cipassword = var.admin_password
  sshkeys    = <<-EOF
  %{for key in var.admin_public_ssh_keys~}
  ${key}
  %{endfor~}
  EOF

  lifecycle {
    ignore_changes = [
      #ciuser,
      #sshkeys,
      disk,
      network
    ]
  }

}

#data "template_file" "k8s" {
#  template = file("./templates/k8s.tpl")
#  vars = {
#    k3s_master_ip = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_master : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.pvt_key])])}"
#    k3s_node_ip   = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_workers : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.pvt_key])])}"
#  }
#}


#resource "local_file" "k8s_file" {
#  content  = data.template_file.k8s.rendered
#  filename = "../inventory/my-cluster/hosts.ini"
#}

resource "local_file" "k8s_file" {
  content  = templatefile ("./templates/k8s.tpl",{
      k3s_master_ip = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_master : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.pvt_key])])}"
      k3s_node_ip   = "${join("\n", [for instance in proxmox_vm_qemu.proxmox_vm_workers : join("", [instance.default_ipv4_address, " ansible_ssh_private_key_file=", var.pvt_key])])}"
      }
  )
  filename = "../inventory/my-cluster/hosts.ini"
}

#resource "local_file" "var_file" {
#  source   = "../inventory/sample/group_vars/all.yml"
#  filename = "../inventory/my-cluster/group_vars/all.yml"
#}
