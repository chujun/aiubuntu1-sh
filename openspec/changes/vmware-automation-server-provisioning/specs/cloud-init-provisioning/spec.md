# cloud-init-provisioning

> **部署说明**：Cloud-Init 软件运行在目标 VM 内部（Ubuntu 24 自带），Cloud-Init 配置文件通过 Packer 挂载的 ISO 注入。

## ADDED Requirements

### Requirement: Cloud-Init creates initial user

The system SHALL create an administrative user account during first boot using Cloud-Init user-data configuration.

#### Scenario: User creation on first boot
- **WHEN** A VM provisioned with Cloud-Init boots for the first time
- **THEN** Cloud-Init creates the user specified in user-data
- **AND** The user has sudo privileges (passwordless sudo for admin group)

#### Scenario: User creation with SSH authorized keys
- **WHEN** Cloud-Init user-data includes SSH public keys
- **THEN** The created user can authenticate via SSH using the corresponding private key
- **AND** Password authentication is disabled for security

---

### Requirement: Cloud-Init configures network

The system SHALL configure the VM's network settings via Cloud-Init, supporting DHCP and static IP configurations.

#### Scenario: DHCP network configuration
- **WHEN** Cloud-Init user-data specifies DHCP network config
- **THEN** The VM obtains IP address via DHCP on the primary interface
- **AND** DNS servers are configured according to the DHCP response

#### Scenario: Static IP network configuration
- **WHEN** Cloud-Init user-data specifies static IP configuration
- **THEN** The VM uses the specified IP address, netmask, gateway, and DNS servers
- **AND** Network configuration persists across reboots

---

### Requirement: Cloud-Init sets hostname

The system SHALL set the VM's hostname during first boot based on Cloud-Init configuration.

#### Scenario: Hostname assignment
- **WHEN** A VM boots with Cloud-Init configured with hostname "vm-ubuntu-server-01"
- **THEN** The VM's hostname is set to "vm-ubuntu-server-01"
- **AND** The hostname resolves correctly in the local network

---

### Requirement: Cloud-Init runs on first boot only

The system SHALL ensure Cloud-Init only runs its user-data scripts on the first boot, not on subsequent boots.

#### Scenario: First boot executes user-data
- **WHEN** A new VM boots for the first time with Cloud-Init
- **THEN** Cloud-Init executes all user-data modules (users, groups, write_files, runcmd)

#### Scenario: Subsequent boots skip user-data
- **WHEN** The same VM boots a second time
- **THEN** Cloud-Init skips user-data execution
- **AND** Boot time is not affected by Cloud-Init processing

---

### Requirement: Cloud-Init logs are accessible

The system SHALL provide accessible Cloud-Init logs for troubleshooting provisioning issues.

#### Scenario: Cloud-Init log location
- **WHEN** Cloud-Init executes during VM boot
- **THEN** Logs are written to `/var/log/cloud-init.log`
- **AND** Output from user-data scripts is written to `/var/log/cloud-init-output.log`

#### Scenario: Cloud-Init status command
- **WHEN** `cloud-init status` is executed on a running VM
- **THEN** It returns the current Cloud-Init execution state (running, done, error)
