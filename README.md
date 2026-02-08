# CachyOS EU Mirror Management

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

**Deutsche Dokumentation für die Mirror-Verwaltung von CachyOS mit EU-Only-Filterung**

Dieses Repository enthält Skripte und Dokumentation zur Konfiguration der Mirror-Verwaltung von CachyOS, sodass ausschließlich europäische (EU) Server verwendet werden.

---

## 🎯 Funktionen

- ✅ Automatische Filterung auf EU-Mitgliedstaaten
- ✅ Unterstützung für Arch Linux und CachyOS Repositories
- ✅ Robuste Fehlerbehandlung (Netzwerk-Checks, Root-Prüfung)
- ✅ Systemd-Integration für Autostart und periodische Aktualisierung
- ✅ Power Management Integration (Sleep/Wake Hooks)
- ✅ Automatische Backups der Mirror-Listen
- ✅ Farbige Terminal-Ausgabe mit Logging

---

## 📋 Voraussetzungen

- CachyOS oder Arch Linux basiertes System
- `rate-mirrors` Paket (aus dem offiziellen Repository)
- `curl` für Netzwerkprüfungen
- Root-Rechte für die Installation

### Installation der Abhängigkeiten

```bash
sudo pacman -S rate-mirrors curl
```

---

## 🚀 Schnellstart

### 1. Repository klonen

```bash
git clone https://github.com/MaxMeyer32154/cachy.git
cd cachy
```

### 2. Installation

```bash
# Vollständige Installation (Service + Timer + Resume-Hook)
sudo ./install.sh

# Oder nur Service für Boot-Ausführung
sudo ./install.sh --service-only
```

### 3. Einmalige Ausführung

```bash
sudo ./install.sh --run
# Oder direkt:
sudo cachyos-rate-mirrors-eu
```

---

## 📁 Projektstruktur

```
.
├── docs/
│   └── EU-Mirror-Management-Guide.md    # Ausführliche Dokumentation
├── scripts/
│   └── cachyos-rate-mirrors-eu.sh       # Haupt-Skript
├── systemd/
│   ├── cachyos-rate-mirrors-eu.service  # Systemd Service
│   ├── cachyos-rate-mirrors-eu.timer    # Timer für periodische Ausführung
│   └── cachyos-rate-mirrors-eu-resume.service  # Sleep/Wake Hook
├── install.sh                            # Installations-Skript
└── README.md                             # Diese Datei
```

---

## 🌍 EU-Länder (ISO 3166-1 alpha-2)

Das Skript filtert auf folgende EU-Mitgliedstaaten (Stand 2024):

| Code | Land | Code | Land |
|------|------|------|------|
| AT | Österreich | HU | Ungarn |
| BE | Belgien | IE | Irland |
| BG | Bulgarien | IT | Italien |
| HR | Kroatien | LV | Lettland |
| CY | Zypern | LT | Litauen |
| CZ | Tschechien | LU | Luxemburg |
| DK | Dänemark | NL | Niederlande |
| EE | Estland | PL | Polen |
| FI | Finnland | PT | Portugal |
| FR | Frankreich | RO | Rumänien |
| DE | Deutschland | SK | Slowakei |
| GR | Griechenland | SI | Slowenien |
| ES | Spanien | SE | Schweden |

> **Hinweis:** GB (Vereinigtes Königreich), CH (Schweiz) und NO (Norwegen) sind keine EU-Mitglieder.

---

## ⚙️ Konfiguration

### Umgebungsvariablen

Das Skript kann über Umgebungsvariablen angepasst werden:

```bash
# Startland für Mirror-Suche (Standard: automatische Erkennung oder DE)
export RATE_MIRRORS_ENTRY_COUNTRY=DE

# Protokoll (Standard: https)
export RATE_MIRRORS_PROTOCOL=https

# Maximale Mirror-Verzögerung in ms (Standard: 10000)
export RATE_MIRRORS_MAX_DELAY=10000

# Timeout für Mirror-Fetch in ms (Standard: 30000)
export RATE_MIRRORS_FETCH_MIRRORS_TIMEOUT=30000
```

### Systemd-Timer anpassen

Bearbeiten Sie `/etc/systemd/system/cachyos-rate-mirrors-eu.timer`:

```ini
[Timer]
# Wöchentlich (Standard)
OnCalendar=Sun *-*-* 03:00:00

# Täglich
# OnCalendar=*-*-* 04:00:00

# Alle 3 Tage
# OnCalendar=*-*-1,4,7,10,13,16,19,22,25,28 03:00:00
```

Nach Änderungen:
```bash
sudo systemctl daemon-reload
sudo systemctl restart cachyos-rate-mirrors-eu.timer
```

---

## 📖 Dokumentation

Ausführliche technische Dokumentation finden Sie unter:

➡️ [docs/EU-Mirror-Management-Guide.md](docs/EU-Mirror-Management-Guide.md)

Enthält:
- Detaillierte Konfigurationsanalyse
- Rate-mirrors Befehlsoptionen
- Sicherheitshinweise
- Power Management Integration
- Polkit-Konfiguration

---

## 🔧 Befehle

| Befehl | Beschreibung |
|--------|-------------|
| `sudo ./install.sh` | Vollständige Installation |
| `sudo ./install.sh --service-only` | Nur Boot-Service installieren |
| `sudo ./install.sh --uninstall` | Deinstallation |
| `sudo ./install.sh --status` | Status anzeigen |
| `sudo ./install.sh --run` | Einmalig ausführen |
| `sudo cachyos-rate-mirrors-eu` | Skript direkt ausführen |
| `systemctl status cachyos-rate-mirrors-eu.service` | Service-Status |
| `systemctl list-timers cachyos-rate-mirrors-eu.timer` | Timer-Status |
| `journalctl -u cachyos-rate-mirrors-eu.service` | Logs anzeigen |

---

## 🔒 Sicherheit

- Das Skript benötigt Root-Rechte nur für das Schreiben in `/etc/pacman.d/`
- Systemd-Service verwendet Sicherheitsoptionen (`ProtectSystem`, `PrivateTmp`)
- Automatische Backups der Mirror-Listen werden erstellt
- Logging über systemd-journal und syslog

---

## 📚 Referenzen

- [Arch Wiki - Mirrors](https://wiki.archlinux.org/title/Mirrors)
- [Arch Wiki - Systemd/Timers](https://wiki.archlinux.org/title/Systemd/Timers)
- [CachyOS Wiki](https://wiki.cachyos.org)
- [rate-mirrors GitHub](https://github.com/westandskif/rate-mirrors)
- [CachyOS-PKGBUILDS](https://github.com/CachyOS/CachyOS-PKGBUILDS)

---

## 📄 Lizenz

Dieses Projekt steht unter der [GNU General Public License v2.0](LICENSE).

---

## 🤝 Mitwirken

Beiträge sind willkommen! Bitte erstellen Sie einen Issue oder Pull Request.

---

**Erstellt mit ❤️ für die CachyOS Community**
