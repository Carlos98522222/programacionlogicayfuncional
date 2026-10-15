# 10 · Erlang/OTP + rebar3 en iSH (iPhone / iPad)

Segunda parte de [09_erlang_termux.md](09_erlang_termux.md): el mismo entorno, pero en iOS usando
la app **iSH** (un shell Alpine Linux que corre sobre un emulador x86 de usuario).

> **Estado: borrador sin verificar en un iPhone real.** Los pasos de `apk`, `sshd` y `rebar3` son los
> estándar de Alpine, pero no se han ejecutado en iSH. Cada paso trae su verificación; si falla,
> reporta la salida exacta. Cuando se pruebe, se quita este aviso y se anota versión de iOS, de iSH y de OTP.

## Qué cambia respecto a Termux

| | Termux (Android) | iSH (iOS) |
|---|---|---|
| Sistema | Android nativo (aarch64) | Alpine Linux **x86 32-bit emulado** |
| Gestor de paquetes | `pkg` | `apk` |
| Usuario | no root (`u0_a123`) | `root` (dentro del emulador) |
| SSH | puerto 8022 | puerto 22 |
| Segundo plano | `termux-wake-lock` | iOS suspende iSH; se mantiene vivo con `/dev/location` |
| Sensores (demo 4) | Termux:API | no disponible |
| Velocidad | nativa | notablemente más lenta (emulación): compila poco a poco |

Consecuencia práctica: es un entorno para **aprender y probar** (demos 1–3), no para medir rendimiento.

## Antes de empezar (lo haces tú, en el iPhone)

Abre iSH y ejecuta:

```sh
apk update && apk add openssh
ssh-keygen -A                       # genera las llaves del servidor
passwd                              # define la contraseña de root
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'PEGA_AQUI_TU_LLAVE_PUBLICA' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
/usr/sbin/sshd                      # inicia SSH en el puerto 22
ifconfig | grep inet                # tu IP en la red WiFi
```

(La llave se ve con `cat ~/.ssh/id_ed25519.pub` en tu computadora. Si no tienes: `ssh-keygen -t ed25519`.)

Mantén iSH vivo en segundo plano (iOS lo suspende y tumba `sshd`):

```sh
cat /dev/location > /dev/null &     # iOS pedirá permiso de ubicación: acepta
```

Aun así, **deja iSH abierto en primer plano** mientras el asistente trabaja. El iPhone y la
computadora deben estar en la misma red. Si la conexión se rechaza, iOS cerró iSH: ábrelo y
ejecuta `/usr/sbin/sshd` otra vez.

## Prompt

```
Eres experto en Alpine Linux y en Erlang/OTP. Tienes acceso SSH a mi iPhone (app iSH, Alpine x86 emulado):
  ssh root@IP
Necesito un entorno de programación funcional con Erlang/OTP para mi curso. Instálalo y verifícalo.

REGLAS
- iSH usa `apk` y corre como root (sin sudo). Es un emulador x86 de 32 bits: espera lentitud.
- Conéctate con BatchMode (sin contraseña interactiva, usa mi llave).
- Antes de ejecutar algo descargado de internet, descárgalo, léelo y muéstramelo.
  Si es un binario/zip (como rebar3), dime que solo pudiste revisar la cabecera y de dónde lo bajaste.
- No me hagas preguntas innecesarias. Si algo falla, dame la salida exacta y prueba el plan B.
- No afirmes que algo funciona si no lo ejecutaste.

PASOS
1. cat /etc/alpine-release; uname -m; apk update
2. apk add erlang   (si el paquete no existe en este release, dímelo y muestra `apk search erlang`)
   Verifica: erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]), halt().'
   Plan B si el runtime se cae o se cuelga al arrancar (el emulador no soporta bien varios hilos):
   erl +S 1:1 +A 0 +sbwt none -noshell -eval '...'
   Si el plan B funciona, expórtalo: export ERL_FLAGS="+S 1:1 +A 0 +sbwt none" en ~/.profile
3. rebar3: primero `apk search rebar3`; si existe, `apk add rebar3`.
   Si no, descárgalo a /root/tmp desde https://s3.amazonaws.com/rebar3/rebar3 , revisa la cabecera
   (#!/usr/bin/env escript), muévelo a ~/bin/rebar3, chmod +x y agrega
   `export PATH=$HOME/bin:$PATH` a ~/.profile. Verifica: rebar3 version
4. Ejecuta los demos 1, 2 y 3 de 09_erlang_termux.md (mismo código, sin cambios) y reporta la salida de cada uno.
   El demo 4 (sensores) NO aplica en iSH: iOS no expone sensores al emulador.
5. Entrégame una tabla con versiones (Alpine, erl/OTP, erlc, rebar3) y qué quedó sin instalar y por qué.

NOTAS DE iSH
- Si `apk add` falla por repositorios, revisa /etc/apk/repositories (debe incluir `community`).
- La primera compilación con rebar3 puede tardar minutos: es normal bajo emulación.
- `observer` (gráfico) no funciona; usa `erl` con `i().`, `processes().`, `sys:get_state(Pid)`.
- Si iSH se cierra a media instalación, vuelve a abrirlo y repite el paso: `apk` es idempotente.
```

## Demos

Son los mismos de [09_erlang_termux.md](09_erlang_termux.md#demos): Demo 1 (Erlang puro),
Demo 2 (`gen_server` + `supervisor`) y Demo 3 (proyecto `rebar3` con `eunit`). Las salidas esperadas
son idénticas. El Demo 4 requiere Termux:API y no tiene equivalente en iSH.

## Limitaciones conocidas

- **No hay BEAM nativo para iOS en iSH:** todo corre emulado en x86 de 32 bits, así que la versión
  de OTP depende de lo que Alpine publique para esa arquitectura y release.
- **Un proceso de iSH no sobrevive en segundo plano** sin el truco de `/dev/location`, y aun así iOS
  puede cerrarlo por memoria.
- Para trabajo serio en el teléfono, Termux en Android (guía 09) es la opción recomendada;
  iSH sirve cuando solo se dispone de un iPhone.
