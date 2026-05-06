# virsh KVM Command Guide

## Overview
`virsh` is a CLI tool for managing virtual machines via libvirt (KVM/QEMU).

---

## Basic Syntax
virsh <command> [options]

---

## Connection Management
virsh uri                        # Show current connection URI
virsh connect qemu:///system     # Connect to system libvirt
virsh list --all                 # List all VMs

---

## VM Lifecycle
virsh start <vm>                 # Start VM
virsh shutdown <vm>              # Graceful shutdown
virsh destroy <vm>               # Force stop (power off)
virsh reboot <vm>                # Reboot VM
virsh reset <vm>                 # Hard reset
virsh suspend <vm>               # Pause VM
virsh resume <vm>                # Resume VM

---

## Autostart
virsh autostart <vm>             # Enable autostart
virsh autostart --disable <vm>   # Disable autostart

---

## VM Information
virsh dominfo <vm>               # General info
virsh domstate <vm>              # Current state
virsh domuuid <vm>               # Show UUID
virsh domid <vm>                 # Show ID
virsh vcpuinfo <vm>              # CPU info

---

## Resource Monitoring
virsh cpu-stats <vm>             # CPU usage
virsh dommemstat <vm>            # Memory stats
virsh domstats <vm>              # Extended stats

---

## Console Access
virsh console <vm>               # Connect to VM console

---

## VM Creation & Definition
virsh define vm.xml              # Define VM from XML
virsh undefine <vm>              # Remove VM definition
virsh create vm.xml              # Create and start from XML

---

## Storage Management
virsh pool-list --all            # List storage pools
virsh pool-start <pool>          # Start pool
virsh pool-autostart <pool>      # Enable autostart for pool
virsh vol-list <pool>            # List volumes
virsh vol-create-as <pool> name size --format qcow2

---

## Network Management
virsh net-list --all             # List networks
virsh net-start <network>        # Start network
virsh net-autostart <network>    # Enable autostart
virsh net-destroy <network>      # Stop network

---

## Disk & Device Management
virsh attach-disk <vm> /path/disk.img vdb
virsh detach-disk <vm> vdb
virsh attach-interface <vm> network default
virsh detach-interface <vm> network --mac <mac>

---

## Snapshots
virsh snapshot-create-as <vm> snap1
virsh snapshot-list <vm>
virsh snapshot-revert <vm> snap1
virsh snapshot-delete <vm> snap1

---

## Migration
virsh migrate <vm> qemu+ssh://host/system
virsh migrate --live <vm> qemu+ssh://host/system

---

## Editing Configuration
virsh edit <vm>                  # Edit VM XML
virsh dumpxml <vm>               # View XML config

---

## Helpful Tips
- Use `--help` with any command for details
- VM names or IDs can usually be used interchangeably
- Be careful with `destroy` and `reset` (they are forceful)