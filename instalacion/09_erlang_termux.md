# 9 · Erlang/OTP + rebar3 en Termux (Android)

Guía autocontenida para tener un entorno de Erlang/OTP en un teléfono Android, usando
un asistente de IA con acceso SSH. Alternativa móvil a [03_erlang.md](03_erlang.md)
(Ubuntu ARM64). Complementa el [tema 2.1](../unidad2/tema2.1/README.md) (Erlang).

> Los 4 demos fueron probados en Termux (Android aarch64, OTP 29, rebar3 3.27.3).

## Antes de empezar (lo haces tú, en el teléfono)

```sh
pkg update -y && pkg install -y openssh
passwd                       # define tu contraseña
sshd                         # inicia SSH en el puerto 8022
termux-wake-lock             # evita que Android cierre Termux y tumbe sshd
whoami                       # tu usuario (ej. u0_a123)
ifconfig | grep inet         # tu IP en la red WiFi
```

El teléfono y la computadora deben estar en la misma red. Autoriza la llave pública de tu computadora:

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'PEGA_AQUI_TU_LLAVE_PUBLICA' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

(La llave se ve con `cat ~/.ssh/id_ed25519.pub` en tu computadora. Si no tienes: `ssh-keygen -t ed25519`.)
Si la conexión se rechaza ("Connection refused"), Android cerró Termux: ábrelo y ejecuta `sshd` otra vez.

## Prompt

```
Eres experto en Termux y en Erlang/OTP. Tienes acceso SSH a mi dispositivo Android:
  ssh -p 8022 USUARIO@IP
Necesito un entorno de programación funcional con Erlang/OTP para mi curso. Instálalo y verifícalo.

REGLAS
- Termux usa `pkg` (no sudo). No existe /tmp: usa $TMPDIR.
- Conéctate con BatchMode (sin contraseña interactiva, usa mi llave).
- Antes de ejecutar algo descargado de internet, descárgalo, léelo y muéstramelo.
  Si es un binario/zip (como rebar3), dime que solo pudiste revisar la cabecera y de dónde lo bajaste.
- No me hagas preguntas innecesarias. Si algo no existe en Termux, dime el equivalente.

PASOS
1. pkg update -y && pkg upgrade -y
2. pkg install -y erlang   (incluye OTP: gen_server, supervisor, gen_statem, eunit, dialyzer...)
   Verifica: erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]), halt().'
3. rebar3 NO está como paquete de Termux. Descárgalo a $TMPDIR desde
   https://s3.amazonaws.com/rebar3/rebar3 , revisa la cabecera (#!/usr/bin/env escript),
   muévelo a ~/bin/rebar3, chmod +x, y agrega `export PATH=$HOME/bin:$PATH` a ~/.bashrc y ~/.zshrc.
   Verifica: rebar3 version
4. Ejecuta los 4 demos de la sección "Demos" de este documento y reporta la salida de cada uno:
   - Demo 1: Erlang puro  (erlc + erl)
   - Demo 2: gen_server + supervisor  (OTP)
   - Demo 3: proyecto rebar3 con pruebas eunit
   - Demo 4: gen_server que muestrea sensores (fuente simulada; la real requiere Termux:API)
5. Entrégame una tabla con versiones (erl/OTP, erlc, rebar3) y qué quedó sin instalar y por qué.

NOTAS DE TERMUX
- `observer` (gráfico) normalmente no funciona; para inspeccionar usa `erl` con `i().`, `processes().`,
  `sys:get_state(Pid)`, `etop` o `recon`.
- Para probar ideas rápido usa `rebar3 shell` (recompila y carga tu proyecto).
- Recarga de código en caliente dentro del shell: `c(modulo).`
- Si SSH da "Connection refused", Termux fue cerrado por Android: pídeme ejecutar `sshd` de nuevo.
```

## Recomendaciones para desarrollo experimental

- Trabaja en el shell (`rebar3 shell` / `erl`) y prueba ideas ahí antes de escribir módulos.
- Empieza con procesos y mensajes (`spawn`, `!`, `receive`) y después pasa a `gen_server`.
- Mata procesos a propósito (demo 2) para ver al `supervisor` reiniciarlos ("let it crash").
- Escribe una prueba `eunit` por cada función pura que agregues (`rebar3 eunit`).
- Usa `tmux` (shell, editor, trazas) y `asciinema rec` para grabar tus sesiones.
- Análisis estático: `rebar3 dialyzer`. Trazas: `sys:trace(Pid, true)`.

## Demos

### Demo 1: Erlang puro

Archivo `demo1_erlang.erl`:

```erlang
%% Demo 1: Erlang puro - recursion, pattern matching, listas y procesos.
-module(demo1_erlang).
-export([main/0, factorial/1, fib/1, ping/0]).

factorial(0) -> 1;
factorial(N) when N > 0 -> N * factorial(N - 1).

fib(0) -> 0;
fib(1) -> 1;
fib(N) when N > 1 -> fib(N - 1) + fib(N - 2).

%% Un proceso que responde "pong" a quien le mande {ping, Pid}
ping() ->
    receive
        {ping, From} -> From ! pong, ping();
        stop -> ok
    end.

main() ->
    io:format("5! = ~p~n", [factorial(5)]),
    io:format("fib(0..10) = ~p~n", [[fib(N) || N <- lists:seq(0, 10)]]),
    Pares = lists:filter(fun(X) -> X rem 2 =:= 0 end, lists:seq(1, 10)),
    io:format("pares = ~p, suma de cuadrados = ~p~n",
              [Pares, lists:sum(lists:map(fun(X) -> X * X end, Pares))]),
    Pid = spawn(fun ping/0),
    Pid ! {ping, self()},
    receive pong -> io:format("recibido: pong~n") after 1000 -> io:format("timeout~n") end,
    Pid ! stop,
    ok.
```

Ejecutar:

```sh
erlc demo1_erlang.erl && erl -noshell -eval "demo1_erlang:main(), halt()."
```

Salida esperada:

```
5! = 120
fib(0..10) = [0,1,1,2,3,5,8,13,21,34,55]
pares = [2,4,6,8,10], suma de cuadrados = 220
recibido: pong
```

### Demo 2: gen_server y supervisor (OTP)

Archivo `contador.erl`:

```erlang
%% Demo 2: gen_server (OTP) - un contador con estado.
-module(contador).
-behaviour(gen_server).
-export([start_link/0, inc/0, get/0, boom/0]).
-export([init/1, handle_call/3, handle_cast/2]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, 0, []).
inc()  -> gen_server:cast(?MODULE, inc).
get()  -> gen_server:call(?MODULE, get).
boom() -> gen_server:cast(?MODULE, boom).   %% provoca un fallo a proposito

init(N) -> {ok, N}.
handle_call(get, _From, N) -> {reply, N, N}.
handle_cast(inc, N)  -> {noreply, N + 1};
handle_cast(boom, _) -> exit(fallo_provocado).
```

Archivo `contador_sup.erl`:

```erlang
%% Supervisor: reinicia el contador si se cae ("let it crash").
-module(contador_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Hijo = #{id => contador, start => {contador, start_link, []}, restart => permanent},
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [Hijo]}}.
```

Ejecutar:

```sh
erlc contador.erl contador_sup.erl
erl -noshell -eval "
{ok,_}=contador_sup:start_link(),
contador:inc(), contador:inc(),
io:format(\"antes del fallo: ~p~n\",[contador:get()]),
contador:boom(), timer:sleep(300),
io:format(\"despues del reinicio: ~p~n\",[contador:get()]),
halt()."
```

Salida esperada: `antes del fallo: 2`, un `ERROR REPORT` (el fallo provocado a propósito) y
`despues del reinicio: 0` (el supervisor reinició el contador con estado nuevo).

### Demo 3: proyecto rebar3 con eunit

```sh
rebar3 new app demo_rebar && cd demo_rebar
# guarda calc.erl en src/ y luego:
rebar3 eunit
rebar3 shell --eval 'io:format("~p~n",[calc:suma(2,3)]), halt().'
```

Archivo `src/calc.erl`:

```erlang
%% Demo 3: modulo de un proyecto rebar3, con sus pruebas eunit.
-module(calc).
-export([suma/2, promedio/1]).
-include_lib("eunit/include/eunit.hrl").

suma(A, B) -> A + B.
promedio([]) -> 0;
promedio(L) -> lists:sum(L) / length(L).

%% Pruebas (se ejecutan con: rebar3 eunit)
suma_test() -> ?assertEqual(5, suma(2, 3)).
promedio_test_() ->
    [?_assertEqual(0, promedio([])),
     ?_assertEqual(2.0, promedio([1, 2, 3]))].
```

Salida esperada de `rebar3 eunit`: `3 tests, 0 failures`; y del shell: `5`.

### Demo 4: sensores del Android en un gen_server

Muestrea temperatura de la batería, acelerómetro, luz y proximidad. Tiene dos fuentes:
`simulado` (datos aleatorios, funciona en cualquier Termux) y `termux` (lee sensores reales con
Termux:API).

**Importante:** Termux instalado desde Google Play **no** tiene la app Termux:API, y `termux-sensor`
responde "Termux:API is not yet available on Google Play". Para sensores reales instala Termux y
Termux:API desde F-Droid o GitHub (esto exige desinstalar el Termux de Play; respalda tus archivos)
y ejecuta `pkg install termux-api`. Android casi nunca tiene sensor de temperatura ambiente: la
temperatura real disponible es la de la batería. Ver qué sensores tiene tu teléfono: `termux-sensor -l`.

Archivo `sensores.erl`:

```erlang
%% Demo 4: gen_server que muestrea sensores del Android.
%% Fuente = simulado (datos aleatorios) | termux (Termux:API, requiere Termux de F-Droid/GitHub).
-module(sensores).
-behaviour(gen_server).
-export([start_link/1, start_link/2, leer/1, historial/1, promedio/1, lista/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([parsear_bateria/1, parsear_sensor/1]).
-include_lib("eunit/include/eunit.hrl").

-define(SENSORES, [temperatura_bateria, acelerometro, luz, proximidad]).
-define(MAX_HIST, 10).

%% --- API ---------------------------------------------------------------
start_link(Fuente) -> start_link(Fuente, 500).
start_link(Fuente, Intervalo) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, {Fuente, Intervalo}, []).

lista() -> ?SENSORES.
leer(S)      -> gen_server:call(?MODULE, {leer, S}).
historial(S) -> gen_server:call(?MODULE, {historial, S}).
promedio(S)  -> gen_server:call(?MODULE, {promedio, S}).

%% --- gen_server --------------------------------------------------------
init({Fuente, Intervalo}) ->
    self() ! muestrear,
    {ok, #{fuente => Fuente, intervalo => Intervalo, lecturas => #{}}}.

handle_call({leer, S}, _From, #{lecturas := L} = E) ->
    {reply, case maps:get(S, L, []) of [] -> sin_datos; [V | _] -> V end, E};
handle_call({historial, S}, _From, #{lecturas := L} = E) ->
    {reply, maps:get(S, L, []), E};
handle_call({promedio, S}, _From, #{lecturas := L} = E) ->
    {reply, promedio_de(maps:get(S, L, [])), E}.

handle_cast(_Msg, E) -> {noreply, E}.

%% El siguiente muestreo se programa al TERMINAR el actual: con comandos lentos
%% (termux-*) un temporizador fijo encolaria muestreos y bloquearia las llamadas.
handle_info(muestrear, #{fuente := F, intervalo := I, lecturas := L} = E) ->
    L2 = lists:foldl(fun(S, Acc) ->
             try obtener(F, S) of
                 V -> maps:update_with(S, fun(H) -> lists:sublist([V | H], ?MAX_HIST) end, [V], Acc)
             catch _:_ -> Acc   %% si una lectura falla, se omite (no tumba al servidor)
             end
         end, L, ?SENSORES),
    erlang:send_after(I, self(), muestrear),
    {noreply, E#{lecturas := L2}};
handle_info(_Otro, E) -> {noreply, E}.

%% --- Fuentes -------------------------------------------------------------
obtener(simulado, temperatura_bateria) -> redondear(30 + rand:uniform() * 10);      %% 30-40 C
obtener(simulado, acelerometro) ->
    {redondear(rand:normal() * 0.3), redondear(rand:normal() * 0.3), redondear(9.8 + rand:normal() * 0.2)};
obtener(simulado, luz)        -> rand:uniform(1000);                                  %% lux
obtener(simulado, proximidad) -> case rand:uniform(2) of 1 -> 0.0; 2 -> 5.0 end;      %% cm
obtener(termux, temperatura_bateria) -> parsear_bateria(os:cmd("termux-battery-status"));
obtener(termux, acelerometro) -> list_to_tuple(parsear_sensor(os:cmd("termux-sensor -s accelerometer -n 1")));
obtener(termux, luz)          -> hd(parsear_sensor(os:cmd("termux-sensor -s light -n 1")));
obtener(termux, proximidad)   -> hd(parsear_sensor(os:cmd("termux-sensor -s proximity -n 1"))).

%% --- Parseo del JSON de Termux:API (puro, se prueba sin telefono) -------
parsear_bateria(Json) ->
    #{<<"temperature">> := T} = json:decode(iolist_to_binary(Json)),
    T.

%% termux-sensor devuelve {"<nombre del sensor>": {"values": [...]}}
parsear_sensor(Json) ->
    [#{<<"values">> := V}] = maps:values(json:decode(iolist_to_binary(Json))),
    V.

%% --- Utilidades ------------------------------------------------------------
promedio_de([]) -> sin_datos;
promedio_de([N | _] = L) when is_number(N) -> redondear(lists:sum(L) / length(L));
promedio_de([T | _] = L) when is_tuple(T) ->      %% promedio por componente (acelerometro)
    Comps = [tuple_to_list(X) || X <- L],
    list_to_tuple([redondear(lists:sum(C) / length(C)) || C <- transponer(Comps)]).

transponer([[] | _]) -> [];
transponer(M) -> [[H || [H | _] <- M] | transponer([T || [_ | T] <- M])].

redondear(X) -> round(X * 100) / 100.

%% --- Pruebas: rebar3 eunit / erl -eval "eunit:test(sensores)" ------------
parsear_bateria_test() ->
    ?assertEqual(31.5, parsear_bateria(<<"{\"percentage\":80,\"temperature\":31.5,\"status\":\"CHARGING\"}">>)).
parsear_sensor_test() ->
    ?assertEqual([0.1, -0.2, 9.8],
        parsear_sensor(<<"{\"LSM6DSO Accelerometer\":{\"values\":[0.1,-0.2,9.8]}}">>)).
promedio_test_() ->
    [?_assertEqual(sin_datos, promedio_de([])),
     ?_assertEqual(2.0, promedio_de([1, 2, 3])),
     ?_assertEqual({2.0, 3.0}, promedio_de([{1, 2}, {3, 4}]))].
```

Ejecutar (fuente simulada):

```sh
erlc sensores.erl
erl -noshell -eval "eunit:test(sensores), halt()."
erl -noshell -eval "
{ok,_}=sensores:start_link(simulado, 100), timer:sleep(1200),
[io:format(\"~-20s ultima=~p promedio=~p~n\",[S, sensores:leer(S), sensores:promedio(S)]) || S <- sensores:lista()],
halt()."
```

Salida esperada: `All 5 tests passed.` y una línea por sensor con su última lectura y su promedio
(los valores cambian en cada ejecución porque son aleatorios). Con Termux:API instalado, cambia
`simulado` por `termux`: la fuente real está probada solo con la temperatura de la batería
(`termux-battery-status` funciona incluso con Termux de Google Play); los demás sensores devuelven
`sin_datos` hasta instalar Termux:API.
