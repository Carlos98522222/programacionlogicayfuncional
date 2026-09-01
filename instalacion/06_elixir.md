# 6 · Elixir — Ubuntu 24.04 ARM64

Guía autocontenida. El curso usa Elixir en ejemplos de la unidad 2/4
(pipe operator, GenServer con sintaxis moderna).

Elixir corre sobre la BEAM: **requiere Erlang** instalado primero
(ver [03_erlang.md](03_erlang.md)).

## Opción A — apt (rápida: Erlang 25 + Elixir empaquetado)

```bash
sudo apt update
sudo apt install -y elixir
elixir --version
# Erlang/OTP 25 ... Elixir 1.14.x
```

Suficiente para los ejemplos del curso. Nota: instala el Erlang de apt (OTP 25)
como dependencia.

## Opción B — Precompilado oficial sobre tu OTP 26 de kerl

Si ya compilaste OTP 26 con kerl ([03_erlang.md](03_erlang.md) Opción B), usa
el paquete precompilado de Elixir que corresponde a tu OTP (los `.zip` de
elixir-lang son bytecode BEAM — independientes de la arquitectura):

```bash
. ~/otp/26.2.5/activate    # asegura OTP 26 en el PATH

ELIXIR_VER=1.16.3
curl -sLo elixir.zip \
  https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VER}/elixir-otp-26.zip
sudo mkdir -p /opt/elixir
sudo unzip -q elixir.zip -d /opt/elixir
echo 'export PATH=/opt/elixir/bin:$PATH' >> ~/.bashrc
export PATH=/opt/elixir/bin:$PATH
```

> El sufijo `-otp-26` del zip **debe coincidir** con tu versión de OTP activa.

## Opción C — asdf (Erlang + Elixir con versiones fijadas)

Recomendada si el curso te pide una versión exacta reproducible entre máquinas
(y entre estudiantes). `asdf` compila Erlang y descarga el Elixir precompilado
correcto para ese OTP.

```bash
# asdf (si no lo tienes)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
. ~/.asdf/asdf.sh

# dependencias para compilar Erlang en Ubuntu 24.04 ARM64
sudo apt install -y build-essential autoconf m4 libncurses-dev \
  libssl-dev libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev \
  libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils

asdf plugin add erlang
asdf plugin add elixir

asdf install erlang 26.2.5
asdf install elixir 1.16.3-otp-26
```

Fija las versiones del proyecto (crea `.tool-versions` en la raíz del repo):

```bash
cd ~/programacionlogicayfuncional
asdf local erlang 26.2.5
asdf local elixir 1.16.3-otp-26
cat .tool-versions
# erlang 26.2.5
# elixir 1.16.3-otp-26
```

Cualquiera que clone el repo y ejecute `asdf install` obtiene exactamente las
mismas versiones.

## Herramientas de proyecto: mix, Hex y rebar3

`mix` es la herramienta de build de Elixir (compilar, correr, probar, gestionar
dependencias). Viene incluida con Elixir. La primera vez instala Hex (gestor de
paquetes) y rebar3 (build de dependencias en Erlang):

```bash
mix local.hex --force
mix local.rebar --force
```

### Primer proyecto

```bash
mix new saludo --module Saludo
cd saludo
mix test          # corre la suite generada
iex -S mix        # REPL con el proyecto cargado
```

En el `iex`:

```elixir
iex(1)> Saludo.hello()
:world
```

Estructura mínima que genera `mix new`:

```
saludo/
├── lib/saludo.ex        # código
├── test/saludo_test.exs # pruebas (ExUnit)
├── mix.exs              # definición del proyecto y dependencias
└── .formatter.exs       # reglas de `mix format`
```

Agregar una dependencia (ejemplo: `jason` para JSON) — se declara en `mix.exs`:

```elixir
defp deps do
  [
    {:jason, "~> 1.4"}
  ]
end
```

```bash
mix deps.get
mix deps.compile
```

## GenServer con sintaxis moderna (unidad 2)

Ejemplo verificable de la unidad 2/4: un contador como proceso con estado,
usando la sintaxis actual (`start_link/1`, `@impl true`, `GenServer.call/cast`).
Guárdalo en `lib/contador.ex` de un proyecto `mix new`:

```elixir
defmodule Contador do
  use GenServer

  # --- API pública (se ejecuta en el proceso llamador) ---

  def start_link(inicial \\ 0) do
    GenServer.start_link(__MODULE__, inicial, name: __MODULE__)
  end

  def incrementar(n \\ 1), do: GenServer.cast(__MODULE__, {:incrementar, n})
  def valor, do: GenServer.call(__MODULE__, :valor)

  # --- Callbacks (se ejecutan en el proceso del GenServer) ---

  @impl true
  def init(inicial), do: {:ok, inicial}

  @impl true
  def handle_cast({:incrementar, n}, estado), do: {:noreply, estado + n}

  @impl true
  def handle_call(:valor, _from, estado), do: {:reply, estado, estado}
end
```

Prueba en `iex -S mix`:

```elixir
iex(1)> Contador.start_link(10)
{:ok, #PID<0.150.0>}
iex(2)> Contador.incrementar()
:ok
iex(3)> Contador.incrementar(5)
:ok
iex(4)> Contador.valor()
16
```

`cast` es asíncrono (no espera respuesta); `call` es síncrono (bloquea hasta el
`{:reply, ...}`). El estado vive solo dentro del proceso: si el proceso muere,
el estado se reinicia — de ahí que en producción un `Supervisor` lo reinicie
(patrón "let it crash" de la BEAM; ver [03_erlang.md](03_erlang.md)).

## Editor / LSP

Para autocompletado, ir a definición y errores en vivo se usa **ElixirLS**
(language server). En VS Code: extensión "ElixirLS: Elixir support and debugger".
En Neovim: `elixir-ls` vía `mason.nvim` o `nvim-lspconfig`. Requiere que
`elixir` y `mix` estén en el `PATH` del editor (con asdf, abre el editor desde
una terminal donde `elixir --version` funcione, o configura `shims`).

`mix format` aplica el estilo estándar del lenguaje (sin configuración, sin
debates): córrelo antes de entregar cualquier práctica.

```bash
mix format
mix format --check-formatted   # falla si algo no está formateado (útil en CI)
```

## Verificación

```bash
elixir --version
```

Prueba con el pipe operator (unidad 2):

```bash
elixir -e '
1..10
|> Enum.map(&(&1 * &1))
|> Enum.filter(&(rem(&1, 2) == 0))
|> Enum.sum()
|> IO.puts()
'
# 220
```

REPL interactivo:

```bash
iex
iex(1)> "hola mundo" |> String.upcase() |> String.split()
["HOLA", "MUNDO"]
```

## Solución de problemas

| Síntoma | Causa / solución |
|---------|------------------|
| `elixir: command not found` (Opción B) | `export PATH=/opt/elixir/bin:$PATH` o reabre sesión |
| Crash al arrancar iex | Mezcla de versiones: el zip `-otp-26` corriendo sobre OTP 25 — activa el OTP correcto |
| `mix` pide Hex | `mix local.hex --force` la primera vez |
| `asdf install elixir` falla con "No preexisting Erlang" | Instala primero `asdf install erlang <ver>` y elige el Elixir `-otp-<misma>` |
| `asdf install erlang` falla al compilar wx | Falta `libwxgtk3.2-dev`; en servidores sin GUI usa `KERL_CONFIGURE_OPTIONS="--without-wx"` |
| El editor no encuentra `elixir` con asdf | Ábrelo desde una terminal con las shims cargadas, o usa `asdf reshim` |
| `mix deps.get` no resuelve nada | Sin conexión o falta Hex: `mix local.hex --force` y reintenta |
| `iex` no autocompleta módulos del proyecto | Arráncalo con `iex -S mix`, no `iex` a secas |
