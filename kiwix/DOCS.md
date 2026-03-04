# Kiwix (Offline Wiki / Wiki Offline)

## English

Home Assistant OS add-on that serves `.zim` files through `kiwix-serve`.

How to use:

1. Configure `zim_dir` (default: `/share/kiwix`).
2. Choose `language`: `pt`, `en`, or `all`.
3. Copy `.zim` files to the language folders.
4. Start the add-on.
5. Open `http://IP_OF_HOME_ASSISTANT:8080`.

Optional test mode:

- You can bundle `.zim` files into the image by placing them in `kiwix/zims/` before build.

Options:

- `zim_dir` (string): directory containing `.zim` files.
- `language` (string): served language (`all`, `pt`, `en`).
- `port` (port): Kiwix HTTP port.
- `username` (string, optional): basic auth username if supported by the `kiwix-serve` version.
- `password` (password, optional): basic auth password if supported by the `kiwix-serve` version.

Configuration example:

```yaml
zim_dir: /share/kiwix
language: all
port: 8080
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

## Portugues (PT-BR)

Add-on para Home Assistant OS que publica arquivos `.zim` usando `kiwix-serve`.

Como usar:

1. Configure `zim_dir` (padrao: `/share/kiwix`).
2. Escolha `language`: `pt`, `en` ou `all`.
3. Copie arquivos `.zim` para as pastas de idioma.
4. Inicie o add-on.
5. Acesse `http://IP_DO_HOME_ASSISTANT:8080`.

Modo opcional para testes:

- Voce pode embutir `.zim` na imagem colocando arquivos em `kiwix/zims/` antes do build.

Opcoes:

- `zim_dir` (string): diretorio com arquivos `.zim`.
- `language` (string): idioma servido (`all`, `pt`, `en`).
- `port` (porta): porta HTTP do Kiwix.
- `username` (string, opcional): usuario para auth basica, se suportado pela versao do `kiwix-serve`.
- `password` (password, opcional): senha para auth basica, se suportado pela versao do `kiwix-serve`.

Exemplo de configuracao:

```yaml
zim_dir: /share/kiwix
language: all
port: 8080
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
