-- Extra autostart processes.
-- o.launch_on_start("my-service")


-- Fond animé Zenitsu (couches IA + pluie + éclair) : ~/.config/quickshell/zenitsu
o.launch_on_start("env QT_LOGGING_RULES=quickshell.io.socket.warning=false qs -c zenitsu")
