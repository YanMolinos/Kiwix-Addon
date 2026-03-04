# Kiwix (Offline Wiki / Wiki Offline)

## English

Home Assistant OS add-on that serves `.zim` files through `kiwix-serve`.

How to use:

1. Configure `zim_dir` (default: `/share/kiwix`).
2. Put all your `.zim` files in that same folder.
4. Start the add-on.
5. Open it from the Home Assistant sidebar (Ingress).

Optional test mode:

- You can bundle `.zim` files into the image by placing them in `kiwix/zims/` before build.

Options:

- `zim_dir` (string): directory containing `.zim` files.
- `username` (string, optional): basic auth username if supported by the `kiwix-serve` version.
- `password` (password, optional): basic auth password if supported by the `kiwix-serve` version.

Configuration example:

```yaml
zim_dir: /share/kiwix
username: ""
password: ""
```

Recommended folder layout:

```text
/share/kiwix/
+-- wikipedia_en_all_maxi_2026-01.zim
+-- wikipedia_pt_all_maxi_2026-01.zim
`-- ifixit_en_all_2025-12.zim
```

Notes:

- Docker base image is pinned to `ghcr.io/kiwix/kiwix-serve:3.8.2`.
- The add-on waits until at least one `.zim` file exists in `zim_dir`.
- Bundled files in `/opt/kiwix/zims` are also considered.
- The add-on auto-generates a `library.xml` with `kiwix-manage` so the main page can list all ZIM entries reliably.
- If `--username/--password` is unavailable in your `kiwix-serve` build, the add-on starts without auth.
- For large libraries, consider `/media/kiwix`.
- `init: false` is required because the upstream Kiwix image already uses s6 as PID 1.
- `ingress: true` exposes Kiwix inside Home Assistant sidebar.
- This add-on does not publish an external host port; access is via Home Assistant UI.

## Portugues (PT-BR)

Add-on para Home Assistant OS que publica arquivos `.zim` usando `kiwix-serve`.

Como usar:

1. Configure `zim_dir` (padrao: `/share/kiwix`).
2. Coloque todos os arquivos `.zim` nessa mesma pasta.
4. Inicie o add-on.
5. Abra pela barra lateral do Home Assistant (Ingress).

Modo opcional para testes:

- Voce pode embutir `.zim` na imagem colocando arquivos em `kiwix/zims/` antes do build.

Opcoes:

- `zim_dir` (string): diretorio com arquivos `.zim`.
- `username` (string, opcional): usuario para auth basica, se suportado pela versao do `kiwix-serve`.
- `password` (password, opcional): senha para auth basica, se suportado pela versao do `kiwix-serve`.

Exemplo de configuracao:

```yaml
zim_dir: /share/kiwix
username: ""
password: ""
```

Estrutura recomendada:

```text
/share/kiwix/
+-- wikipedia_en_all_maxi_2026-01.zim
+-- wikipedia_pt_all_maxi_2026-01.zim
`-- ifixit_en_all_2025-12.zim
```

Notas:

- A imagem base do Docker esta fixada em `ghcr.io/kiwix/kiwix-serve:3.8.2`.
- O add-on aguarda ate existir pelo menos um arquivo `.zim` em `zim_dir`.
- Arquivos embutidos em `/opt/kiwix/zims` tambem sao considerados.
- O add-on gera automaticamente `library.xml` com `kiwix-manage` para a pagina principal listar todos os ZIMs de forma consistente.
- Se `--username/--password` nao estiver disponivel na sua versao do `kiwix-serve`, o add-on inicia sem auth.
- Para bibliotecas grandes, considere usar `/media/kiwix`.
- `init: false` e necessario porque a imagem upstream do Kiwix ja usa s6 como PID 1.
- `ingress: true` publica o Kiwix dentro da barra lateral do Home Assistant.
- Este add-on nao publica porta externa; o acesso e pela interface do Home Assistant.
