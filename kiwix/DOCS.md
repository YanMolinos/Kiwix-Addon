# Kiwix (Offline Wiki / Wiki Offline)

## English

Home Assistant OS add-on that serves `.zim` files through `kiwix-serve`.

How to use:

1. Configure `zim_dir` (default: `/share/kiwix`).
2. Choose `language`: `pt`, `en`, or `all`.
3. Copy `.zim` files to the language folders.
4. Start the add-on.
5. Open it from the Home Assistant sidebar (Ingress).

Optional test mode:

- You can bundle `.zim` files into the image by placing them in `kiwix/zims/` before build.

Options:

- `zim_dir` (string): directory containing `.zim` files.
- `language` (string): served language (`all`, `pt`, `en`).
- `username` (string, optional): basic auth username if supported by the `kiwix-serve` version.
- `password` (password, optional): basic auth password if supported by the `kiwix-serve` version.

Configuration example:

```yaml
zim_dir: /share/kiwix
language: all
username: ""
password: ""
```

Recommended language folder layout:

```text
/share/kiwix/
+-- pt/
|  `-- *.zim
`-- en/
   `-- *.zim
```

Behavior:

- `language: pt` loads only Portuguese folder files.
- `language: en` loads only English folder files.
- `language: all` loads `pt`, `en`, and root-level `.zim` files.

Notes:

- The add-on waits until at least one `.zim` file exists in the selected language paths.
- Bundled files in `/opt/kiwix/zims` are also considered.
- If `--username/--password` is unavailable in your `kiwix-serve` build, the add-on starts without auth.
- For large libraries, consider `/media/kiwix`.
- `init: false` is required because the upstream Kiwix image already uses s6 as PID 1.
- `ingress: true` exposes Kiwix inside Home Assistant sidebar.
- This add-on does not publish an external host port; access is via Home Assistant UI.

## Portugues (PT-BR)

Add-on para Home Assistant OS que publica arquivos `.zim` usando `kiwix-serve`.

Como usar:

1. Configure `zim_dir` (padrao: `/share/kiwix`).
2. Escolha `language`: `pt`, `en` ou `all`.
3. Copie arquivos `.zim` para as pastas de idioma.
4. Inicie o add-on.
5. Abra pela barra lateral do Home Assistant (Ingress).

Modo opcional para testes:

- Voce pode embutir `.zim` na imagem colocando arquivos em `kiwix/zims/` antes do build.

Opcoes:

- `zim_dir` (string): diretorio com arquivos `.zim`.
- `language` (string): idioma servido (`all`, `pt`, `en`).
- `username` (string, opcional): usuario para auth basica, se suportado pela versao do `kiwix-serve`.
- `password` (password, opcional): senha para auth basica, se suportado pela versao do `kiwix-serve`.

Exemplo de configuracao:

```yaml
zim_dir: /share/kiwix
language: all
username: ""
password: ""
```

Estrutura recomendada de pastas:

```text
/share/kiwix/
+-- pt/
|  `-- *.zim
`-- en/
   `-- *.zim
```

Comportamento:

- `language: pt` carrega apenas arquivos da pasta em portugues.
- `language: en` carrega apenas arquivos da pasta em ingles.
- `language: all` carrega `pt`, `en` e `.zim` na raiz.

Notas:

- O add-on aguarda ate existir pelo menos um arquivo `.zim` nos caminhos do idioma selecionado.
- Arquivos embutidos em `/opt/kiwix/zims` tambem sao considerados.
- Se `--username/--password` nao estiver disponivel na sua versao do `kiwix-serve`, o add-on inicia sem auth.
- Para bibliotecas grandes, considere usar `/media/kiwix`.
- `init: false` e necessario porque a imagem upstream do Kiwix ja usa s6 como PID 1.
- `ingress: true` publica o Kiwix dentro da barra lateral do Home Assistant.
- Este add-on nao publica porta externa; o acesso e pela interface do Home Assistant.
