#!/usr/bin/env bash
# =============================================================================
# CachyOS EU-Only Mirror Rating Script
# =============================================================================
# Copyright (C) 2024-2026 CachyOS Community
#
# Beschreibung: Dieses Skript aktualisiert die Mirror-Listen von CachyOS und
#               Arch Linux, sodass nur europäische (EU) Server verwendet werden.
#
# Quellen:
#   - https://github.com/westandskif/rate-mirrors
#   - https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-rate-mirrors
#   - https://wiki.archlinux.org/title/Mirrors
#
# Lizenz: GPL-2.0-or-later
# =============================================================================
set -euo pipefail

# =============================================================================
# Konfiguration
# =============================================================================
readonly MIRRORS_DIR="/etc/pacman.d"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_TAG="cachyos-rate-mirrors-eu"

# EU-Mitgliedstaaten (ISO 3166-1 alpha-2) - Stand 2024
readonly EU_COUNTRIES="AT,BE,BG,HR,CY,CZ,DK,EE,FI,FR,DE,GR,HU,IE,IT,LV,LT,LU,NL,PL,PT,RO,SK,SI,ES,SE"

# Nicht-EU-Länder (für Referenz, wird nicht mehr verwendet)
# readonly NON_EU_COUNTRIES="US,CN,RU,BY,JP,KR,AU,BR,CA,IN,SG,TW,HK,UA,CH,NO,GB,IS,RS,MD,AL,MK,ME,BA,XK,TR,NZ,ZA,AR,CL,MX,ID,TH,VN,PH,MY"

# Rate-mirrors Einstellungen
export RATE_MIRRORS_PROTOCOL="${RATE_MIRRORS_PROTOCOL:-https}"
export RATE_MIRRORS_FETCH_MIRRORS_TIMEOUT="${RATE_MIRRORS_FETCH_MIRRORS_TIMEOUT:-30000}"
export RATE_MIRRORS_ALLOW_ROOT=true
export RATE_MIRRORS_MAX_DELAY="${RATE_MIRRORS_MAX_DELAY:-10000}"
export RATE_MIRRORS_ENTRY_COUNTRY="${RATE_MIRRORS_ENTRY_COUNTRY:-DE}"

# Netzwerk-Test-Timeouts
readonly CONNECTIVITY_TIMEOUT=10
readonly CONNECTIVITY_URL="https://archlinux.org"

# =============================================================================
# Farben und Logging
# =============================================================================
disable_colors() {
    unset ALL_OFF BOLD BLUE GREEN RED YELLOW
    ALL_OFF="" BOLD="" BLUE="" GREEN="" RED="" YELLOW=""
}

enable_colors() {
    if [[ -t 2 ]] && command -v tput &>/dev/null && tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        BLUE="${BOLD}$(tput setaf 4)"
    else
        ALL_OFF="\e[0m"
        BOLD="\e[1m"
        RED="${BOLD}\e[31m"
        GREEN="${BOLD}\e[32m"
        YELLOW="${BOLD}\e[33m"
        BLUE="${BOLD}\e[34m"
    fi
}

# Terminal-Farben aktivieren wenn möglich
if [[ -t 2 ]]; then
    enable_colors
else
    disable_colors
fi

msg() {
    local mesg="$1"; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

info() {
    local mesg="$1"; shift
    printf "${YELLOW} -->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
    local mesg="$1"; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
    logger -t "${LOG_TAG}" -p user.err "ERROR: ${mesg}"
}

success() {
    local mesg="$1"; shift
    printf "${GREEN}==> SUCCESS:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
    logger -t "${LOG_TAG}" -p user.info "SUCCESS: ${mesg}"
}

# =============================================================================
# Hilfsfunktionen
# =============================================================================
cleanup() {
    local exit_code="${1:-0}"
    [[ -n "${TMPFILE:-}" ]] && rm -f -- "$TMPFILE"
    exit "$exit_code"
}

die() {
    (( $# )) && error "$@"
    cleanup 255
}

trap 'cleanup' EXIT
trap 'die "Interrupt signal received"' INT TERM

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        die "Dieses Skript muss als Root ausgeführt werden (sudo %s)" "$SCRIPT_NAME"
    fi
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in rate-mirrors curl cp mv chmod; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Fehlende Abhängigkeiten: %s\nInstallieren mit: sudo pacman -S rate-mirrors curl" "${missing_deps[*]}"
    fi
}

check_connectivity() {
    info "Prüfe Internetverbindung..."
    
    if ! curl --connect-timeout "$CONNECTIVITY_TIMEOUT" -sSfL "$CONNECTIVITY_URL" -o /dev/null 2>&1; then
        die "Keine Internetverbindung verfügbar. Bitte Netzwerk prüfen."
    fi
    
    info "Internetverbindung OK"
}

detect_country() {
    info "Ermittle aktuellen Standort..."
    
    local country
    country="$(curl --connect-timeout "$CONNECTIVITY_TIMEOUT" -sSL 'https://geoip.kde.org/v1/ubiquity' 2>/dev/null | grep -Po '<CountryCode>\K([A-Z]{2})' || echo "")"
    
    if [[ -n "$country" ]]; then
        info "Erkanntes Land: %s" "$country"
        
        # Prüfe ob das erkannte Land in der EU ist
        if [[ ",${EU_COUNTRIES}," == *",${country},"* ]]; then
            export RATE_MIRRORS_ENTRY_COUNTRY="$country"
            info "Verwende %s als Startland (EU-Mitglied)" "$country"
        else
            info "Erkanntes Land %s ist nicht in der EU, verwende DE als Startland" "$country"
            export RATE_MIRRORS_ENTRY_COUNTRY="DE"
        fi
    else
        info "Land konnte nicht ermittelt werden, verwende DE als Standard"
        export RATE_MIRRORS_ENTRY_COUNTRY="DE"
    fi
}

# =============================================================================
# Mirror-Rating Funktionen
# =============================================================================
rate_repository_mirrors() {
    local repo="$1"
    local mirror_file="$2"
    local max_delay="${3:-10000}"
    
    info "Bewerte Mirrors für %s Repository..." "$repo"
    info "Zieldatei: %s" "$mirror_file"
    info "Erlaubte EU-Länder: %s" "$EU_COUNTRIES"
    
    # Prüfe ob Zieldatei existiert
    if [[ ! -f "$mirror_file" ]]; then
        local pkg
        pkg="$(pacman -Fq "$mirror_file" 2>/dev/null || echo "unbekannt")"
        die "Datei %s existiert nicht! Installieren Sie das Paket: %s" "$mirror_file" "$pkg"
    fi
    
    # Erstelle temporäre Datei
    TMPFILE="$(mktemp)"
    
    # Führe rate-mirrors aus mit EU-Filter (nur EU-Länder einschließen)
    if rate-mirrors \
        --save="$TMPFILE" \
        --entry-country="${RATE_MIRRORS_ENTRY_COUNTRY}" \
        --include-countries="${EU_COUNTRIES}" \
        --allow-root \
        "$repo"; then
        
        # Backup erstellen und neue Mirrorlist installieren
        cp -f --backup=simple --suffix="-backup" "$TMPFILE" "$mirror_file"
        
        # Berechtigungen setzen (lesbar für alle)
        chmod 644 "$mirror_file"
        
        success "Mirror-Liste für %s aktualisiert: %s" "$repo" "$mirror_file"
        
        # Zeige erste 5 Server
        info "Top 5 Server:"
        grep -m 5 "^Server" "$mirror_file" | head -5 || true
        
    else
        local exit_code=$?
        error "rate-mirrors für %s fehlgeschlagen (Exit-Code: %d)" "$repo" "$exit_code"
        return 1
    fi
    
    rm -f "$TMPFILE"
    TMPFILE=""
}

update_cachyos_variants() {
    local base_mirrorlist="${MIRRORS_DIR}/cachyos-mirrorlist"
    
    # CachyOS v3 (x86-64-v3) Mirrorlist
    if [[ -f "${MIRRORS_DIR}/cachyos-v3-mirrorlist" ]]; then
        info "Aktualisiere cachyos-v3-mirrorlist..."
        cp -f --backup=simple --suffix="-backup" "$base_mirrorlist" "${MIRRORS_DIR}/cachyos-v3-mirrorlist"
        sed -i 's|/\$arch/|/\$arch_v3/|g' "${MIRRORS_DIR}/cachyos-v3-mirrorlist"
        chmod 644 "${MIRRORS_DIR}/cachyos-v3-mirrorlist"
        success "cachyos-v3-mirrorlist aktualisiert"
    fi
    
    # CachyOS v4 (x86-64-v4) Mirrorlist
    if [[ -f "${MIRRORS_DIR}/cachyos-v4-mirrorlist" ]]; then
        info "Aktualisiere cachyos-v4-mirrorlist..."
        cp -f --backup=simple --suffix="-backup" "$base_mirrorlist" "${MIRRORS_DIR}/cachyos-v4-mirrorlist"
        sed -i 's|/\$arch/|/\$arch_v4/|g' "${MIRRORS_DIR}/cachyos-v4-mirrorlist"
        chmod 644 "${MIRRORS_DIR}/cachyos-v4-mirrorlist"
        success "cachyos-v4-mirrorlist aktualisiert"
    fi
}

# =============================================================================
# Hauptprogramm
# =============================================================================
main() {
    msg "CachyOS EU-Only Mirror Rating Script"
    msg "====================================="
    info "Startzeit: %s" "$(date '+%Y-%m-%d %H:%M:%S')"
    info "Erlaubte EU-Länder: %s" "$EU_COUNTRIES"
    
    # Vorprüfungen
    check_root
    check_dependencies
    check_connectivity
    detect_country
    
    # Arch Linux Mirrors aktualisieren
    msg "Aktualisiere Arch Linux Mirrors..."
    if rate_repository_mirrors "arch" "${MIRRORS_DIR}/mirrorlist" 21600; then
        success "Arch Linux Mirrors erfolgreich aktualisiert"
    else
        error "Arch Linux Mirror-Update fehlgeschlagen"
    fi
    
    # CachyOS Mirrors aktualisieren (falls installiert)
    if [[ -f "${MIRRORS_DIR}/cachyos-mirrorlist" ]]; then
        msg "Aktualisiere CachyOS Mirrors..."
        if rate_repository_mirrors "cachyos" "${MIRRORS_DIR}/cachyos-mirrorlist" 10000; then
            success "CachyOS Mirrors erfolgreich aktualisiert"
            
            # Varianten aktualisieren
            update_cachyos_variants
        else
            error "CachyOS Mirror-Update fehlgeschlagen"
        fi
    else
        info "CachyOS-Mirrorlist nicht gefunden, überspringe..."
    fi
    
    # Berechtigungen für alle Mirrorlists sicherstellen
    chmod go+r "${MIRRORS_DIR}"/*mirrorlist* 2>/dev/null || true
    
    msg "====================================="
    success "Mirror-Update abgeschlossen!"
    info "Endzeit: %s" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Log-Eintrag
    logger -t "${LOG_TAG}" -p user.info "EU-Mirror-Update erfolgreich abgeschlossen"
}

# Skript ausführen
main "$@"
