# jbl-ubuntu-hotplug
Recupera PipeWire/WirePlumber no hotplug e define o headset JBL (saída + microfone) como padrão no Ubuntu 24.04+.

## Instalação
```bash
mkdir -p ~/.local/bin ~/.config/systemd/user
cp bin/jbl-hotplug-recover.sh ~/.local/bin/
chmod +x ~/.local/bin/jbl-hotplug-recover.sh
cp systemd/user/jbl-hotplug.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now jbl-hotplug.path

```

Logs

    journalctl --user -u jbl-hotplug.service -n 50 --no-pager
    ~/.cache/jbl-hotplug.log

Configuração (opcional)

Use variáveis no .service:
    MATCH_NAME (default: JBL Quantum)
    EXCLUDE_SINK (default: Chat)
    DEBOUNCE_SEC (default: 1)
    APPEAR_TIMEOUT (default: 10)

Licença: MIT.
