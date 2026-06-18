# sriov

Vulkan application for Intel Arc Pro B50/B70 (Battlemage) SR-IOV VF provisioning. By Default it allocates 2GB GPU memory before creating VFs to ensure host has usable VRAM.

## Dependencies (Ubuntu)

```bash
sudo apt install libvulkan-dev vulkan-tools mesa-vulkan-drivers cmake g++ make
```

## Build

```bash
mkdir build && cd build
cmake ..
make
```

## Usage

**Run as root** (required for sysfs SR-IOV writes).

```bash
# Auto-detect Intel Arc Pro B50/B70 and create 3 VFs
sudo ./sriov --sriov 3

# Specify PCI address manually (format: domain:bus:device, function=0 is forced)
sudo ./sriov --pci 0000:0d:00 --sriov 3
```

### Options

- `--pci <domain:bus:device>` — Target PCI device (default: auto-detect Arc Pro B50/B70)
- `--sriov <num>` — Create `<num>` SR-IOV VFs after allocating PF memory
- `--memory <MB>` — GPU memory (VRAM) to reserve for the PF before creating VFs (default: 2048)
- `--reset-vfs` — Disable all VFs (`sriov_numvfs=0`) without allocating any GPU memory. Use this before re-running with different `--memory`/`--sriov` values
- `--persist` — After performing the requested allocation/VF setup, install a `systemd` service that replays the same command on every boot (see [Persistence across reboots](#persistence-across-reboots))
- `--undo-persist` — Remove the boot-persistence service and exit
- `--help` — Show usage and exit

### Examples

```bash
# Auto-detect, create 3 VFs, allocate 2GB
sudo ./sriov --sriov 3

# Allocate 512 MB, create 3 VFs
sudo ./sriov --memory 512 --sriov 3

# Allocate 4GB, create 6 VFs
sudo ./sriov --memory 4096 --sriov 6

# Multi-GPU: specify device explicitly (domain:bus:device)
sudo ./sriov --pci 0000:0d:00 --sriov 3

# Disable all existing VFs (e.g. before re-running with different --memory/--sriov)
sudo ./sriov --reset-vfs

# Create 3 VFs now AND re-apply on every boot
sudo ./sriov --sriov 3 --persist

# Stop re-applying on boot
sudo ./sriov --undo-persist

# On systems where the system Mesa is too old for this GPU's PCI ID (e.g. Arc
# Pro B70 / 0xe223 on Proxmox VE 9.2's Mesa 25.0.7), use run.sh instead - it
# wraps the binary above and picks up a custom Mesa build at /opt/mesa-intel
# if present (see "Arc Pro B70 (0xe223) on older Mesa" below)
sudo ./run.sh --sriov 3
```

## VRAM Status Script

`vram-status.sh` shows the current LMEM (VRAM) split between the PF and each SR-IOV VF,
in GB. Requires VFs to already be created (see `--sriov` above) and debugfs to be mounted
(default on most distros). Run as root:

```bash
sudo ./vram-status.sh
```

Example output:

```
VFs:
  vf1: 9.89 GB
  vf2: 9.89 GB
  vf3: 9.89 GB
PF:    2.20 GB
Spare: 0.12 GB
Total: 32.00 GB
```

## Arc Pro B70 (0xe223) on older Mesa (e.g. Proxmox VE 9.2)

The B70 (`0xe223`) was added to Mesa's `anv` Vulkan driver in Mesa 25.1. Proxmox VE 9.2
(Debian 13 "trixie") ships Mesa 25.0.7, so the system Vulkan ICD prints `MESA: warning:
Driver does not support the 0xe223 PCI ID`, falls back to `llvmpipe`, and device selection
fails.

Solution: build Mesa 26.x from source into an isolated `/opt/mesa-intel` prefix (system Mesa 
is left untouched). `./run.sh` automatically uses `/opt/mesa-intel`'s ICD if present.

If the `--persist` flag is used to install the service on boot, the environment variable
will be carried over to the persistence service (so `./run.sh` is not required).

```bash
# Build dependencies
sudo apt install -y git build-essential meson ninja-build pkg-config python3-mako \
  libdrm-dev libexpat1-dev zlib1g-dev libelf-dev bison flex glslang-tools \
  libclc-19-dev llvm-19-dev clang-19 libclang-cpp19-dev libllvmspirvlib-19-dev

# Mesa's intel_clc needs Clang's full C++ headers (Driver/CodeGen/Frontend), which
# Debian's clang-19 packages don't ship - install from apt.llvm.org instead
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 19 all

# Build and install Mesa into an isolated prefix
git clone --depth 1 --branch mesa-26.0.8 https://gitlab.freedesktop.org/mesa/mesa.git
cd mesa
meson setup build --prefix=/opt/mesa-intel \
  -Dbuildtype=release -Dplatforms= -Dgallium-drivers= \
  -Dvulkan-drivers=intel -Dintel-rt=disabled -Dvideo-codecs= \
  -Dvalgrind=disabled -Dlibunwind=disabled
ninja -C build
sudo ninja -C build install
```

## Persistence across reboots

The PF memory reservation is transient (held only while the process runs) and
SR-IOV VFs are reset to `0` on every reboot, so the PF/VF configuration does not
survive a restart on its own. `--persist` solves this by installing a `systemd`
oneshot service (`/etc/systemd/system/sriov.service`, `WantedBy=multi-user.target`)
that replays the exact command you ran — minus `--persist` — on every boot.

```bash
# Apply now and on every boot
sudo ./sriov --sriov 3 --persist
```

Because the service runs the binary on every boot, it should live in a stable
location. If the binary is not already under `/opt` or `/usr`, `--persist`
prompts to copy it to `/opt/sriov/sriov` and points the
service at that copy. If you used `run.sh` for a custom Mesa build, the
`VK_ICD_FILENAMES` value is captured into the service so the B70-on-older-Mesa
case keeps working at boot (where `run.sh`'s environment is not present).

Inspect or remove persistence:

```bash
systemctl status sriov.service     # check it
journalctl -u sriov.service        # see boot-time output
sudo ./sriov --undo-persist        # disable + remove the service
```

`--undo-persist` disables and deletes the service unit; the installed binary
under `/opt/sriov/` is left in place (remove it manually if desired).

## Notes

- If multiple Intel Arc Pro B50/B70 devices found use `--pci` to specify
- To force Mesa Vulkan to report only one default GPU (typically VF 0), use:

```bash
export MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE=1
```
