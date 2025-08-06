#!/bin/bash
# zenbook_duo_linux_postinstall.sh
# Script d'installation et de configuration post-installation Ubuntu 25.04 pour ASUS Zenbook Duo UX8406CA-PZ011W
# Inclut correctifs pour WiFi, second écran, clavier BT, audio, suspend/hibernate

set -e

# Vérifie que le script est lancé en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être lancé avec sudo ou en tant que root."
  exit 1
fi

### 1. MISE À JOUR SYSTÈME ET INSTALLATIONS DE BASE ###
echo "[1/6] Mise à jour du système et installation des paquets nécessaires..."
apt update && apt full-upgrade -y
apt install -y git curl sof-firmware linux-oem-22.04 pipewire wireplumber \
               gnome-tweaks gnome-shell-extension-manager linux-tools-common \
               linux-tools-`uname -r` gnome-shell-extension-system-monitor

### 2. INSTALLATION DU SCRIPT ZENBOOK DUO LINUX ###
echo "[2/6] Clonage et installation du script zenbook-duo-linux..."
cd /opt
git clone https://github.com/fmstrat/zenbook-duo-linux.git
cd zenbook-duo-linux
chmod +x setup.sh
./setup.sh

### 3. CONFIGURATION DU GRUB POUR LE SECOND ÉCRAN ###
echo "[3/6] Ajout des options de démarrage pour i915..."
sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 i915.experimental_panel_flip=1"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

### 4. CORRECTIF POUR WIFI/Bluetooth MODE AVION AU DETACHEMENT ###
echo "[4/6] Application des règles udev pour Wi-Fi et clavier Bluetooth..."
cat <<EOF > /etc/udev/rules.d/99-zenbook-duo.rules
SUBSYSTEM=="bluetooth", ACTION=="add", RUN+="/opt/zenbook-duo-linux/handle_bluetooth.sh"
SUBSYSTEM=="platform", KERNEL=="asus-nb-wmi", ATTR{rfkill}="0"
EOF

### 5. ACTIVATION DU MODE HIBERNATION SÛR ###
echo "[5/6] Vérification de la prise en charge de l'hibernation..."
if grep -q mem_sleep /sys/power/state; then
  echo "hibernation supportée."
else
  echo "hibernation non détectée : ajout de l’option intel_idle"
  sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 intel_idle.slp_resume=1"/' /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
fi

### 6. FINALISATION ###
echo "[6/6] Nettoyage et fin. Reboot recommandé."
echo "Toutes les modifications sont appliquées. Redémarrez pour activer les changements."
