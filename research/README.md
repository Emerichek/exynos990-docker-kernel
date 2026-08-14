# research — como se chegou ao `LLVM_IAS=1`

Registro dos testes que levaram à receita final. Cinco kernels foram gravados
no aparelho; os quatro primeiros não bootaram. Estes scripts são o caminho
percorrido, mantidos porque o método vale mais que o resultado: se alguém
enfrentar o mesmo silêncio no `Starting kernel...`, aqui está o que já foi
eliminado.

## O sintoma

O log do bootloader (`/proc/last_kmsg`, lido pelo recovery) terminava sempre
assim:

```
[0:    3.320820 ] UPLOAD_MODE 0, Set S2D LOW, DUMP_DIS
[0:    3.320929 ] Starting kernel...
```

Nada depois. Nem pânico, nem call trace, nem uma linha do kernel. O bootloader
carregou a imagem, saltou para ela, e o kernel morreu antes de inicializar o
console — o que impede qualquer registro em `pstore`.

## As hipóteses, na ordem em que foram testadas

| # | Hipótese | Como foi testada | Resultado |
|---|---|---|---|
| 1 | Opções não entraram na config | `06-verificar.sh`: extrai a config de dentro da `Image` compilada | entraram; 31/31 |
| 2 | LTO desabilitado | `diag-lto.sh`: leitura do `arch/Kconfig` | **confirmada** — `depends on LD_IS_LLD` |
| 3 | Config divergente do original | `10-diff-config.sh`: diff das configs embutidas | só as opções intencionais diferiam |
| 4 | Cabeçalho ARM64 malformado | `11-diff-header.sh` | `magic`, `text_offset`, `flags` idênticos |
| 5 | RKP / Knox rejeitando o kernel | `14-rkp.sh` | o LineageOS não compila RKP; descartada |
| 6 | Uma das opções mata o boot cedo | `13-build-minimal.sh` + gravação | não bootou; e o **controle** também não |
| 7 | `magiskboot repack` corrompe a imagem | `../flash/repack-test.sh` | repack é idempotente; descartada |
| 8 | Ferramentas de build divergentes | `15-paridade.sh` | ver abaixo |

## O teste que redirecionou tudo

`12-controle-lto.sh` compila com LTO e **zero opções nossas** — ou seja, deveria
produzir o kernel oficial. Resultado: **42.514.448 bytes, exatamente o tamanho
do kernel original**, e `10-diff-config.sh` confirmou config 100% idêntica.

Esse kernel também não bootou.

Isso eliminou configuração como causa de forma definitiva e apontou para a
geração do binário. O `16-cmp-binario.sh` quantificou: **70,72% dos bytes
diferentes**, distribuídos por toda a imagem, com tamanho idêntico.

## A solução

Veio de fora do LineageOS. O `build.sh` do projeto
[ExtremeXT/android_kernel_samsung_exynos990](https://github.com/ExtremeXT/android_kernel_samsung_exynos990)
— outro kernel para o mesmo SoC, cujas builds comprovadamente bootam — usa:

```bash
MAKE_ARGS="LLVM=1 LLVM_IAS=1 ARCH=arm64 READELF=$CLANG_DIR/bin/llvm-readelf O=out"
```

`LLVM_IAS=1`, o assembler integrado do clang, era o único eixo de geração de
código que ainda não havia sido variado. Todas as builds anteriores montaram o
kernel com o `as` do binutils 2.27.

A build com `LLVM_IAS=1` bootou de primeira.

## Observação sobre a documentação oficial

O `vendor/lineage/build/tasks/kernel.mk` do LineageOS define:

```make
KERNEL_CC := CC="$(CCACHE_BIN) clang" LD=ld.lld
```

Apenas `CC` e `LD`. Seguir isso literalmente, fora do sistema de build deles,
produz um kernel que não boota. Provavelmente o ambiente completo do Android
build system supre o restante por outros meios — mas para uma compilação
isolada, `LLVM=1 LLVM_IAS=1` é o que funciona.

## Índice dos scripts

| Script | O que faz |
|---|---|
| `04-config.sh` | monta a config e confere opção por opção |
| `05-build.sh` | primeira build (sem LTO — não boota) |
| `06-verificar.sh` | extrai a config de dentro da `Image` com `extract-ikconfig` |
| `07-controle.sh` | controle sem LTO (inútil, mantido por completude) |
| `08-build-lto.sh` | build com LTO via `ld.lld` — ainda não boota |
| `09-verificar-lto.sh` | verifica os 31 requisitos na imagem com LTO |
| `10-diff-config.sh` | extrai o kernel da `boot.img` e compara as configs |
| `11-diff-header.sh` | compara o cabeçalho ARM64 e o DTB |
| `12-controle-lto.sh` | **controle decisivo**: LTO, zero opções |
| `13-build-minimal.sh` | só as opções essenciais do Docker |
| `14-rkp.sh` | procura RKP/Knox/TIMA no kernel |
| `15-paridade.sh` | tenta reproduzir o kernel oficial bit a bit |
| `16-cmp-binario.sh` | quantifica a diferença binária |
| `diag-config.sh` | por que `OVERLAY_FS` e `VETH` sumiram |
| `diag-lto.sh` | por que o LTO foi desabilitado |

Os scripts esperam a árvore em `~/kernel/` (`src/`, `clang/`, `gcc/`, `cmp/`),
montada por `build/02-fontes.sh` e `build/03-gcc.sh`.
