# Add-on Kiwix para Home Assistant OS

Este repositorio contem um add-on para Home Assistant OS que publica arquivos `.zim` usando `kiwix-serve`.

## Estrutura do Repositorio

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
```

Add-on incluido:

- `kiwix`: servidor web para bibliotecas ZIM offline (Wikipedia, Wiktionary etc.).

## Instalacao

1. Faca push deste repositorio para o GitHub.
2. No Home Assistant, abra `Settings -> Add-ons -> Add-on Store -> Repositories`.
3. Adicione a URL do seu repositorio.
4. Instale **Kiwix (Offline Wiki / Wiki Offline)**.
5. Inicie o add-on e abra o Kiwix pela barra lateral do Home Assistant.

## Onde colocar os arquivos ZIM

- Caminho base recomendado: `/share/kiwix`
- Coloque todos os arquivos `.zim` nessa mesma pasta.
- Nao separe por pasta de idioma.

Opcional para testes:

- Coloque arquivos `.zim` em `kiwix/zims/` antes do build para embutir conteudo na imagem.

## Observacoes

- Usa versao fixada da imagem: `ghcr.io/kiwix/kiwix-serve:3.8.2`.
- O add-on gera `library.xml` com `kiwix-manage`, para a pagina inicial listar todos os ZIMs como catalogo.
- Embutir ZIM grande na imagem Docker nao e recomendado (build lento e muito uso de armazenamento).
- Ingress esta habilitado, entao o Kiwix aparece na barra lateral do Home Assistant.
- Publicacao de porta externa esta desabilitada; use a interface do Home Assistant (barra lateral/Ingress).
