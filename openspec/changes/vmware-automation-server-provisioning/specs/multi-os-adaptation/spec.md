# multi-os-adaptation

> **部署说明**：多 OS 适配由 Ansible Role 实现，运行在控制节点 Linux VM 上，通过 SSH 连接到目标 VM 执行差异化配置。

## ADDED Requirements

### Requirement: Ansible Role detects OS distribution

The system SHALL detect the target VM's Linux distribution and version using Ansible facts.

#### Scenario: Ubuntu detection
- **WHEN** Ansible gathers facts from an Ubuntu 24.04 target
- **THEN** `ansible_facts['distribution']` equals "Ubuntu"
- **AND** `ansible_facts['distribution_major_version']` equals "24"
- **AND** `ansible_facts['os_family']` equals "Debian"

#### Scenario: Debian detection
- **WHEN** Ansible gathers facts from a Debian 12 target
- **THEN** `ansible_facts['distribution']` equals "Debian"
- **AND** `ansible_facts['distribution_major_version']` equals "12"
- **AND** `ansible_facts['os_family']` equals "Debian"

#### Scenario: CentOS detection
- **WHEN** Ansible gathers facts from a CentOS 9 target
- **THEN** `ansible_facts['distribution']` equals "CentOS"
- **AND** `ansible_facts['distribution_major_version']` equals "9"
- **AND** `ansible_facts['os_family']` equals "RedHat"

---

### Requirement: Ansible Role loads OS-specific tasks

The system SHALL load OS-specific task files based on the detected distribution, avoiding conditional tasks throughout role logic.

#### Scenario: Debian-family OS uses debian.yml tasks
- **WHEN** Ansible executes a Role on an Ubuntu target
- **THEN** The Role includes tasks from `tasks/debian.yml`
- **AND** Tasks in `tasks/main.yml` use `when: ansible_facts['os_family'] == 'Debian'` condition

#### Scenario: RedHat-family OS uses redhat.yml tasks
- **WHEN** Ansible executes a Role on a CentOS target
- **THEN** The Role includes tasks from `tasks/redhat.yml`
- **AND** Tasks in `tasks/main.yml` use `when: ansible_facts['os_family'] == 'RedHat'` condition

---

### Requirement: Ansible Role uses OS-specific variables

The system SHALL load OS-specific variables from separate variable files (vars/debian.yml, vars/redhat.yml).

#### Scenario: Package names vary by OS
- **WHEN** A Role needs to install openssh-server
- **THEN** On Debian/Ubuntu, it installs "openssh-server"
- **AND** On RedHat/CentOS, it installs "openssh-server" (same package name in this case)
- **AND** Variable files allow override of package names per OS if needed

#### Scenario: Service names vary by OS
- **WHEN** A Role needs to manage the SSH service
- **THEN** On Debian/Ubuntu, it uses service name "ssh"
- **AND** On RedHat/CentOS, it uses service name "sshd"
- **AND** The correct service name is loaded from OS-specific variable files

---

### Requirement: Ansible Role handles firewall differences

The system SHALL handle firewall configuration differences between Debian (ufw) and RedHat (firewalld) systems.

#### Scenario: Debian firewall configuration
- **WHEN** The firewall Role executes on Ubuntu
- **THEN** It uses ufw (Uncomplicated Firewall) commands
- **AND** Rules are configured via `ufw allow` commands

#### Scenario: RedHat firewall configuration
- **WHEN** The firewall Role executes on CentOS
- **THEN** It uses firewalld commands
- **AND** Rules are configured via `firewall-cmd --permanent --add-port` commands

---

### Requirement: Ansible Role handles package manager differences

The system SHALL use the correct package manager (apt/dnf/yum) based on the detected OS.

#### Scenario: Debian/Ubuntu uses apt
- **WHEN** Ansible installs packages on Ubuntu
- **THEN** It uses `ansible.builtin.apt` module
- **AND** Package cache is updated before installation

#### Scenario: RedHat/CentOS uses dnf
- **WHEN** Ansible installs packages on CentOS
- **THEN** It uses `ansible.builtin.dnf` module
- **AND** Package cache is updated before installation

---

### Requirement: Multi-OS support is documented

The system SHALL document which OS versions are supported and how to add support for new distributions.

#### Scenario: Supported OS documentation
- **WHEN** A new team member reviews the Ansible Role documentation
- **THEN** They can find a list of currently supported OS distributions
- **AND** They can find instructions for adding a new OS distribution
- **AND** Examples show where to add new OS-specific task and variable files
