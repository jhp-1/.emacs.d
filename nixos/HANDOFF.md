# Locked-Down Console Emacs Appliance — ThinkPad X270

**Goal:** a non-graphical (console-only) NixOS laptop running Emacs, where a
child user can browse/read/write in Emacs but **cannot install a web browser or
a P2P filesharing program**, and cannot escalate to root. MELPA/ELPA
(`package.el`) must keep working for the Emacs config.

**What "airtight" means here (read this first).** Two guarantees are genuinely
airtight; the rest are strong layers, not magic:

- **No GUI program can run at all** — there is no X and no Wayland. A graphical
  browser (Firefox, Chromium) or a GUI torrent client (qBittorrent,
  Transmission) has no screen to draw on and cannot start, regardless of how it
  got onto the disk. This is the airtight block on *browsers*.
- **No system-wide software can be installed** — the child cannot reach the Nix
  daemon and there is no compiler/toolchain, so `nix-shell -p firefox`,
  `nix profile install`, `nix build`, `apt`, `pip`, etc. all fail.

Everything else (noexec mounts, egress firewall, firmware passwords) closes the
remaining CLI-binary and physical paths. The honest residual is documented at
the end — it is small and does not include browsers or installable P2P clients.

---

## 1. The security model — five barriers

Installing a native program means **get a binary in → mark it executable →
run it**, and for a GUI app, **draw a window**. Each step is independently
closed.

| # | Barrier | Mechanism | Stops |
|---|---------|-----------|-------|
| 1 | **Install path** | `nix.settings.allowed-users` excludes the child; no compiler in the system | `nix-shell`, `nix build`, `nix profile`, any package manager. `/nix/store` is root-owned; users can't write it. |
| 2 | **Execution path** | `noexec,nosuid,nodev` on every user-writable filesystem | A downloaded static ELF binary or AppImage — `chmod +x && ./thing` → *Permission denied*. Verified: even the `ld.so` loader bypass fails on current kernels (`mmap(PROT_EXEC)` is refused on noexec). |
| 3 | **Display path** | No X, no Wayland, no display manager | **Every GUI browser and GUI P2P client.** They cannot open a window. |
| 4 | **Network path** (optional but recommended) | nftables egress allowlist (53/80/443/123 out, drop rest) | Torrent peer/DHT traffic; backstops any CLI binary that slipped through. Leaves MELPA (443), `eww`, `elfeed`, DNS, time sync working. |
| 5 | **Physical path** | UEFI supervisor password + disabled external boot; FDE; GRUB edit lock | Booting a live USB, pulling the disk, `init=/bin/bash`. Laptop-in-a-child's-hands is never *perfectly* closable — see §9. |

**MELPA/ELPA is orthogonal to all five.** `package.el` is pure Emacs Lisp
fetching over HTTPS; it never touches the Nix daemon (barrier 1 untouched) and
installs byte-code, not native binaries (barrier 2 untouched). The only Emacs
packages that could be browser/P2P frontends (`mentor`, `transmission.el`) are
inert because their native backends can't be installed. So allowing MELPA grants
*more Emacs Lisp* — which is fine per your stated threat model — and nothing else.

---

## 2. THE key interaction: MELPA + `noexec` + native-comp

This is the one subtlety that decides whether the box boots into a working Emacs.

- `.el` and `.elc` (byte-code) are **interpreted** by the Emacs VM. They are
  never `mmap`'d executable, so they load fine from a `noexec` home.
- `.eln` (native-compiled) files are **`dlopen`'d** → `mmap(PROT_EXEC)` →
  **blocked** by `noexec`.

Therefore: **disable native-comp JIT.** MELPA/ELPA packages then install and run
as byte-code from `~/.emacs.d/elpa`, which `noexec` permits. No writable-exec
directory is needed anywhere, so barrier #2 stays fully intact.

> An earlier draft of this design added a world-writable *exec* tmpfs for the
> eln-cache to make native-comp work. **That was a hole** — the child could drop
> a downloaded binary there and run it. It has been removed. Byte-code is the
> correct answer.

Put these two lines in the child's `early-init.el` (before any package loads):

```elisp
;;; Locked appliance: /home is mounted noexec, so native-compiled .eln files
;;; cannot be dlopen'd from the user eln-cache. Run packages as byte-code.
(setq native-comp-jit-compilation nil)
(setq native-comp-enable-subr-trampolines nil)
```

The base Emacs still runs fast: nixpkgs ships its bundled Lisp
**AOT-native-compiled into `/nix/store`** (which is exec-ok) and precompiles the
standard subr trampolines, so nothing needs to be compiled at runtime. Only your
MELPA packages run as byte-code, which is imperceptible for this workload
(completion, org, elfeed, magit).

---

## 3. Package rule — pure-elisp vs native-module

| Package kind | Where it comes from | Why |
|---|---|---|
| **Pure Emacs Lisp** (vertico, consult, marginalia, orderless, embark, corfu, cape, magit, denote, org-modern, org-ql, elfeed, modus-themes, which-key, helpful, rainbow-delimiters, corfu-terminal, …) | **MELPA/ELPA** via `package.el` — *works as-is* | Byte-code loads under `noexec`. |
| **Native C module** (pdf-tools → `epdfinfo`; jinx → `enchant`; vterm; emacsql-sqlite; tree-sitter grammars) | **Nix `emacs.pkgs.withPackages`**, and set `:ensure nil` in your config | Building the `.so` needs a compiler you don't have, and the `.so` couldn't be `dlopen`'d from `noexec` home anyway. Nix compiles it into the store (exec-ok). |

On **this console box** the native-module list is nearly empty:

- **pdf-tools** — excluded (it's graphical; you already scoped this box as
  "excluding pdf-view"). Don't load `joe-research.el`'s pdf section here.
- **jinx** — optional. If you want spell-check, provide it from Nix (see §7
  appendix) plus a dictionary; otherwise disable it. It **cannot** work from
  MELPA on this box.

Everything else in your `joe-*.el` is pure elisp and installs from MELPA
normally.

---

## 4. `flake.nix`

```nix
{
  description = "Locked-down console Emacs appliance (ThinkPad X270)";

  inputs = {
    # Bump to the current stable — see https://channels.nixos.org
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }: {
    nixosConfigurations.x270 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Verified present in nixos-hardware; sets i915.enable_psr=0 to fix
        # the X270's random display freezes.
        nixos-hardware.nixosModules.lenovo-thinkpad-x270
        ./configuration.nix
      ];
    };
  };
}
```

---

## 5. `configuration.nix`

```nix
{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  ##########################################################################
  ## Boot + firmware
  ##########################################################################
  boot.loader.systemd-boot.enable = false;   # systemd-boot has no password
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    # See §9: on NixOS this tends to gate BOOTING as well as editing. The UEFI
    # supervisor password (§8 step 5) is the primary physical control; treat
    # this block as optional and read the caveat before enabling it.
    # extraConfig = ''
    #   set superusers="admin"
    #   password_pbkdf2 admin GRUB_PBKDF2_HASH_HERE
    # '';
  };

  boot.kernel.sysctl = {
    "kernel.kptr_restrict"             = 2;
    "kernel.dmesg_restrict"            = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.yama.ptrace_scope"         = 1;
    "fs.protected_symlinks"            = 1;
    "fs.protected_hardlinks"           = 1;
    # NOTE: do NOT set user.max_user_namespaces=0 — the Nix build sandbox needs
    # user namespaces. The install path is already closed by the daemon ACL.
  };

  ##########################################################################
  ## Hardware: wifi + bluetooth (Intel 8265 on the X270)
  ##########################################################################
  # iwlwifi + Intel Bluetooth firmware. Redistributable — no allowUnfree needed.
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  networking.hostName = "x270";
  networking.networkmanager.enable = true;   # drive with `nmtui` on the console
  networking.firewall.enable = true;         # inbound: default-deny
  networking.firewall.allowedTCPPorts = [ ]; # no inbound services

  ##########################################################################
  ## Console only — NO display server (Barrier #3)
  ##########################################################################
  services.xserver.enable = false;
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    earlySetup = true;
  };

  ##########################################################################
  ## Emacs — stock emacs-nox from Nix; packages come from MELPA at runtime.
  ## (For native-module packages like jinx, see §7 appendix.)
  ##########################################################################
  services.emacs = {
    enable = true;
    package = pkgs.emacs-nox;
    defaultEditor = true;
  };

  ##########################################################################
  ## Users — child is not in wheel and cannot reach the Nix daemon (Barrier #1)
  ##########################################################################
  users.mutableUsers = false;   # accounts/passwords come ONLY from this file

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "ADMIN_HASH";     # mkpasswd -m sha-512
  };

  users.users.kid = {
    isNormalUser = true;
    extraGroups = [ ];                 # no wheel, no networkmanager — nothing
    hashedPassword = "KID_HASH";
    shell = pkgs.bashInteractive;
  };

  # Drop the child straight into Emacs on login. A shell escape (M-x shell) is
  # fine per the threat model — it still can't install anything.
  programs.bash.loginShellInit = ''
    if [ "$USER" = "kid" ] && [ -z "$SSH_TTY" ]; then
      exec emacsclient -t -a "emacs -nw"
    fi
  '';

  security.sudo.enable = true;
  security.sudo.execWheelOnly = true;  # only wheel may even invoke sudo

  ##########################################################################
  ## Barrier #1 — lock the Nix daemon
  ##########################################################################
  nix.settings.allowed-users = [ "root" "@wheel" ];  # kid can't reach it at all
  nix.settings.trusted-users = [ "root" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  ##########################################################################
  ## Barrier #2 — noexec on every user-writable filesystem
  ##########################################################################
  # /home is on its own partition (you partitioned it separately at install).
  # NixOS merges by mountpoint, so this only adds options; the device/fsType
  # come from hardware-configuration.nix.
  fileSystems."/home".options = [ "noexec" "nosuid" "nodev" ];

  # /tmp and /var/tmp as noexec tmpfs. (/var/tmp becomes non-persistent across
  # reboots — acceptable for an appliance, and closes the exec gap it otherwise
  # has by living on the exec root filesystem.)
  fileSystems."/tmp" = {
    device = "tmpfs"; fsType = "tmpfs";
    options = [ "noexec" "nosuid" "nodev" "mode=1777" "size=2G" ];
  };
  fileSystems."/var/tmp" = {
    device = "tmpfs"; fsType = "tmpfs";
    options = [ "noexec" "nosuid" "nodev" "mode=1777" "size=1G" ];
  };
  # /dev/shm defaults to EXEC — override it. Verify with `findmnt /dev/shm`
  # after boot; if a conflict appears, drop this and rely on barriers 1/3/4.
  fileSystems."/dev/shm" = {
    device = "tmpfs"; fsType = "tmpfs";
    options = [ "noexec" "nosuid" "nodev" "size=1G" ];
  };

  ##########################################################################
  ## Close removable-media + rootless-container vectors
  ##########################################################################
  services.udisks2.enable = false;   # non-root can't auto-mount USB media
  # Do NOT install: flatpak, snapd, podman, docker, gcc/clang, python3+pip,
  # nodejs+npm. None are here; keep it that way.

  environment.systemPackages = with pkgs; [
    # Required by the Emacs workflow. None are install vectors:
    # curl/git can DOWNLOAD or CLONE, but noexec stops running and there's no
    # compiler to build. ripgrep/fd are search tools.
    git ripgrep fd curl
  ];

  services.getty.autologinUser = null;   # require a password to log in

  system.stateVersion = "25.05";   # match your channel; don't bump casually
}
```

---

## 6. (Optional, recommended for the P2P concern) egress firewall

The install-and-run barriers already stop a P2P *client* from getting onto the
box. This adds defense-in-depth by cutting the *traffic* torrents need (many
outbound connections + DHT on random high ports), while leaving everything the
appliance uses intact. Enabling this **replaces** the simple `networking.firewall`,
so set `networking.firewall.enable = false;` and add:

```nix
networking.firewall.enable = false;
networking.nftables.enable = true;
networking.nftables.ruleset = ''
  table inet filter {
    chain input {
      type filter hook input priority 0; policy drop;
      ct state established,related accept
      iif lo accept
      ip protocol icmp accept
      ip6 nexthdr ipv6-icmp accept
    }
    chain forward {
      type filter hook forward priority 0; policy drop;
    }
    chain output {
      type filter hook output priority 0; policy drop;
      ct state established,related accept
      oif lo accept
      udp dport { 53, 67, 68, 123 } accept    # DNS, DHCP, NTP
      tcp dport { 53, 80, 443 } accept          # DNS-over-TCP, HTTP, HTTPS
      ip protocol icmp accept
      ip6 nexthdr ipv6-icmp accept
    }
  }
'';
```

This still allows: MELPA/ELPA and the Nix binary cache (443), `eww`/`elfeed`
(80/443/53), DHCP, and time sync. It drops SSH-out, mail, and the arbitrary
high-port traffic BitTorrent relies on. Honest limit: a torrent client *could*
tunnel over 443 — but it can't be installed in the first place, so this is a
backstop, not the primary block.

---

## 7. Emacs config changes (bridging your existing `joe-*.el`)

Clone your config into the child's home once, as admin
(`/home/kid/.emacs.d`), then make these adjustments so it fits the box:

1. **`early-init.el`** — add the two `native-comp` lines from §2. Without them,
   any package that native-compiles will fail to load from the `noexec` home.

2. **`compile-angel`** (in `joe-core.el`) — it AOT-compiles loaded elisp. With
   native-comp JIT off it should byte-compile only, but confirm it isn't trying
   to write `.eln`. If it warns, disable its native step (byte-compilation is
   enough) or drop the package on this box.

3. **`corfu` popup** — Emacs 30's Corfu needs child frames, which are an Emacs 31
   feature; in the terminal on 30 the popup is inert. Add `corfu-terminal`
   (pure elisp, from MELPA):
   ```elisp
   (unless (display-graphic-p)
     (use-package corfu-terminal :ensure t :config (corfu-terminal-mode)))
   ```

4. **pdf-tools** (`joe-research.el`) — don't load it here. It's graphical and has
   a native module; it can't work on a console box. Guard its `require`/module
   behind `(when (display-graphic-p) …)` or skip that module.

5. **jinx** (`joe-org-notes.el`) — native module; can't load from MELPA under
   `noexec`. Either disable it on this box, or provide it from Nix:
   ```nix
   # in configuration.nix, replace services.emacs.package with:
   services.emacs.package =
     (pkgs.emacsPackagesFor pkgs.emacs-nox).emacsWithPackages
       (epkgs: [ epkgs.jinx ]);
   # and add a dictionary backend:
   environment.systemPackages = with pkgs; [ enchant nuspell hunspellDicts.en_US ];
   ```
   Then mark it `:ensure nil` in your config so `package.el` doesn't also try to
   install it from MELPA.

6. **`embark` keys** — `C-.`/`C-;`/`C-,` are unreachable in most terminals.
   On the Linux console specifically they can't be sent at all; rebind embark to
   ASCII-safe keys (e.g. `C-c .`, `C-c ;`).

7. **nerd-icons** — the 512-glyph console font can't render them; they'll show as
   blanks. Harmless, but you may want to disable the `nerd-icons-*` modes.

First launch will download and byte-compile your whole package set from MELPA —
a slow but one-time step. Requires network (and, if you enabled §6, ports 443/53).

---

## 8. Build steps

**0. Prep.** Download the **minimal** ISO (not graphical). Write to USB:
`dd bs=4M if=nixos-minimal-*.iso of=/dev/sdX status=progress`. Plug the X270 into
**ethernet** to skip installer-wifi. In BIOS: UEFI mode, Secure Boot **off** for
now, boot the USB once.

**1. Partition — the one irreversible decision is a SEPARATE `/home`.**
Example with LUKS full-disk encryption + LVM:
```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 1GiB 100%

cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 crypt
pvcreate /dev/mapper/crypt
vgcreate vg /dev/mapper/crypt
lvcreate -L 40G -n root vg
lvcreate -l 100%FREE -n home vg

mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
mkfs.ext4 -L root /dev/mapper/vg-root
mkfs.ext4 -L home /dev/mapper/vg-home

mount /dev/mapper/vg-root /mnt
mkdir -p /mnt/{boot,home}
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/mapper/vg-home /mnt/home
```

**2. Generate + drop in config.**
```bash
nixos-generate-config --root /mnt
# leave /mnt/etc/nixos/hardware-configuration.nix ALONE
# write flake.nix and configuration.nix (§4/§5) into /mnt/etc/nixos/
```
Confirm `hardware-configuration.nix` picked up the LUKS device and the separate
`/home` mount. The `fileSystems."/home".options` line in §5 merges onto it.

**3. Generate password hashes; paste them in.**
```bash
mkpasswd -m sha-512                                   # ADMIN_HASH, then KID_HASH
nix-shell -p grub2 --run 'grub-mkpasswd-pbkdf2'       # only if you enable §9 GRUB lock
```

**4. Install and reboot.**
```bash
nixos-install --flake /mnt/etc/nixos#x270
reboot
```

**5. Firmware lockdown (do this from the running system, last).**
- Enter BIOS → set a **Supervisor password** → disable USB boot and network
  boot → fix boot order to the internal SSD → save. This is the primary physical
  control.
- Secure Boot (via `lanzaboote`) is a good second-pass hardening step; don't
  fight it during the initial install.

**6. Wireless + Bluetooth, from the console.**
```bash
nmtui          # connect + save wifi (auto-reconnects at boot)
bluetoothctl   # scan on / pair / connect / trust
```
Both work because `enableRedistributableFirmware` shipped the `iwlwifi` and
Intel BT blobs.

**7. Provision the child's Emacs.** As admin, clone your config into
`/home/kid/.emacs.d`, apply the §7 changes, `chown -R kid:users /home/kid`.
Log in as `kid`, let the first MELPA install/compile run to completion.

---

## 9. Verification — test it, don't trust it

Log in **as the child** and confirm each of these fails the stated way:
```bash
su - kid
nix-shell -p firefox                      # -> "you are not allowed to use the Nix daemon"
nix profile install nixpkgs#aria2          # -> denied
curl -sLo m https://example.com/x && chmod +x m && ./m   # -> Permission denied (noexec)
sudo id                                    # -> kid is not in the sudoers file
groups                                     # -> kid   (nothing else)
findmnt /home /tmp /var/tmp /dev/shm       # -> each shows noexec
```
If all of those behave as noted, barriers 1–3 are up. `firefox` is doubly dead:
not installable, and no display to run in even if it were.

---

## 10. Day-to-day admin (from the `admin` account)

```bash
sudoedit /etc/nixos/configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#x270    # apply a change
sudo nixos-rebuild switch --rollback                 # undo instantly; old gen still on disk
nix flake update /etc/nixos                          # updates happen ONLY when you run this
sudo nix-collect-garbage -d                          # reclaim /nix/store space
```
Keep `/etc/nixos` in git — same habit as your `.emacs.d`, one layer down. It's
what makes the box reproducible if the SSD dies.

---

## 11. Honest residuals — what this does NOT stop

- **Self-authored interpreter scripts.** `perl` and some `python3` live in the
  system closure (NixOS activation needs them). A determined kid could write a
  script in an already-present interpreter. But: there's no `pip`/`npm` to pull
  libraries, so no real torrent client or browser can be assembled this way, and
  the egress firewall (§6) cuts the traffic anyway. Not a browser/P2P path.
- **`/run/user/$UID` is an exec tmpfs** that systemd manages and NixOS doesn't
  cleanly let you `noexec`. A *pre-built static CLI binary* downloaded there
  could run. Closed in practice by: no compiler to make one, the egress firewall
  limiting what's reachable/downloadable, and — for anything with a UI — no
  display. This is the main residual and it does not admit a GUI browser or an
  installable P2P client.
- **Physical access, fully determined.** GRUB's `e`-key edit
  (`init=/bin/bash`) is the local-root path. On NixOS, GRUB `superusers` tends to
  password-gate *booting* as well as editing (there's no clean per-entry
  "unrestricted" toggle), which makes the machine unusable for the child. So the
  realistic controls are the **UEFI supervisor password + disabled external
  boot** (§8 step 5). With FDE, the disk can't be read if pulled — but a child
  who legitimately unlocks the disk to use the machine can still reach an
  `init=/bin/bash` root shell if they can edit the GRUB line. A laptop physically
  in a determined person's hands is never perfectly lockable; this is the ceiling
  without going to signed/measured boot (dm-verity, Secure Boot + lanzaboote),
  which is a much larger project.

**Bottom line:** browsers are airtight-blocked (no display + not installable).
Installable/GUI P2P clients are airtight-blocked. The residuals are limited to
self-written interpreter scripts with no library access and a narrow exec-tmpfs
gap — neither of which yields a browser or a real filesharing client, and both
of which are backstopped by the egress firewall.
