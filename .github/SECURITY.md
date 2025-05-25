# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in `datsync`, please responsibly disclose it by opening a GitHub issue or emailing **security@datsforge.com**

Please include:
- A clear description of the issue
- Steps to reproduce (if applicable)
- Any relevant files or proof of concept
- Your GitHub username (optional, if you want recognition)

We take security seriously and will respond as quickly as possible to valid reports. Responsible disclosures may be credited in future changelogs (with your consent).

---

## Scope

This script interacts with local file systems and connected devices. Users are responsible for verifying target paths and connected devices before running commands.

---

## Responsible Usage

- Avoid syncing to/from directories with sensitive system files.
- Do **not** run this script as `root` unless absolutely necessary.
- Always verify devices before trusting them for syncing.

---

## Recommendations

- Make regular backups of important data.
- Audit the script before running if downloaded from a third party.
- Keep your shell environment and permissions secure.

---

## Disclaimer

This script is provided as-is without any guarantees. The author is not responsible for data loss, device damage, or other unintended consequences.
