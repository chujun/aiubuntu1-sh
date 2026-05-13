# ansible-config-management

> **部署说明**：Ansible 运行在独立的 Linux 控制节点 VM（Ubuntu Server）上，通过 SSH 连接到目标 VM 进行配置管理。

## ADDED Requirements

### Requirement: Ansible connects to target VMs via SSH

The system SHALL establish SSH connections from the Ansible control node to target VMs for configuration management.

#### Scenario: Ansible ping test succeeds
- **WHEN** `ansible -i inventory/hosts.yml all -m ping` is executed
- **THEN** Ansible connects to all target VMs via SSH
- **AND** Returns SUCCESS for each reachable VM

#### Scenario: Ansible connection failure handling
- **WHEN** Ansible attempts to connect to an unreachable VM
- **THEN** Ansible reports UNREACHABLE status for that host
- **AND** Continues execution for other hosts without failing entirely

---

### Requirement: Ansible configures SSH service

The system SHALL configure SSH daemon settings including disabling password authentication and configuring authorized keys.

#### Scenario: SSH hardening applied
- **WHEN** `ansible-playbook -i inventory/hosts.yml playbooks/base.yml --tags ssh` is executed
- **THEN** SSH password authentication is disabled
- **AND** Root login is disabled
- **AND** SSH authorized_keys are configured for ansible user

---

### Requirement: Ansible configures NTP service

The system SHALL configure NTP time synchronization on target VMs.

#### Scenario: NTP service enabled and running
- **WHEN** `ansible-playbook -i inventory/hosts.yml playbooks/base.yml --tags ntp` is executed
- **THEN** NTP service is installed
- **AND** NTP service is enabled and running
- **AND** Time synchronization with specified NTP servers is active

---

### Requirement: Ansible configures firewall

The system SHALL configure firewall rules on target VMs, opening only required ports.

#### Scenario: Firewall allows SSH and defined services
- **WHEN** `ansible-playbook -i inventory/hosts.yml playbooks/base.yml --tags firewall` is executed
- **THEN** SSH (port 22) is allowed
- **AND** Only additionally specified ports are opened
- **AND** Default deny policy is applied for incoming connections

---

### Requirement: Ansible installs Docker runtime

The system SHALL install and configure Docker runtime environment on target VMs.

#### Scenario: Docker installation
- **WHEN** `ansible-playbook -i inventory/hosts.yml playbooks/runtime.yml --tags docker` is executed
- **THEN** Docker engine is installed
- **AND** Docker service is enabled and running
- **AND** Current user is added to docker group

#### Scenario: Docker daemon configuration
- **WHEN** Docker is installed via Ansible
- **THEN** Docker daemon is configured with specified registry mirrors (if any)
- **AND** Docker socket permissions allow docker group members to access

---

### Requirement: Ansible installs Java runtime

The system SHALL install Java Development Kit on target VMs designated as Java development machines.

#### Scenario: Java installation
- **WHEN** `ansible-playbook -i inventory/hosts.yml playbooks/runtime.yml --tags java` is executed
- **THEN** OpenJDK or Oracle JDK is installed (version specified in inventory)
- **AND** JAVA_HOME environment variable is set
- **AND** `java -version` executes successfully

---

### Requirement: Ansible installs Node.js runtime

The system SHALL install Node.js runtime on target VMs designated for JavaScript/Node development.

#### Scenario: Node.js installation
- **WHEN** `ansible-playbook -i inventory/hosts.yml playbooks/runtime.yml --tags node` is executed
- **THEN** Node.js is installed (version specified in inventory)
- **AND** npm is installed and functional
- **AND** `node -v` and `npm -v` execute successfully

---

### Requirement: Ansible inventory defines target VMs

The system SHALL use a structured inventory file (YAML format) that defines all target VMs and their groupings.

#### Scenario: Inventory structure
- **WHEN** `ansible-inventory -i inventory/hosts.yml --list` is executed
- **THEN** All defined hosts are listed with their variables
- **AND** Host groups are correctly organized (dev-machines, ai-machines, etc.)
- **AND** Group variables are accessible to hosts in that group

#### Scenario: Inventory validation
- **WHEN** `ansible-inventory -i inventory/hosts.yml --graph` is executed
- **THEN** The hierarchical structure of hosts and groups is displayed correctly
