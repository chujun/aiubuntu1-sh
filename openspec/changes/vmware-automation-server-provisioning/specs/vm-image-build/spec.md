# vm-image-build

> **部署说明**：Packer 运行在 Windows 11 宿主机上（Windows 原生安装），Cloud-Init 运行在目标 VM 内部（Ubuntu 24 自带）。

## ADDED Requirements

### Requirement: Packer validates VM image configuration

The system SHALL validate Packer configuration files (.pkr.hcl) before building to catch syntax and configuration errors.

#### Scenario: Valid configuration passes validation
- **WHEN** `packer validate` is executed with a valid .pkr.hcl file
- **THEN** Packer returns exit code 0 and outputs "Template validated successfully"

#### Scenario: Invalid configuration fails validation
- **WHEN** `packer validate` is executed with an invalid .pkr.hcl file
- **THEN** Packer returns non-zero exit code and outputs specific validation error messages

---

### Requirement: Packer builds Ubuntu Server base image

The system SHALL build a minimal Ubuntu 24.04 Server base image using Packer and VMware Workstation Pro builder.

#### Scenario: Successful image build
- **WHEN** `packer build ubuntu-24-server.pkr.hcl` is executed
- **THEN** Packer creates a VM with Ubuntu 24.04 Server installed
- **AND** the VM is configured with minimal packages (OpenSSH Server, Cloud-Init)
- **AND** the resulting .vmx and .vmdk files are placed in the configured output directory

#### Scenario: Build fails due to ISO mount error
- **WHEN** `packer build` is executed but the Ubuntu ISO is not accessible
- **THEN** Packer fails with error indicating ISO file not found
- **AND** no partial VM files are left in the output directory

---

### Requirement: Packer builds Ubuntu Desktop base image

The system SHALL build a minimal Ubuntu 24.04 Desktop base image using Packer and VMware Workstation Pro builder.

#### Scenario: Successful desktop image build
- **WHEN** `packer build ubuntu-24-desktop.pkr.hcl` is executed
- **THEN** Packer creates a VM with Ubuntu 24.04 Desktop installed
- **AND** the VM is configured with minimal packages (OpenSSH Server, Cloud-Init, desktop utilities)
- **AND** the resulting .vmx and .vmdk files are placed in the configured output directory

---

### Requirement: Image build uses cloud-init for OS provisioning

The system SHALL use Cloud-Init to provision the guest OS during Packer build, avoiding interactive prompts.

#### Scenario: Cloud-Init configures VM without prompts
- **WHEN** Packer builds an image with Cloud-Init configured
- **THEN** The VM boots without displaying language/keyboard/username prompts
- **AND** Cloud-Init applies the user-data configuration automatically

---

### Requirement: Image build output is versioned

The system SHALL produce versioned image artifacts with predictable naming for automation integration.

#### Scenario: Image naming follows convention
- **WHEN** Packer completes a build for ubuntu-24-server
- **THEN** Output files follow pattern `ubuntu-24-server-{timestamp}.vmx`
- **AND** Metadata file contains build timestamp and Packer version used
