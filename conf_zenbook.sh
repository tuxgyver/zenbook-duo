#!/bin/bash

# zenbook_duo_linux_postinstall.sh
# Script d'installation et de configuration post-installation Ubuntu 25.04 pour ASUS Zenbook Duo UX8406CA-PZ011W
# Inclut correctifs pour WiFi, second écran, clavier BT, audio, suspend/hibernate
# Version améliorée avec support complet et gestion d'erreurs

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
LOG_FILE="/var/log/zenbook_duo_setup.log"
BACKUP_DIR="/root/zenbook_backup_$(date +%Y%m%d_%H%M%S)"

# Fonction de logging
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCÈS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1" | tee -a "$LOG_FILE"
}

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    error "Ce script doit être lancé avec sudo ou en tant que root."
    exit 1
fi

# Création du répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"

# Détection de la version du kernel
KERNEL_VERSION=$(uname -r | cut -d. -f1-2)
log "Version du kernel détectée: $KERNEL_VERSION"

# Vérification de la compatibilité Ubuntu
if ! grep -q "25.04" /etc/os-release 2>/dev/null; then
    warning "Ce script est optimisé pour Ubuntu 25.04. Version détectée : $(lsb_release -d | cut -f2)"
    read -p "Voulez-vous continuer ? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log "=== DÉBUT DE L'INSTALLATION ZENBOOK DUO UX8406CA-PZ011W ==="

### 1. SAUVEGARDE ET MISE À JOUR SYSTÈME ###
log "[1/8] Sauvegarde des configurations et mise à jour du système..."

# Sauvegarde des fichiers de configuration importants
cp /etc/default/grub "$BACKUP_DIR/grub.backup" 2>/dev/null || true
cp -r /etc/udev/rules.d "$BACKUP_DIR/udev_rules.backup" 2>/dev/null || true

# Mise à jour complète du système
apt update && apt full-upgrade -y

# Installation des paquets de base nécessaires
apt install -y \
    git curl wget build-essential dkms \
    linux-headers-$(uname -r) \
    linux-oem-22.04 linux-oem-22.04-edge \
    sof-firmware alsa-firmware-loaders \
    pipewire pipewire-pulse wireplumber \
    gnome-tweaks gnome-shell-extension-manager \
    linux-tools-common linux-tools-$(uname -r) \
    gnome-shell-extension-system-monitor \
    bluez bluez-tools rfkill \
    xorg-dev mesa-utils \
    mesa-va-drivers mesa-vdpau-drivers \
    mesa-vulkan-drivers mesa-opencl-icd \
    libegl1-mesa libegl1-mesa-dev \
    libgl1-mesa-glx libgl1-mesa-dev \
    libgles2-mesa libgles2-mesa-dev \
    va-driver-all vdpau-driver-all \
    intel-media-va-driver i965-va-driver \
    ubuntu-restricted-extras power-profiles-daemon \
    python3-pip python3-dev \
    acpi-support tlp tlp-rdw \
    brightnessctl ddcutil

success "Mise à jour système terminée"

### 1.5. VÉRIFICATION ET OPTIMISATION DES PILOTES MESA ###
log "[1.5/8] Vérification et optimisation des pilotes Mesa Intel..."

# Vérification de la présence du GPU Intel
if lspci | grep -i "vga.*intel" > /dev/null; then
    log "GPU Intel détecté, vérification des pilotes Mesa..."
    
    # Information sur la version Mesa installée
    mesa_version=$(glxinfo | grep "OpenGL version" 2>/dev/null || echo "Non détecté")
    log "Version Mesa : $mesa_version"
    
    # Configuration Mesa pour Intel Iris Xe (UX8406CA)
    mkdir -p /etc/environment.d
    cat <<EOF > /etc/environment.d/mesa-intel.conf
# Configuration Mesa pour Intel Iris Xe Graphics
MESA_LOADER_DRIVER_OVERRIDE=iris
INTEL_DEBUG=
LIBVA_DRIVER_NAME=iHD
VDPAU_DRIVER=va_gl
EOF

    # Variables d'environnement pour optimiser Mesa
    cat <<EOF >> /etc/environment
# Optimisations Mesa Intel Iris Xe
MESA_GL_VERSION_OVERRIDE=4.6
MESA_GLSL_VERSION_OVERRIDE=460
INTEL_DEBUG=
LIBVA_DRIVER_NAME=iHD
EOF

    # Test des capacités graphiques
    if command -v glxinfo >/dev/null 2>&1; then
        log "Test des capacités OpenGL..."
        glx_renderer=$(glxinfo | grep "OpenGL renderer" 2>/dev/null || echo "Non détecté")
        log "Rendu OpenGL : $glx_renderer"
        
        if glxinfo | grep -q "direct rendering: Yes"; then
            success "Accélération matérielle Mesa activée"
        else
            warning "Accélération matérielle non détectée - vérification nécessaire"
        fi
    fi
else
    warning "GPU Intel non détecté - pilotes Mesa génériques utilisés"
fi

success "Configuration Mesa terminée"

### 2. INSTALLATION ET CONFIGURATION DES SCRIPTS COMMUNAUTAIRES ###
log "[2/8] Installation des scripts zenbook-duo-linux et alesya-h..."

cd /opt

# Installation du script principal zenbook-duo-linux
if [ ! -d "zenbook-duo-linux" ]; then
    git clone https://github.com/fmstrat/zenbook-duo-linux.git
    cd zenbook-duo-linux
    chmod +x setup.sh
    ./setup.sh
    cd /opt
else
    log "zenbook-duo-linux déjà présent, mise à jour..."
    cd zenbook-duo-linux && git pull && cd /opt
fi

# Installation du script alesya-h pour la gestion avancée des écrans
if [ ! -d "zenbook-duo-2024-ux8406ma-linux" ]; then
    git clone https://github.com/alesya-h/zenbook-duo-2024-ux8406ma-linux.git
    cd zenbook-duo-2024-ux8406ma-linux
    
    # Installation des dépendances Python
    pip3 install -r requirements.txt 2>/dev/null || true
    
    # Installation du service
    if [ -f "install.sh" ]; then
        chmod +x install.sh
        ./install.sh
    fi
    cd /opt
else
    log "Script alesya-h déjà présent, mise à jour..."
    cd zenbook-duo-2024-ux8406ma-linux && git pull && cd /opt
fi

success "Scripts communautaires installés"

### 3. CONFIGURATION AVANCÉE DU GRUB ###
log "[3/8] Configuration avancée du GRUB pour optimiser le support matériel..."

# Sauvegarde du fichier GRUB
cp /etc/default/grub "$BACKUP_DIR/grub_$(date +%H%M%S).backup"

# Options GRUB optimisées pour UX8406CA
GRUB_OPTIONS="i915.enable_psr=0 i915.enable_fbc=0 i915.experimental_panel_flip=1 intel_idle.max_cstate=2 processor.max_cstate=2 acpi_backlight=vendor acpi_osi=Linux"

# Ajout des options au GRUB
if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
    sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $GRUB_OPTIONS\"/" /etc/default/grub
else
    echo "GRUB_CMDLINE_LINUX=\"$GRUB_OPTIONS\"" >> /etc/default/grub
fi

# Configuration additionnelle pour le second écran
if ! grep -q "GRUB_GFXMODE" /etc/default/grub; then
    echo "GRUB_GFXMODE=auto" >> /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg

success "Configuration GRUB terminée"

### 4. RÈGLES UDEV ET GESTION DES PÉRIPHÉRIQUES ###
log "[4/8] Configuration des règles udev pour Wi-Fi, Bluetooth et périphériques..."

cat <<EOF > /etc/udev/rules.d/99-zenbook-duo.rules
# Règles pour ASUS Zenbook Duo UX8406CA-PZ011W

# Gestion du Bluetooth et du clavier détachable
SUBSYSTEM=="bluetooth", ACTION=="add", RUN+="/opt/zenbook-duo-linux/handle_bluetooth.sh"
SUBSYSTEM=="input", ATTRS{name}=="*Zenbook*", RUN+="/bin/bash -c 'echo 1 > /sys/class/rfkill/rfkill0/state'"

# Désactivation automatique du mode avion au détachement
SUBSYSTEM=="platform", KERNEL=="asus-nb-wmi", ATTR{rfkill}="0"
ACTION=="change", SUBSYSTEM=="rfkill", KERNEL=="rfkill0", RUN+="/bin/bash -c 'echo 0 > /sys/class/rfkill/rfkill0/state'"

# Gestion automatique des écrans
SUBSYSTEM=="drm", ACTION=="change", RUN+="/opt/zenbook-duo-2024-ux8406ma-linux/screen_manager.py"

# Permissions pour la gestion de la luminosité
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", MODE="0666"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", MODE="0666"

# Support pour les capteurs
SUBSYSTEM=="iio", KERNEL=="iio:device*", MODE="0664", GROUP="input"
EOF

# Rechargement des règles udev
udevadm control --reload-rules
udevadm trigger

success "Règles udev configurées"

### 5. CONFIGURATION AUDIO ET MICROPHONE ###
log "[5/8] Configuration audio optimisée avec PipeWire..."

# Configuration PipeWire pour les doubles écrans
mkdir -p /etc/pipewire/pipewire-pulse.conf.d
cat <<EOF > /etc/pipewire/pipewire-pulse.conf.d/zenbook-duo.conf
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
}
EOF

# Redémarrage des services audio
systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true

success "Configuration audio terminée"

### 6. GESTION DE L'ÉNERGIE ET HIBERNATION ###
log "[6/8] Configuration de la gestion d'énergie et hibernation..."

# Configuration TLP pour une meilleure autonomie
cat <<EOF > /etc/tlp.d/01-zenbook-duo.conf
# Configuration TLP pour ASUS Zenbook Duo UX8406CA-PZ011W
TLP_ENABLE=1
TLP_DEFAULT_MODE=BAT
TLP_PERSISTENT_DEFAULT=0

# Processeur
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Gestion des écrans
INTEL_GPU_MIN_FREQ_ON_AC=100
INTEL_GPU_MIN_FREQ_ON_BAT=100
INTEL_GPU_MAX_FREQ_ON_AC=1300
INTEL_GPU_MAX_FREQ_ON_BAT=800

# Wi-Fi et Bluetooth
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
WOL_DISABLE=Y

# USB
USB_AUTOSUSPEND=1
USB_BLACKLIST_BTUSB=0
USB_BLACKLIST_PHONE=0
EOF

# Activation de TLP
systemctl enable tlp
systemctl start tlp

# Test et configuration de l'hibernation
if [ -f /sys/power/mem_sleep ]; then
    if grep -q "deep" /sys/power/mem_sleep; then
        echo "deep" > /sys/power/mem_sleep
        success "Mode d'hibernation profond activé"
    fi
else
    warning "Hibernation non supportée par ce kernel"
fi

success "Gestion d'énergie configurée"

### 7. INSTALLATION D'EXTENSIONS GNOME RECOMMANDÉES ###
log "[7/8] Installation d'extensions GNOME pour une meilleure expérience dual-screen..."

# Extensions recommandées pour dual-screen
extensions=(
    "system-monitor@paradoxxx.zero.gmail.com"
    "dash-to-panel@jderose9.github.com"
    "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
)

# Note: L'installation automatique d'extensions GNOME nécessite une session utilisateur
log "Extensions recommandées à installer manuellement via GNOME Extensions :"
for ext in "${extensions[@]}"; do
    log "  - $ext"
done

success "Liste des extensions fournie"

### 8. SCRIPTS DE DÉMARRAGE ET SERVICES ###
log "[8/8] Configuration des services et scripts de démarrage..."

# Service pour la gestion automatique des écrans
cat <<EOF > /etc/systemd/system/zenbook-screen-manager.service
[Unit]
Description=Zenbook Duo Screen Manager
After=graphical-session.target

[Service]
Type=simple
ExecStart=/opt/zenbook-duo-2024-ux8406ma-linux/screen_manager.py
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# Activation du service
systemctl daemon-reload
systemctl enable zenbook-screen-manager.service

# Script de post-boot pour les ajustements finaux
cat <<'EOF' > /usr/local/bin/zenbook-post-boot.sh
#!/bin/bash
# Script post-boot pour ASUS Zenbook Duo

# Attendre que le système soit complètement chargé
sleep 10

# Forcer l'activation du second écran
echo 1 > /sys/class/drm/card0-eDP-2/enabled 2>/dev/null || true

# Optimisation des fréquences GPU
echo 100 > /sys/class/drm/card0/gt/gt0/rps_min_freq_mhz 2>/dev/null || true
echo 1300 > /sys/class/drm/card0/gt/gt0/rps_max_freq_mhz 2>/dev/null || true

# Gestion du Bluetooth
rfkill unblock bluetooth
systemctl restart bluetooth

exit 0
EOF

chmod +x /usr/local/bin/zenbook-post-boot.sh

# Service systemd pour le script post-boot
cat <<EOF > /etc/systemd/system/zenbook-post-boot.service
[Unit]
Description=Zenbook Duo Post-Boot Configuration
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/zenbook-post-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zenbook-post-boot.service

success "Services configurés"

### FINALISATION ###
log "=== FINALISATION ET NETTOYAGE ==="

# Nettoyage des paquets inutiles
apt autoremove -y
apt autoclean

# Génération du rapport de configuration
cat <<EOF > /root/zenbook_duo_config_report.txt
=== RAPPORT DE CONFIGURATION ZENBOOK DUO UX8406CA-PZ011W ===
Date d'installation : $(date)
Kernel version : $(uname -r)
Ubuntu version : $(lsb_release -d | cut -f2)

Fichiers de sauvegarde : $BACKUP_DIR
Log d'installation : $LOG_FILE

Scripts installés :
- zenbook-duo-linux (Fmstrat)
- zenbook-duo-2024-ux8406ma-linux (alesya-h)

Services activés :
- zenbook-screen-manager.service
- zenbook-post-boot.service
- tlp.service

Configuration GRUB :
$(grep GRUB_CMDLINE_LINUX /etc/default/grub)

=== PROCHAINES ÉTAPES ===
1. Redémarrer le système
2. Installer manuellement les extensions GNOME recommandées
3. Configurer les écrans dans Paramètres > Affichage
4. Tester le clavier Bluetooth détachable

=== DÉPANNAGE ===
En cas de problème :
- Consulter le log : $LOG_FILE
- Restaurer GRUB : cp $BACKUP_DIR/grub.backup /etc/default/grub
- Vérifier les services : systemctl status zenbook-screen-manager
EOF

success "=== INSTALLATION TERMINÉE AVEC SUCCÈS ==="
success "Rapport de configuration généré : /root/zenbook_duo_config_report.txt"
warning "REDÉMARRAGE OBLIGATOIRE pour activer tous les changements"

# Proposition de redémarrage automatique
read -p "Voulez-vous redémarrer maintenant ? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Redémarrage en cours..."
    reboot
else
    log "N'oubliez pas de redémarrer le système pour finaliser l'installation !"
fi
