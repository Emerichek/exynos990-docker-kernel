# exynos990-docker-kernel

Kernel do LineageOS para Samsung Galaxy S20 / S20+ / S20 Ultra e Note 20
(Exynos 990) recompilado com as opções necessárias para rodar **Docker**.

O kernel que o LineageOS distribui vem com namespaces de IPC, filas POSIX,
cgroup de devices e a ponte de rede **desativados**, o que impede o `dockerd` de
subir. Este repositório contém a receita completa para recompilar habilitando
essas opções, além do ferramental para gravar e verificar o resultado.

**Status: validado em aparelho real.** SM-G985F (`y2s`), LineageOS 23.2,
Android 16, kernel 4.19.325.

---

## Índice

- [O problema](#o-problema)
- [O detalhe que faz funcionar](#o-detalhe-que-faz-funcionar)
- [Requisitos](#requisitos)
- [Passo a passo](#passo-a-passo)
- [Gravar no aparelho](#gravar-no-aparelho)
- [Recuperação](#recuperação)
- [Armadilhas do Kconfig](#armadilhas-do-kconfig)
- [Limitações conhecidas](#limitações-conhecidas)
- [Custo recorrente](#custo-recorrente)
- [Estrutura do repositório](#estrutura-do-repositório)

---

## O problema

Auditando o kernel de fábrica do LineageOS contra os requisitos do Docker,
faltam **três itens obrigatórios** e **três de rede**:

| Opção | Sem ela |
|---|---|
| `CONFIG_IPC_NS` | o `runc` não cria o namespace de IPC de cada container |
| `CONFIG_POSIX_MQUEUE` | o `runc` monta `/dev/mqueue` em todo container; falha |
| `CONFIG_CGROUP_DEVICE` | sem controle de acesso a devices |
| `CONFIG_BRIDGE` | sem `docker0` |
| `CONFIG_BRIDGE_NETFILTER` | sem firewall na ponte |
| `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE` | sem as regras de porta do Docker |

Não há flag de linha de comando que contorne a ausência de `IPC_NS` ou
`POSIX_MQUEUE`: é recompilação ou nada.

Já vêm habilitadas de fábrica, felizmente: `OVERLAY_FS`, `VETH`, `NF_NAT`,
`SECCOMP`, `MEMCG`, `CGROUP_BPF`, `BLK_CGROUP`, `CFS_BANDWIDTH`,
`NF_CONNTRACK`. O script `flash/docker-check.sh` audita seu aparelho e diz
exatamente o que falta.

---

## O detalhe que faz funcionar

A invocação do `make` precisa ser:

```bash
make O=out LLVM=1 LLVM_IAS=1 ARCH=arm64 READELF=$CLANG/bin/llvm-readelf -j$(nproc)
```

`LLVM=1` ativa toda a suíte LLVM. **`LLVM_IAS=1` usa o assembler integrado do
clang no lugar do GNU `as`** — e é esse o ponto decisivo.

Kernels compilados com o `as` do binutils (o que a documentação do LineageOS
sugere, com apenas `CC=clang LD=ld.lld`) **carregam mas não executam** neste
bootloader. O log do bootloader mostra `Starting kernel...` e nada depois:
nenhuma mensagem, nenhum pânico, nenhum registro em `pstore`. O kernel morre
antes de inicializar o console.

Quatro builds foram descartadas até isolar isso. O histórico completo da
investigação, com todos os testes intermediários, está em
[`research/`](research/).

---

## Requisitos

- **Aparelho Exynos 990** com bootloader destravado e Magisk instalado
- **Ambiente Linux** com ~40 GB livres (WSL2 no Windows serve)
- **adb** (platform-tools) no computador
- 12 GB de RAM recomendados para a build com LTO

Codinomes suportados pela árvore: `x1s`, `x1slte` (S20), `y2s`, `y2slte`
(S20+), `z3s` (S20 Ultra), `c1s`, `c1slte` (Note 20), `c2s`, `c2slte`
(Note 20 Ultra), `r8s` (S20 FE).

---

## Passo a passo

### 0. Descubra o codinome do seu aparelho

```bash
adb shell getprop ro.product.device
```

Se não for `y2s`, edite `build/04-build.sh` e troque `y2s.config` pelo
fragmento correspondente.

### 1. Confirme que seu kernel realmente precisa disso

```bash
adb push flash/docker-check.sh /data/local/tmp/
adb shell su -c 'sh /data/local/tmp/docker-check.sh'
```

O script lê `/proc/config.gz` e lista, opção por opção, o que falta. Se o
veredito já for verde, você não precisa deste repositório.

### 2. Dependências de build

```bash
sudo bash build/01-deps.sh
```

Instala `clang`, `bison`, `flex`, `libssl-dev`, `device-tree-compiler` e o
restante do necessário. Detecta se já está como root e dispensa o `sudo`.

### 3. Clonar fontes e toolchain

```bash
bash build/02-fontes.sh
```

Baixa ~3,2 GB para `~/kernel/`:

- `LineageOS/android_kernel_samsung_universal9830`, branch `lineage-23.2`
- `clang-r416183b`, o toolchain que o `BoardConfigCommon.mk` do device tree
  declara

E instala `config/docker-kernel.config` em `arch/arm64/configs/`.

> **Confira a branch.** Se sua ROM não for LineageOS 23.2, ajuste `-b` no
> script. Kernel de branch errada não boota.

### 4. Binutils cruzado

```bash
bash build/03-gcc.sh
```

O clang não traz `as`/`ld`/`objcopy`. Este script clona o prebuilt
`aarch64-linux-android-4.9` do AOSP (~91 MB).

### 5. Compilar

```bash
bash build/04-build.sh
```

Antes de compilar, o script valida três coisas e **aborta** se alguma falhar:

1. `CONFIG_LTO_CLANG=y` sobreviveu ao `olddefconfig`
2. as opções do Docker entraram no `.config` final
3. a `Image` gerada tem tamanho compatível com o kernel original

Leva de 6 a 10 minutos. Resultado em `out/Image-ias`.

---

## Gravar no aparelho

### Como funciona

Não se grava a `Image` diretamente: ela precisa ser inserida dentro de uma
`boot.img`, que também contém o ramdisk e o device tree. O
`flash/kernel-swap.sh` faz isso usando o `magiskboot` que já está no aparelho.

Ele parte de um **backup da sua boot atual**, que já está patchada com o
Magisk. Como o patch do Magisk vive no ramdisk, e a troca substitui só o
kernel, **o root sobrevive** — não é preciso repassar pelo app do Magisk.

### Sequência

```bash
# 1. envia o kernel novo
adb push out/Image-ias /data/local/tmp/Image

# 2. envia as ferramentas
adb push flash/kernel-swap.sh flash/verify-patched.sh /sdcard/Download/
adb shell su -c 'cp /sdcard/Download/*.sh /data/local/tmp/ && chmod 755 /data/local/tmp/*.sh'

# 3. monta a boot.img nova (NAO grava nada ainda)
adb shell su -c 'sh /data/local/tmp/kernel-swap.sh'
```

O `kernel-swap.sh` faz backup da boot atual em **dois lugares**
(`/data/local/tmp/` e `/sdcard/Download/`), mostra o md5 do kernel antigo e do
novo, e gera `boot-novo.img`. Se o backup já existir, ele **não sobrescreve** —
assim uma segunda execução não substitui o original por um já modificado.

```bash
# 4. PUXE O BACKUP PARA O COMPUTADOR - passo que salva a pele
adb pull /sdcard/Download/boot-original.img .

# 5. grava
adb shell su -c 'dd if=/data/local/tmp/boot-novo.img of=/dev/block/by-name/boot bs=4096'
adb shell su -c sync
adb reboot
```

> **O passo 4 não é opcional.** Se o aparelho não bootar, `/data` fica
> inacessível — o recovery não consegue montar uma partição f2fs com checkpoint
> sujo. Um backup que só existe dentro do aparelho não serve para nada nesse
> momento.

### Verificação opcional

Se preferir passar pelo app do Magisk (Instalar → Selecionar e corrigir um
arquivo → `boot-novo.img`), o `flash/verify-patched.sh` confere, antes de
gravar, se o kernel dentro da imagem é o que você compilou e se o Magisk foi
mesmo aplicado.

---

## Recuperação

Um kernel que não boota **não danifica nada**. A partição `/data` nunca é
tocada: seus dados, aplicativos e arquivos continuam intactos. Só a partição de
boot, de 59 MB, precisa ser regravada.

### Entrar no recovery

1. **Power + Volume Baixo** por ~10 s, até a tela apagar
2. Com o **cabo USB conectado**, **Volume Alto + Power** até o recovery abrir
3. No recovery: **Advanced → Enable ADB**

### Restaurar

```bash
adb push boot-original.img /tmp/boot.img
adb shell dd if=/tmp/boot.img of=/dev/block/by-name/boot bs=4096
adb reboot
```

### Se você perdeu o backup

O LineageOS publica a `boot.img` avulsa de cada build — 59 MB, não é preciso
baixar a ROM inteira:

```bash
curl -s https://download.lineageos.org/api/v2/devices/y2s/builds | grep -o 'https://[^"]*boot\.img'
```

Confira o sha256 contra o que a API informa antes de gravar. Essa imagem é
limpa, sem Magisk: você recupera o aparelho, mas precisa refazer o root.

### Diagnóstico da falha

Depois de um boot fracassado, o log do bootloader fica em `/proc/last_kmsg`,
acessível pelo recovery:

```bash
adb pull /proc/last_kmsg
```

Procure o fim do arquivo. Se terminar em `Starting kernel...` sem nenhuma linha
do kernel, a imagem não executou — provável problema de build, não de
configuração.

---

## Armadilhas do Kconfig

Três comportamentos silenciosos custaram tempo nesta investigação. Todos os
scripts deste repositório verificam o `.config` **final**, nunca o que foi
pedido.

### 1. `# CONFIG_X=y` em comentário desliga a opção

O `merge_config.sh` trata `# CONFIG_X is not set` como uma **definição** — é a
forma que o Kconfig usa para "desativado". Uma linha de documentação assim:

```
# CONFIG_OVERLAY_FS=y   ja vem habilitada no defconfig
```

é interpretada como ordem de desligar `OVERLAY_FS`, e remove silenciosamente o
`=y` que vinha do defconfig base.

**Regra:** em fragmentos de configuração, nunca escreva `CONFIG_` logo após o
`#`. Coloque outra palavra antes.

### 2. LTO depende do linker

```
config LTO_CLANG
	depends on ARCH_SUPPORTS_LTO_CLANG
	depends on CC_IS_CLANG && LD_IS_LLD
```

Compilando com GNU `ld`, a dependência `LD_IS_LLD` não é satisfeita, o Kconfig
resolve a escolha para `LTO_NONE` **sem emitir aviso**, e o kernel sai 3,4 MB
maior. `LLVM=1` resolve.

### 3. `olddefconfig` desfaz o que não pode atender

Qualquer opção cuja dependência não esteja satisfeita é revertida em silêncio.
O `build/04-build.sh` confere uma a uma depois do `olddefconfig` e aborta se
alguma não entrou — descobrir isso depois de compilar e gravar custa muito mais
caro.

---

## Limitações conhecidas

### Sem `-p porta:porta`

O `dockerd` precisa rodar com `iptables: false`. O motivo:

O chroot compartilha o namespace de rede do Android, cujas tabelas contêm
regras com o match `quota2` (contabilidade de dados móveis da Samsung). O
`iptables` do Debian consegue **ler** essas regras depois de instalar
`xtables-addons-common`, mas ao **gravar** precisa re-serializar a tabela
inteira — e o layout do `quota2` do xtables-addons difere do `xt_quota2` da
Samsung. O kernel rejeita a escrita com `No chain/target/match by that name`.

Consequência: use `--network=host`. O container abre a porta direto no
aparelho, o que para um servidor caseiro costuma bastar — só não repita portas
entre containers.

A solução definitiva seria dar ao chroot um namespace de rede próprio, com par
veth e NAT feito pelo `iptables` do **Android** (que entende `quota2`).

### `USER_NS` fica desligado de propósito

O namespace de usuário é vetor conhecido de escalada de privilégio e vem
desabilitado nos kernels Android por decisão de segurança. O Docker comum não
precisa dele — só o modo rootless. Se quiser, descomente em
`config/docker-kernel.config`.

### Sem `--cpus` e `--cpuset-cpus`

O `dockerd` avisa `No cpu shares support` e `No cpuset support`: a delegação de
cgroup dentro do chroot é parcial. Limite de memória (`--memory`) funciona.

---

## Custo recorrente

Toda atualização do LineageOS regrava a partição de boot, apagando o kernel
customizado **e** o Magisk. Em builds nightly, isso é semanal.

Refazer leva ~10 minutos:

```bash
bash build/04-build.sh          # ~7 min, a árvore já está clonada
# kernel-swap + dd + reboot     # ~3 min
```

Mas exige você presente. Se o ritmo incomodar, considere um canal de
atualização menos frequente.

---

## Estrutura do repositório

```
build/       receita de compilação, na ordem de execução
  01-deps.sh       dependências do sistema
  02-fontes.sh     clona kernel + clang, instala o fragmento
  03-gcc.sh        binutils cruzado do AOSP
  04-build.sh      compila (LLVM=1 LLVM_IAS=1) com validação

config/      fragmentos de configuração do kernel
  docker-kernel.config    completo (rede + cgroups opcionais)
  docker-minimal.config   só o essencial, sem os cgroups opcionais

flash/       ferramentas para o aparelho
  docker-check.sh     audita o kernel em uso contra os requisitos
  kernel-swap.sh      troca o kernel dentro da boot.img
  verify-patched.sh   confere a imagem antes de gravar
  flash-kernel.sh     grava com leitura de volta
  repack-test.sh      verifica idempotência do magiskboot

research/    registro da investigação: 15 scripts de teste
```

---

## Licença

MIT. Veja [LICENSE](LICENSE).

Os fragmentos de configuração são derivados do defconfig do kernel do
LineageOS, que é GPLv2 — como qualquer código do kernel Linux.
