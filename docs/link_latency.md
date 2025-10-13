# Latence entre le clic du LinkClock et Ableton Live

Lorsque le LinkClock de SuperCollider pilote un clic audio local, le signal est
planifié en tenant compte de la latence client (`Server.latency`). Par défaut,
cette valeur est d'environ 0,2 s pour laisser au serveur temps de préparer les
buffers audio. Cela fonctionne bien pour les processus entièrement internes à
SuperCollider, mais crée un décalage audible face aux applications Ableton Link
(ici Ableton Live) qui, elles, jouent leurs clics sans ce délai additionnel.

En réduisant `s.latency` (par exemple `s.latency = 0.02;`), les évènements
sont envoyés au serveur avec seulement 20 ms d'avance, ce qui suffit pour un
usage en temps réel avec une interface audio stable tout en alignant beaucoup
mieux le clic SuperCollider sur celui d'Ableton Live. Si la carte son supporte
des buffers encore plus courts, cette valeur peut être diminuée davantage.
