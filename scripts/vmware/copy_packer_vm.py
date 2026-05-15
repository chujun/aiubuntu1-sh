#!/usr/bin/env python3
"""Copy a Packer-built VMware VM folder into one or more VM instances.

The script copies the complete Packer output directory, renames the copied VMX
file, updates VMX identity fields, and removes runtime leftovers. It does not
start or register VMs in VMware Workstation.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


CONFLICT_KEYS = {
    "uuid.bios",
    "uuid.location",
    "vc.uuid",
    "ethernet0.generatedAddress",
    "ethernet0.generatedAddressOffset",
    "ethernet0.address",
}

RUNTIME_FILE_PATTERNS = ("vmware.log", "vmware-*.log", "*.vmem", "*.vmss")


@dataclass(frozen=True)
class CopyPlan:
    source_dir: Path
    destination_root: Path
    vm_name: str

    @property
    def destination_dir(self) -> Path:
        return self.destination_root / self.vm_name

    @property
    def destination_vmx(self) -> Path:
        return self.destination_dir / f"{self.vm_name}.vmx"


def parse_vm_names(raw_values: list[str]) -> list[str]:
    names: list[str] = []
    for value in raw_values:
        names.extend(part.strip() for part in value.split(","))

    names = [name for name in names if name]
    if not names:
        raise ValueError("At least one VM name is required.")

    invalid = [name for name in names if not re.fullmatch(r"[A-Za-z0-9._-]+", name)]
    if invalid:
        raise ValueError(
            "VM names may only contain letters, numbers, dot, underscore, and dash: "
            + ", ".join(invalid)
        )

    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise ValueError("Duplicate VM names are not allowed: " + ", ".join(duplicates))

    return names


def resolve_existing_dir(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.is_dir():
        raise FileNotFoundError(f"{label} does not exist or is not a directory: {resolved}")
    return resolved


def find_single_vmx(vm_dir: Path) -> Path:
    vmx_files = sorted(vm_dir.glob("*.vmx"))
    if not vmx_files:
        raise FileNotFoundError(f"No .vmx file found in {vm_dir}")
    if len(vmx_files) > 1:
        names = ", ".join(path.name for path in vmx_files)
        raise RuntimeError(f"Expected exactly one .vmx file in {vm_dir}, found: {names}")
    return vmx_files[0]


def render_vmx_line(key: str, value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'{key} = "{escaped}"'


def update_vmx_identity(vmx_path: Path, vm_name: str) -> None:
    lines = vmx_path.read_text(encoding="utf-8", errors="surrogateescape").splitlines()
    output: list[str] = []
    seen_display_name = False
    seen_address_type = False

    for line in lines:
        match = re.match(r'^\s*([^#][^=]*?)\s*=\s*"(.*)"\s*$', line)
        if not match:
            output.append(line)
            continue

        key = match.group(1).strip().lstrip("\ufeff")
        if key in CONFLICT_KEYS:
            continue
        if key == "displayName":
            output.append(render_vmx_line("displayName", vm_name))
            seen_display_name = True
            continue
        if key == "ethernet0.addressType":
            output.append(render_vmx_line("ethernet0.addressType", "generated"))
            seen_address_type = True
            continue

        output.append(line)

    if not seen_display_name:
        output.append(render_vmx_line("displayName", vm_name))
    if not seen_address_type:
        output.append(render_vmx_line("ethernet0.addressType", "generated"))

    vmx_path.write_text("\n".join(output) + "\n", encoding="utf-8", errors="surrogateescape")


def clean_runtime_leftovers(vm_dir: Path) -> list[Path]:
    removed: list[Path] = []

    for path in sorted(vm_dir.rglob("*.lck"), reverse=True):
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()
        removed.append(path)

    for pattern in RUNTIME_FILE_PATTERNS:
        for path in sorted(vm_dir.rglob(pattern)):
            if path.is_file():
                path.unlink()
                removed.append(path)

    return removed


def safe_remove_existing_destination(destination: Path, destination_root: Path) -> None:
    resolved_destination = destination.resolve()
    resolved_root = destination_root.resolve()
    if resolved_destination == resolved_root or resolved_root not in resolved_destination.parents:
        raise RuntimeError(f"Refusing to remove path outside destination root: {resolved_destination}")
    shutil.rmtree(resolved_destination)


def copy_vm(plan: CopyPlan, force: bool, dry_run: bool) -> dict[str, object]:
    source_vmx = find_single_vmx(plan.source_dir)
    result: dict[str, object] = {
        "vm_name": plan.vm_name,
        "source_dir": str(plan.source_dir),
        "source_vmx": str(source_vmx),
        "destination_dir": str(plan.destination_dir),
        "destination_vmx": str(plan.destination_vmx),
        "dry_run": dry_run,
        "actions": [],
    }
    actions = result["actions"]
    assert isinstance(actions, list)

    if plan.destination_dir.exists():
        if not force:
            raise FileExistsError(
                f"Destination already exists: {plan.destination_dir}. Use --force to replace it."
            )
        actions.append(f"remove existing destination {plan.destination_dir}")
        if not dry_run:
            safe_remove_existing_destination(plan.destination_dir, plan.destination_root)

    actions.append(f"copy directory {plan.source_dir} -> {plan.destination_dir}")
    if dry_run:
        actions.append(f"rename copied VMX to {plan.destination_vmx.name}")
        actions.append("update displayName and VMware identity fields")
        actions.append("remove runtime leftovers")
        return result

    shutil.copytree(plan.source_dir, plan.destination_dir)

    copied_vmx = plan.destination_dir / source_vmx.name
    if copied_vmx.name != plan.destination_vmx.name:
        copied_vmx.rename(plan.destination_vmx)
        actions.append(f"rename copied VMX to {plan.destination_vmx.name}")
    else:
        actions.append(f"keep VMX filename {plan.destination_vmx.name}")

    update_vmx_identity(plan.destination_vmx, plan.vm_name)
    actions.append("update displayName and VMware identity fields")

    removed = clean_runtime_leftovers(plan.destination_dir)
    actions.append(f"remove runtime leftovers: {len(removed)} item(s)")

    return result


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Copy a Packer-generated VMware VM folder into unique VM folders."
    )
    parser.add_argument(
        "-s",
        "--source-dir",
        required=True,
        type=Path,
        help="Packer output VM directory containing exactly one .vmx file.",
    )
    parser.add_argument(
        "-d",
        "--destination-root",
        required=True,
        type=Path,
        help="Directory where VM folders will be created.",
    )
    parser.add_argument(
        "-n",
        "--vm-names",
        required=True,
        nargs="+",
        help="Target VM names. Use comma-separated values or repeated arguments.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace an existing target VM folder under destination root.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the planned actions without copying or modifying files.",
    )
    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()

    try:
        source_dir = resolve_existing_dir(args.source_dir, "Source directory")
        destination_root = args.destination_root.expanduser().resolve()
        vm_names = parse_vm_names(args.vm_names)

        if not args.dry_run:
            destination_root.mkdir(parents=True, exist_ok=True)

        results = []
        for vm_name in vm_names:
            plan = CopyPlan(source_dir, destination_root, vm_name)
            results.append(copy_vm(plan, force=args.force, dry_run=args.dry_run))

        summary = {
            "created_at": datetime.now().isoformat(timespec="seconds"),
            "source_dir": str(source_dir),
            "destination_root": str(destination_root),
            "vm_count": len(results),
            "results": results,
        }
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:
        parser.exit(1, f"error: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
