# jbl-ubuntu-hotplug

**Ubuntu 24.04+** · **PipeWire + WirePlumber** · **wpctl**
Ajuda o Ubuntu a **redetectar** e **selecionar automaticamente** o headset **JBL Quantum 910 Wireless** (saída + microfone) quando você **despluga/religa** o dongle — **sem precisar rodar `usbreset` toda hora**.

---

## Por que existe?

Em alguns sistemas, ao religar ou replugá-lo, o dongle do **JBL Quantum 910 Wireless** aparece no `lsusb`, mas os **nós de áudio** (sink/source) **não reaparecem** no PipeWire/WirePlumber até reiniciar os serviços de áudio.
Este projeto automatiza:

1. Detectar a mudança de áudio (hotplug)
2. **Reiniciar** *somente se necessário* `wireplumber`, `pipewire` e `pipewire-pulse` (modo usuário)
3. Esperar o JBL surgir nos **Sinks/Sources**
4. Definir o JBL como **dispositivo padrão** de **saída** *e* **entrada**

---

## Requisitos

* Ubuntu **24.04+** (PipeWire + WirePlumber já vêm por padrão no desktop)
* `wpctl` (parte do PipeWire)
* `systemd` em modo usuário (padrão no Ubuntu)

---

## Instalação (modo usuário)

1. Copie os arquivos do repositório para as pastas sugeridas:

   mkdir -p \~/.local/bin \~/.config/systemd/user
   cp bin/jbl-hotplug-recover.sh \~/.local/bin/
   chmod +x \~/.local/bin/jbl-hotplug-recover.sh
   cp systemd/user/jbl-hotplug.service \~/.config/systemd/user/
   cp systemd/user/jbl-hotplug.path    \~/.config/systemd/user/

2. Recarregue e habilite o gatilho:

   systemctl --user daemon-reload
   systemctl --user enable --now jbl-hotplug.path

   # (opcional) rode uma vez manualmente agora:

   systemctl --user start jbl-hotplug.service

Pronto. A cada plug/unplug o serviço será disparado automaticamente.

---

## Como funciona

* O `.path` observa mudanças em **/proc/asound/cards** (ALSA)
* O `.service` executa `bin/jbl-hotplug-recover.sh`, que:

  * tenta encontrar os nós do JBL diretamente (sem reiniciar nada)
  * se ainda não aparecerem, **debounce** curto e tenta de novo
  * se continuar ausente, **reinicia** WirePlumber/PipeWire do **usuário**
  * espera até 10s o surgimento dos nós e então define:

    * **Sink** padrão (saída)
    * **Source** padrão (microfone)

> Observação: reiniciar a stack de áudio **derruba streams ativos** (ex.: chamada). O script só faz isso quando o JBL **não** reapareceu sozinho.

---

## Configuração (opcional)

Você pode ajustar alguns parâmetros via variáveis de ambiente no `.service`:

* `MATCH_NAME` (padrão: `JBL Quantum`) — expressão que identifica seu headset nas listas do `wpctl status`
* `EXCLUDE_SINK` (padrão: `Chat`) — evita selecionar um sink “Chat” se existir
* `DEBOUNCE_SEC` (padrão: `1`) — espera breve antes de reiniciar a stack
* `APPEAR_TIMEOUT` (padrão: `10`) — tempo máximo para os nós surgirem após reinício

Para configurar, crie um drop-in:

```
systemctl --user edit jbl-hotplug.service
```

Exemplo de conteúdo:

```
[Service]
Environment=MATCH_NAME=JBL Quantum
Environment=EXCLUDE_SINK=Chat
Environment=DEBOUNCE_SEC=1
Environment=APPEAR_TIMEOUT=10
```

Depois:

```
systemctl --user daemon-reload
systemctl --user restart jbl-hotplug.service
```

---

## Uso manual (se precisar)

Forçar uma tentativa agora:

```
systemctl --user start jbl-hotplug.service
```

Verificar a seleção de áudio:

```
wpctl status | awk '/^Audio/{a=1;next}/^Video/{a=0} a' | sed -n '/Sinks:/,/Source endpoints:/p'
```

---

## Logs e diagnóstico

Logs do serviço:

```
journalctl --user -u jbl-hotplug.service -n 50 --no-pager
```

Log do script:

```
tail -n 100 ~/.cache/jbl-hotplug.log
```

Checar se o dongle enumerou no USB:

```
lsusb | grep -i '0ecb:2088' || echo 'USB não enumerado'
```

Se o dongle apareceu no `lsusb` mas **não** há nós de áudio:

```
systemctl --user restart wireplumber pipewire pipewire-pulse
sleep 2
wpctl status | awk '/^Audio/{a=1;next}/^Video/{a=0} a' | sed -n '/Sinks:/,/Source endpoints:/p'
```

---

## Estrutura do repositório

```
jbl-ubuntu-hotplug/
├─ bin/
│  └─ jbl-hotplug-recover.sh
├─ systemd/user/
│  ├─ jbl-hotplug.service
│  └─ jbl-hotplug.path
├─ LICENSE
└─ README.md
```

---

## Segurança

* Tudo roda no **usuário** (sem `sudo`, sem `udev` root, sem `usbreset`)
* O script usa *locking* e reinicia a stack **apenas quando necessário**

---

## Limitações conhecidas

* Se o driver ALSA realmente não anexar ao dongle após o hotplug, nem o reinício do PipeWire/WirePlumber vai ajudar; nesse caso é algo **abaixo** da camada do usuário (driver/kernel).
* Em chamadas ativas, reiniciar o áudio interrompe as streams (o script evita quando possível).

---

## Licença

MIT — veja o arquivo `LICENSE`.

---

## Créditos

Criado para resolver a **auto-detecção** do **JBL Quantum 910 Wireless** no Ubuntu, evitando a necessidade de rodar `usbreset` toda vez que o headset é desligado/reconectado.
