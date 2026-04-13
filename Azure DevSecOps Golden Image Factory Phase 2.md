# Project: Azure DevSecOps Golden Image Factory

## Phase 2: CI/CD Automation & Continuous Compliance Verification

### 📌 Project Overview
Following the successful manual compilation of the hardened templates in Phase 1, the objective of Phase 2 was to engineer a fully hands-free, automated factory using **GitHub Actions**. 

The goal was not just to automate the baking of the images, but to establish a "Trust but Verify" pipeline. To achieve this, the pipeline dynamically deploys ephemeral Virtual Machines from the newly baked images, executes military-grade compliance scans using **OpenSCAP**, securely extracts the audit evidence, and publishes the results as an immutable GitHub Release before aggressively tearing down the temporary infrastructure.

### 🛠️ Technology Stack (Additions)
* **CI/CD Platform:** GitHub Actions
* **Compliance Engine:** OpenSCAP (scap-security-guide)
* **Scripting & Connectivity:** Bash, Secure Copy (SCP), SSH Polling Loops
* **Artifact Management:** GitHub Releases (`softprops/action-gh-release`)
* **Dynamic Versioning:** Semantic Versioning mapped to GitHub Run Counters

### 🏗️ Architecture & Workflow
1. **The Trigger:** A code push to the `main` branch or a manual workflow dispatch initiates the GitHub Actions runner.
2. **Dynamic Baking:** HashiCorp Packer builds both the RHEL 9 and Ubuntu 22.04 CIS-hardened images simultaneously, tagging them with a dynamic semantic version number (e.g., `1.0.42`) linked to the GitHub run.
3. **Ephemeral Deployment:** The pipeline uses the Azure CLI to spin up temporary VMs utilizing the newly minted Golden Images.
4. **Continuous Compliance:** The runner authenticates via dynamically generated Ed25519 SSH keys, installs the OpenSCAP engine, and runs a strict CIS Level 1 evaluation against the live OS.
5. **Extraction:** The resulting HTML compliance reports are securely pulled back to the GitHub runner via SCP.
6. **Defensive Demolition:** A cascading teardown sequence permanently shreds the ephemeral VMs, OS Disks, NICs, and Public IPs to protect the cloud quota.
7. **Immutable Audit Trail:** The pipeline bundles the HTML reports and publishes them to a permanent GitHub Release, establishing a verifiable, non-expiring audit trail for the security team.

### 🛡️ Key Challenges & Engineering Solutions

Transitioning from local execution to a headless, automated CI/CD pipeline uncovered several race conditions and hardened OS restrictions. Here is how they were engineered around:

**1. The Survivor Resource Race Condition**
* **The Problem:** During the ephemeral VM teardown phase, the Azure CLI `az vm delete` command defaults to leaving the Network Interface (NIC) and OS Disk intact to prevent data loss. Combined with an asynchronous `--no-wait` flag, the pipeline's IP sweeper script was executing before the NIC was destroyed, causing orphaned Public IPs to quickly exhaust the Azure environment quota.
* **The Solution:** Enforced a strict, blocking cascading deletion by injecting the `--nic-delete-option delete` and `--os-disk-delete-option delete` flags during the VM *creation* step. By removing the `--no-wait` override, the pipeline was forced to wait for complete infrastructure demolition before successfully sweeping the orphaned IPs.

**2. OpenSCAP AppArmor & CIS Permission Traps**
* **The Problem:** The pipeline executes the OpenSCAP compliance scan as `root` to evaluate kernel-level parameters. However, because the Golden Image is strictly CIS-hardened, aggressive `umask` settings and AppArmor profiles blocked the OpenSCAP engine from writing the final HTML report into standard user home directories, crashing the pipeline.
* **The Solution:** Pivoted the reporting engine to output to the universally writable `/tmp` directory to bypass AppArmor restrictions. Engineered a subsequent Bash sequence to move the report into the `sysadmin` home directory and execute a `chown` command, allowing the unprivileged runner to securely extract the file via SCP.

**3. Ephemeral SSH Boot Delays**
* **The Problem:** Hardened cloud VMs boot at unpredictable speeds. Relying on a static `sleep 30` command to wait for the VM to become available resulted in intermittent pipeline crashes when the SSH daemon took longer to initialize.
* **The Solution:** Engineered a dynamic Bash polling loop that attempts to connect via SSH up to 20 times with a 5-second timeout. Once the connection succeeds, it utilizes `ssh-keyscan` to dynamically inject the VM's thumbprint into the runner's `known_hosts`, creating a self-healing, time-efficient connectivity phase.

**4. Immutable Releases & Ghost Resources**
* **The Problem:** Standard GitHub Actions build artifacts expire after 90 days, destroying the compliance evidence. Additionally, re-running failed pipelines caused Packer to crash when it collided with "ghost" managed images left behind by previous interrupted runs.
* **The Solution:** Swapped standard artifacts for `softprops/action-gh-release` to attach the OpenSCAP reports to permanent, version-tagged GitHub Releases. Parameterized the Packer templates to accept `github.run_number` for dynamic semantic versioning, and implemented the Packer `-force` flag to automatically bulldoze and overwrite any orphaned cloud wreckage.

---

### 🚀 Conclusion
This DevSecOps Golden Image Factory completely eliminates the friction between agile deployment and enterprise security. By integrating automated OpenSCAP scans and immutable release tracking, the pipeline guarantees that any engineer spinning up infrastructure in this Azure environment is utilizing a verified, hardened, and fully compliant operating system by default.
