# Kiwix Add-on for Home Assistant OS

This repository contains a Home Assistant OS add-on that serves `.zim` files with `kiwix-serve`.

## Repository Structure

```text
.
+-- repository.yaml
`-- kiwix/
   +-- config.yaml
   +-- Dockerfile
   +-- run.sh
   +-- DOCS.md
   +-- icon.png
   +-- logo.png
   `-- zims/
      +-- pt/
      `-- en/
```

Included add-on:

- `kiwix`: web server for offline ZIM libraries (Wikipedia, Wiktionary, etc.).

## Install

1. Push this repository to GitHub.
2. In Home Assistant, open `Settings -> Add-ons -> Add-on Store -> Repositories`.
3. Add your repository URL.
4. Install **Kiwix (Offline Wiki / Wiki Offline)**.
5. Start the add-on and open Kiwix from the Home Assistant sidebar.

## Where to place ZIM files

- Recommended base path: `/share/kiwix`
- Portuguese: `/share/kiwix/pt`
- English: `/share/kiwix/en`

Set `language` in add-on options:

- `pt`: loads only Portuguese files.
- `en`: loads only English files.
- `all`: loads both languages and also root-level `.zim` files.

Optional for tests:

- Put `.zim` files in `kiwix/zims/` before build to bundle content into the image.

## Notes

- Uses a pinned image version: `ghcr.io/kiwix/kiwix-serve:3.8.2`.
- Embedding large ZIM files in the Docker image is not recommended (slow build, large storage usage).
- Ingress is enabled, so Kiwix appears in the Home Assistant side panel.
- External host port publishing is disabled; use Home Assistant UI (sidebar/Ingress).
