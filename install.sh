#!/usr/bin/env bash
# =============================================================================
# CachyOS EU Mirror Management - Installer
# =============================================================================
# Beschreibung: Installiert das EU-Mirror-Skript und die systemd-Services
# Verwendung: sudo ./install.sh
#
# Optionen:
#   --uninstall     Deinstalliert alle Komponenten
#   --service-only  Installiert nur den Service (ohne Timer/Resume)
#   --help          Zeigt diese Hilfe
# =============================================================================
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="cachyos-rate-mirrors-eu"
readonly INSTALL_DIR="/usr/local/bin"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

msg() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==> WARNUNG:${NC} $1"; }
error() { echo -e "${RED}==> FEHLER:${NC} $1" >&2; }

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Dieses Skript muss als Root ausgeführt werden"
        echo "Verwenden Sie: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    local missing=()
    
    for cmd in rate-mirrors curl systemctl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Fehlende Abhängigkeiten: ${missing[*]}"
        echo "Installieren mit: sudo pacman -S rate-mirrors curl"
        exit 1
    fi
}

install_script() {
    msg "Installiere Skript nach ${INSTALL_DIR}/${SCRIPT_NAME}..."
    
    cp -f "${SCRIPT_DIR}/scripts/cachyos-rate-mirrors-eu.sh" "${INSTALL_DIR}/${SCRIPT_NAME}"
    chown root:root "${INSTALL_DIR}/${SCRIPT_NAME}"
    chmod 755 "${INSTALL_DIR}/${SCRIPT_NAME}"
    
    msg "Skript installiert"
}

install_services() {
    local service_only="${1:-false}"
    
    msg "Installiere systemd-Service..."
    cp -f "${SCRIPT_DIR}/systemd/cachyos-rate-mirrors-eu.service" "${SYSTEMD_DIR}/"
    
    if [[ "$service_only" != "true" ]]; then
        msg "Installiere systemd-Timer..."
        cp -f "${SCRIPT_DIR}/systemd/cachyos-rate-mirrors-eu.timer" "${SYSTEMD_DIR}/"
        
        msg "Installiere Resume-Service..."
        cp -f "${SCRIPT_DIR}/systemd/cachyos-rate-mirrors-eu-resume.service" "${SYSTEMD_DIR}/"
    fi
    
    msg "Lade systemd-Konfiguration neu..."
    systemctl daemon-reload
    
    msg "systemd-Dateien installiert"
}

enable_services() {
    local service_only="${1:-false}"
    
    msg "Aktiviere Service für Boot..."
    systemctl enable "${SCRIPT_NAME}.service"
    
    if [[ "$service_only" != "true" ]]; then
        msg "Aktiviere Timer..."
        systemctl enable --now "${SCRIPT_NAME}.timer"
        
        msg "Aktiviere Resume-Service..."
        systemctl enable "${SCRIPT_NAME}-resume.service"
    fi
    
    msg "Services aktiviert"
}

uninstall() {
    msg "Deinstalliere CachyOS EU Mirror Management..."
    
    # Services deaktivieren und stoppen
    systemctl disable --now "${SCRIPT_NAME}.timer" 2>/dev/null || true
    systemctl disable "${SCRIPT_NAME}.service" 2>/dev/null || true
    systemctl disable "${SCRIPT_NAME}-resume.service" 2>/dev/null || true
    
    # Dateien entfernen
    rm -f "${INSTALL_DIR}/${SCRIPT_NAME}"
    rm -f "${SYSTEMD_DIR}/${SCRIPT_NAME}.service"
    rm -f "${SYSTEMD_DIR}/${SCRIPT_NAME}.timer"
    rm -f "${SYSTEMD_DIR}/${SCRIPT_NAME}-resume.service"
    
    # systemd neu laden
    systemctl daemon-reload
    
    msg "Deinstallation abgeschlossen"
}

show_status() {
    echo ""
    msg "=== Installation Status ==="
    echo ""
    
    echo "Skript: ${INSTALL_DIR}/${SCRIPT_NAME}"
    if [[ -x "${INSTALL_DIR}/${SCRIPT_NAME}" ]]; then
        echo -e "  Status: ${GREEN}Installiert${NC}"
    else
        echo -e "  Status: ${RED}Nicht installiert${NC}"
    fi
    
    echo ""
    echo "Service: ${SCRIPT_NAME}.service"
    if systemctl is-enabled "${SCRIPT_NAME}.service" &>/dev/null; then
        echo -e "  Status: ${GREEN}Aktiviert${NC}"
    else
        echo -e "  Status: ${YELLOW}Deaktiviert${NC}"
    fi
    
    echo ""
    echo "Timer: ${SCRIPT_NAME}.timer"
    if systemctl is-enabled "${SCRIPT_NAME}.timer" &>/dev/null; then
        echo -e "  Status: ${GREEN}Aktiviert${NC}"
        systemctl list-timers "${SCRIPT_NAME}.timer" --no-pager 2>/dev/null | tail -n +2 | head -1
    else
        echo -e "  Status: ${YELLOW}Deaktiviert${NC}"
    fi
    
    echo ""
    echo "Resume-Service: ${SCRIPT_NAME}-resume.service"
    if systemctl is-enabled "${SCRIPT_NAME}-resume.service" &>/dev/null; then
        echo -e "  Status: ${GREEN}Aktiviert${NC}"
    else
        echo -e "  Status: ${YELLOW}Deaktiviert${NC}"
    fi
    
    echo ""
}

show_help() {
    cat << EOF
CachyOS EU Mirror Management - Installer

Verwendung: sudo $0 [OPTION]

Optionen:
  --install         Vollständige Installation (Standard)
  --service-only    Installiert nur den Boot-Service (ohne Timer/Resume)
  --uninstall       Deinstalliert alle Komponenten
  --status          Zeigt den aktuellen Status
  --run             Führt das Skript einmalig aus
  --help            Zeigt diese Hilfe

Beispiele:
  sudo $0                    # Vollständige Installation
  sudo $0 --service-only     # Nur Boot-Service
  sudo $0 --status           # Status anzeigen
  sudo $0 --run              # Einmalig ausführen
  sudo $0 --uninstall        # Deinstallation

Dateien:
  Skript:        ${INSTALL_DIR}/${SCRIPT_NAME}
  Service:       ${SYSTEMD_DIR}/${SCRIPT_NAME}.service
  Timer:         ${SYSTEMD_DIR}/${SCRIPT_NAME}.timer
  Resume:        ${SYSTEMD_DIR}/${SCRIPT_NAME}-resume.service

EOF
}

main() {
    local action="${1:-install}"
    
    case "$action" in
        --help|-h)
            show_help
            exit 0
            ;;
        --status)
            check_root
            show_status
            exit 0
            ;;
        --uninstall)
            check_root
            uninstall
            exit 0
            ;;
        --run)
            check_root
            check_dependencies
            if [[ -x "${INSTALL_DIR}/${SCRIPT_NAME}" ]]; then
                "${INSTALL_DIR}/${SCRIPT_NAME}"
            else
                error "Skript nicht installiert. Führen Sie zuerst '$0 --install' aus."
                exit 1
            fi
            exit 0
            ;;
        --service-only)
            check_root
            check_dependencies
            install_script
            install_services true
            enable_services true
            show_status
            ;;
        --install|install|"")
            check_root
            check_dependencies
            install_script
            install_services false
            enable_services false
            show_status
            msg "Installation abgeschlossen!"
            echo ""
            echo "Nächste Schritte:"
            echo "  1. Einmalig ausführen:  sudo ${SCRIPT_NAME}"
            echo "  2. Timer-Status:        systemctl list-timers ${SCRIPT_NAME}.timer"
            echo "  3. Logs anzeigen:       journalctl -u ${SCRIPT_NAME}.service"
            ;;
        *)
            error "Unbekannte Option: $action"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
