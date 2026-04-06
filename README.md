# Project: Azure DevSecOps Golden Image Factory

## Phase 1: Security Engineering & Infrastructure as Code (IaC)

### 📌 Project Overview
The objective of this phase was to architect a secure, automated "Golden Image" pipeline in Microsoft Azure. Using HashiCorp Packer and Ansible, I automated the creation of custom Virtual Machine images for both Ubuntu and Red Hat Enterprise Linux 9 (RHEL 9) that strictly adhere to the **CIS (Center for Internet Security) Level 1 Benchmark**. 

By shifting security to the left, these templates guarantee that any new infrastructure deployed in the cloud is hardened against enterprise vulnerability standards by default.

### 🛠️ Technology Stack
* **Cloud Provider:** Microsoft Azure (Compute Galleries, Trusted Launch, Run Command)
* **Infrastructure as Code (IaC):** HashiCorp Packer
* **Configuration Management:** Ansible (Ansible Lockdown Official CIS Roles)
* **OS Targets:** Ubuntu 22.04 LTS, RHEL 9

### 🏗️ Architecture & Workflow
1. **Provisioning:** Packer authenticates with Azure to spin up a temporary, invisible build VM.
2. **Configuration:** Packer triggers Ansible to execute the official CIS Level 1 playbooks locally on the build VM.
3. **Customization:** Ansible applies DevSecOps overrides via `post_tasks` to ensure cloud compatibility.
4. **Capture:** Packer generalizes the VM (sysprep/deprovision), captures the disk, and pushes the finalized Golden Image to an Azure Compute Gallery for scalable deployment.

### 🛡️ Key Challenges & Engineering Solutions

Building secure images in a cloud environment introduces severe conflicts between native OS security and cloud hypervisor requirements. Below are the critical roadblocks encountered and the engineering solutions implemented:

**1. Azure VM Agent Lockout (Internal Firewalls)**
* **The Problem:** The CIS baseline automatically enforces strict internal firewall rules (`ufw` on Ubuntu, `firewalld`/`nftables` on RHEL). Upon the first boot of the hardened image, these firewalls dropped all internal traffic, suffocating the Azure VM Agent and breaking SSH access.
* **The Solution:** Engineered a DevSecOps override within the Ansible `post_tasks` to gracefully halt and disable the internal OS firewalls right before the Packer snapshot. This forces the architecture to rely entirely on Azure Network Security Groups (NSGs) for boundary defense, preventing OS-level network lockouts.

**2. Trusted Launch & vTPM Compliance**
* **The Problem:** The RHEL 9 image was configured to require advanced security hardware, causing standard Azure CLI deployment commands to fail. 
* **The Solution:** Modified the deployment architecture to enforce the `--security-type TrustedLaunch` flag. This ensures the VMs boot with Secure Boot and a virtual TPM (vTPM), actively protecting the kernel from rootkits and boot-level malware.

**3. Zero-Trust SSH & SELinux Restrictions**
* **The Problem:** After successfully deploying the RHEL 9 image, SSH connections returned "Permission Denied" despite utilizing correct cryptographic keys. 
* **The Solution:** Leveraged the Azure "Run Command" to remotely query the `/var/log/secure` logs without network access. Identified two distinct CIS enforcements:
    * **SELinux:** Restored the `ssh_home_t` security context on the `authorized_keys` file using `restorecon`.
    * **Zero-Trust Access:** Injected the specific deployment accounts (`azureuser` and `packer`) into the strict `AllowUsers` directive within the `/etc/ssh/sshd_config` file to satisfy the CIS identity requirements.

**4. Cloud Quota & Orphaned Resource Management**
* **The Problem:** Failed early pipeline runs left orphaned Network Interfaces (NICs) and Public IPs, exhausting the Azure environment quota and halting future builds.
* **The Solution:** Mapped resource dependencies and utilized the Azure CLI to surgically trace and terminate ghost resources holding IP addresses hostage, restoring pipeline functionality.

### 🔜 Next Steps: Phase 2
With the manual security engineering and image compilation proven successful, Phase 2 will focus on CI/CD automation. The goal is to migrate these Packer and Ansible configurations into GitHub Actions to establish a hands-free, weekly image baking schedule.
