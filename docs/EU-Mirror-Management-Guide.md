# CachyOS Mirror Management - EU-Only Configuration Guide

> **Letzte Aktualisierung:** Februar 2026  
> **Ziel:** Mirror-Verwaltung von CachyOS ausschließlich auf europäische Server beschränken  
> **Quellen:** [Arch Wiki](https://wiki.archlinux.org), [CachyOS Wiki](https://wiki.cachyos.org), [rate-mirrors GitHub](https://github.com/westandskif/rate-mirrors), [CachyOS-PKGBUILDS](https://github.com/CachyOS/CachyOS-PKGBUILDS)

---

## Inhaltsverzeichnis

1. [Konfigurationsanalyse](#1-konfigurationsanalyse)
2. [Befehlsoptimierung](#2-befehlsoptimierung)
3. [Robustes Bash-Skript](#3-robustes-bash-skript)
4. [Systemd-Service für Autostart](#4-systemd-service-für-autostart)
5. [Energieverwaltung Integration](#5-energieverwaltung-integration)
6. [Sicherheitshinweise](#6-sicherheitshinweise)

---

## 1. Konfigurationsanalyse

### 1.1 Relevante Konfigurationsdateien

CachyOS/Arch Linux verwendet mehrere Mirrorlist-Dateien zur Paketverwaltung:

| Datei | Beschreibung |
|-------|-------------|
| `/etc/pacman.d/mirrorlist` | Standard Arch Linux Mirror-Liste |
| `/etc/pacman.d/cachyos-mirrorlist` | CachyOS Haupt-Repository |
| `/etc/pacman.d/cachyos-v3-mirrorlist` | CachyOS x86-64-v3 optimierte Pakete |
| `/etc/pacman.d/cachyos-v4-mirrorlist` | CachyOS x86-64-v4 optimierte Pakete |

### 1.2 Rate-Mirrors Umgebungsvariablen

Das `rate-mirrors` Tool kann über Umgebungsvariablen konfiguriert werden:

```bash
# Protokoll (http/https)
export RATE_MIRRORS_PROTOCOL=https

# Timeout für Mirror-Fetch (in Millisekunden)
export RATE_MIRRORS_FETCH_MIRRORS_TIMEOUT=30000

# Als Root ausführen erlauben
export RATE_MIRRORS_ALLOW_ROOT=true

# Maximale Verzögerung für Mirrors (in Millisekunden)
export RATE_MIRRORS_MAX_DELAY=10000

# Startland für die Mirror-Suche
export RATE_MIRRORS_ENTRY_COUNTRY=DE
```

### 1.3 EU-Mitgliedstaaten (ISO 3166-1 alpha-2)

Die vollständige Liste der EU-Länder-Codes (Stand 2024):

```
AT  - Österreich
BE  - Belgien
BG  - Bulgarien
HR  - Kroatien
CY  - Zypern
CZ  - Tschechien
DK  - Dänemark
EE  - Estland
FI  - Finnland
FR  - Frankreich
DE  - Deutschland
GR  - Griechenland
HU  - Ungarn
IE  - Irland
IT  - Italien
LV  - Lettland
LT  - Litauen
LU  - Luxemburg
NL  - Niederlande
PL  - Polen
PT  - Portugal
RO  - Rumänien
SK  - Slowakei
SI  - Slowenien
ES  - Spanien
SE  - Schweden
```

---

## 2. Befehlsoptimierung

### 2.1 Rate-Mirrors Kommandozeilenoptionen

Das `rate-mirrors` Tool unterstützt folgende relevante Optionen:

| Option | Beschreibung |
|--------|-------------|
| `--save=FILE` | Ausgabe in Datei speichern |
| `--entry-country=CC` | Startland für Mirror-Suche (ISO-Code) |
| `--exclude-countries=CC,CC` | Länder ausschließen (kommagetrennt) |
| `--protocol=PROTO` | Nur bestimmtes Protokoll testen (http/https) |
| `--max-delay=N` | Maximale Verzögerung in Sekunden |
| `--concurrency=N` | Anzahl gleichzeitiger Speed-Tests |
| `--allow-root` | Als Root ausführen erlauben |
| `--max-mirrors-to-output=N` | Maximale Anzahl der Ausgabe-Mirrors |

### 2.2 Optimierter Befehl für EU-Only

Da `rate-mirrors` aktuell keinen direkten `--include-countries` Parameter hat, verwenden wir `--exclude-countries` um alle Nicht-EU-Länder auszuschließen:

```bash
# Wichtige Nicht-EU-Länder die häufig Mirrors haben
NON_EU_COUNTRIES="US,CN,RU,BY,JP,KR,AU,BR,CA,IN,SG,TW,HK,UA,CH,NO,GB,IS,RS,MD,AL,MK,ME,BA,XK,TR"

# Optimierter Befehl
rate-mirrors \
    --entry-country=DE \
    --exclude-countries="${NON_EU_COUNTRIES}" \
    --protocol=https \
    --max-delay=21600 \
    --concurrency=16 \
    --allow-root \
    arch

# Für CachyOS-Repositories
rate-mirrors \
    --entry-country=DE \
    --exclude-countries="${NON_EU_COUNTRIES}" \
    --protocol=https \
    --max-delay=10000 \
    --allow-root \
    cachyos
```

> **Hinweis:** Nach dem Brexit ist `GB` (Vereinigtes Königreich) kein EU-Mitglied mehr. Auch `CH` (Schweiz) und `NO` (Norwegen) gehören nicht zur EU.

---

## 3. Robustes Bash-Skript

### 3.1 Skript-Speicherort

Das Skript sollte unter `/usr/local/bin/` gespeichert werden:

```bash
sudo nano /usr/local/bin/cachyos-rate-mirrors-eu
```

### 3.2 Vollständiges Skript

Siehe: [`scripts/cachyos-rate-mirrors-eu.sh`](../scripts/cachyos-rate-mirrors-eu.sh)

### 3.3 Skript installieren

```bash
# Skript installieren
sudo cp scripts/cachyos-rate-mirrors-eu.sh /usr/local/bin/cachyos-rate-mirrors-eu
sudo chmod 755 /usr/local/bin/cachyos-rate-mirrors-eu

# Skript manuell ausführen
sudo /usr/local/bin/cachyos-rate-mirrors-eu
```

---

## 4. Systemd-Service für Autostart

### 4.1 Service-Datei erstellen

Erstellen Sie `/etc/systemd/system/cachyos-rate-mirrors-eu.service`:

```ini
[Unit]
Description=CachyOS EU Mirror Rating Service
Documentation=https://wiki.cachyos.org
After=network-online.target
Wants=network-online.target
ConditionPathExists=/usr/local/bin/cachyos-rate-mirrors-eu

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cachyos-rate-mirrors-eu
TimeoutStartSec=600
StandardOutput=journal
StandardError=journal

# Sicherheitseinstellungen
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
```

### 4.2 Timer-Datei erstellen (für periodische Ausführung)

Erstellen Sie `/etc/systemd/system/cachyos-rate-mirrors-eu.timer`:

```ini
[Unit]
Description=Weekly CachyOS EU Mirror Rating Timer
Documentation=https://wiki.cachyos.org

[Timer]
# Wöchentliche Ausführung am Sonntag um 03:00 Uhr
OnCalendar=weekly
OnCalendar=Sun *-*-* 03:00:00
# Auch bei verpasster Ausführung nachholen
Persistent=true
# Zufällige Verzögerung (max 1 Stunde) um Server-Last zu verteilen
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
```

### 4.3 Service aktivieren

```bash
# Systemd neu laden
sudo systemctl daemon-reload

# Service beim Boot aktivieren
sudo systemctl enable cachyos-rate-mirrors-eu.service

# Timer für periodische Ausführung aktivieren
sudo systemctl enable --now cachyos-rate-mirrors-eu.timer

# Status überprüfen
sudo systemctl status cachyos-rate-mirrors-eu.service
sudo systemctl list-timers cachyos-rate-mirrors-eu.timer
```

### 4.4 Einmaliger Start beim Systemstart

Falls die Mirror-Liste nur beim Start (ohne Timer) aktualisiert werden soll:

```bash
# Nur den Service aktivieren (ohne Timer)
sudo systemctl enable cachyos-rate-mirrors-eu.service
```

---

## 5. Energieverwaltung Integration

### 5.1 Systemd Sleep/Wake Hook

Erstellen Sie `/etc/systemd/system/cachyos-rate-mirrors-eu-resume.service`:

```ini
[Unit]
Description=Update CachyOS EU Mirrors after System Resume
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 30
ExecStart=/usr/local/bin/cachyos-rate-mirrors-eu
TimeoutStartSec=600

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
```

```bash
# Aktivieren
sudo systemctl daemon-reload
sudo systemctl enable cachyos-rate-mirrors-eu-resume.service
```

### 5.2 KDE Power Management Integration

Für KDE Plasma können Sie ein Skript bei Inaktivität ausführen:

**Methode 1: KDE PowerDevil Script**

1. Öffnen Sie **Systemeinstellungen → Energieverwaltung → Energieeinsparung**
2. Im Bereich "Erweiterte Einstellungen" einen Hook hinzufügen ist nicht direkt möglich

**Methode 2: Idle Detection mit systemd-logind**

Erstellen Sie `/etc/systemd/system/cachyos-rate-mirrors-eu-idle.service`:

```ini
[Unit]
Description=Update CachyOS EU Mirrors on System Idle
ConditionPathExists=/usr/local/bin/cachyos-rate-mirrors-eu

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cachyos-rate-mirrors-eu
```

Erstellen Sie `/etc/systemd/system/cachyos-rate-mirrors-eu-idle.timer`:

```ini
[Unit]
Description=Check idle and update mirrors
ConditionACPower=true

[Timer]
# Nur bei Inaktivität nach 30 Minuten
OnBootSec=30min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
```

### 5.3 Benutzer-Level Autostart (.desktop)

Für Benutzer ohne Root-Rechte (z.B. via polkit) erstellen Sie `~/.config/autostart/cachyos-rate-mirrors-eu.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=CachyOS EU Mirror Update
Comment=Update mirror lists to EU-only servers
Exec=pkexec /usr/local/bin/cachyos-rate-mirrors-eu
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
```

> **Hinweis:** Diese Methode erfordert eine polkit-Regel für passwortlose Ausführung (nicht empfohlen aus Sicherheitsgründen).

---

## 6. Sicherheitshinweise

### 6.1 Allgemeine Empfehlungen

1. **Root-Rechte minimieren:** Das Skript benötigt Root-Rechte nur für das Schreiben in `/etc/pacman.d/`. Führen Sie es daher nur als Service aus, nicht manuell als Root-Benutzer.

2. **Skript-Integrität:** Stellen Sie sicher, dass das Skript unter `/usr/local/bin/` nur von Root geschrieben werden kann:
   ```bash
   sudo chown root:root /usr/local/bin/cachyos-rate-mirrors-eu
   sudo chmod 755 /usr/local/bin/cachyos-rate-mirrors-eu
   ```

3. **Backup-Strategie:** Das Skript erstellt automatisch Backups der Mirrorlisten mit dem Suffix `-backup`. Überprüfen Sie regelmäßig, ob die Backups vorhanden sind.

4. **Log-Überwachung:** Überwachen Sie die Logs des Services:
   ```bash
   sudo journalctl -u cachyos-rate-mirrors-eu.service -f
   ```

### 6.2 Systemd-Sicherheitsoptionen

Die Service-Datei enthält bereits Sicherheitseinstellungen:

- `ProtectSystem=full`: Schreibschutz für `/usr` und `/boot`
- `PrivateTmp=true`: Isoliertes `/tmp` Verzeichnis
- `NoNewPrivileges=false`: Erforderlich für `rate-mirrors --allow-root`

### 6.3 Polkit-Regel für Benutzer-Ausführung (optional)

Falls Benutzer das Skript ohne Passwort ausführen sollen, erstellen Sie `/etc/polkit-1/rules.d/50-cachyos-rate-mirrors.rules`:

```javascript
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/local/bin/cachyos-rate-mirrors-eu" &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
```

> **Warnung:** Dies erlaubt Benutzern der Gruppe `wheel` die passwortlose Ausführung des Skripts. Verwenden Sie diese Option nur in vertrauenswürdigen Umgebungen.

---

## Referenzen

- [Arch Wiki - Mirrors](https://wiki.archlinux.org/title/Mirrors)
- [Arch Wiki - Systemd/Timers](https://wiki.archlinux.org/title/Systemd/Timers)
- [Arch Wiki - Autostarting](https://wiki.archlinux.org/title/Autostarting)
- [CachyOS Wiki - FAQ](https://wiki.cachyos.org/cachyos_basic/faq/)
- [rate-mirrors GitHub Repository](https://github.com/westandskif/rate-mirrors)
- [CachyOS-PKGBUILDS - cachyos-rate-mirrors](https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-rate-mirrors)
- [EU Country Codes - Eurostat](https://ec.europa.eu/eurostat/statistics-explained/index.php/Glossary:Country_codes)
