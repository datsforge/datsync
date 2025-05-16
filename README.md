# datsync

**datsync** is a lightweight Bash tool for syncing data between your local machine and external devices — specifically Android devices (via ADB) and USB drives — with optional mirroring and persistent configuration.

> 🔧 Because backups should be simple, fast, and smarter than your average sync script.

---

## ✨ Features

- Push/pull files between **local ↔ Android/USB**
- Supports both Android **internal** (`/sdcard/`) and **external** (`/storage/`) storage
- **Mirror mode**: deletes files not present in the source (careful now)
- Supports **short options**: `-an` (android-internal), `-ax` (android-external)
- **Persistent config** – remembers your paths and preferences
- Designed for **Linux**

---

## 📦 Installation

Just drop it somewhere in your `PATH`:

```bash
chmod +x datsync.sh
sudo mv datsync.sh /usr/local/bin/datsync
```

Then run it like:

```bash
datsync --help
```

---

## 🧪 Example Usage

Push to Android internal:
```bash
datsync push -android internal
```

Pull from Android external:
```bash
datsync pull -android external
# or the short way:
datsync pull -ax
```

Mirror push to USB (deletes files on USB not in local):
```bash
datsync push-m -usb
```

Mirror pull from Android internal:
```bash
datsync pull-m -an
```

Prompt for storage if not specified:
```bash
datsync push -android
```

Override local path for this operation only:
```bash
datsync push -usb -l /home/user/projects/backups
```

---

## 🛠 Command Overview

```bash
datsync <mode> <-target> [storage] [options]
```

### Modes

| Command   | Description |
|-----------|-------------|
| `push`    | Push files from local to device |
| `pull`    | Pull files from device to local |
| `push-m`  | Push with mirroring (removes target files not in local) |
| `pull-m`  | Pull with mirroring (removes local files not in target) |

### Targets

- `android` – requires ADB
- `usb` – any mounted USB device path

### Android Storage Options

- `-android internal` or `-an` – for `/sdcard/`
- `-android external` or `-ax` – for `/storage/XXXX-XXXX/`
- `-android all` or `-aa` – do both

---

## ⚙️ Options

| Flag              | Description |
|-------------------|-------------|
| `-l <path>`       | Override local path for this operation |
| `-c`, `--config`  | Set or update default paths |
| `-h`, `--help`    | Show the help message |

---

## 🧠 Tips

- **Mirror mode** (`push-m`, `pull-m`) removes files. Don’t be reckless.
- When syncing to Android and no storage is specified, you'll be asked.
- Default paths are remembered once set using the config.

---

## 🔚 Final Words

Backups shouldn't be annoying, and scripts shouldn't require a PhD in `rsync`.  
**datsync** is your minimalist, no-BS companion for daily backups — fast, predictable, and just smart enough not to get in your way.

Now go sync like a legend.
