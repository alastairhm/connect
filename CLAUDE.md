# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Ruby command-line SSH/RDP connection manager. Given a short server "key" (e.g. `app1`) and an environment (e.g. `dev`), it resolves the real IP/hostname from YAML config and spawns an `ssh`/`rdp` session (or pings, port-checks, copies keys, pushes/pulls files, etc). There is also an old, largely-vestigial FXRuby GUI (`cg.rb`) built on the same lookup logic.

## Setup & running

```
bundle install          # installs terminal-table, rainbow
./connect.rb -a <action> -s <server[,server2,...]> -e <environment[,env2,...]> [-p port] [-u user] [-t ssh|rdp] [-f file]
```

Shortcuts: `./rcon <action> <server> <env>` (Linux/Mac) and `rcon.bat` (Windows) wrap `connect.rb` positionally — note `rcon` currently has a hardcoded absolute path (`/home/alastair/projects/git/connect/connect.rb`) rather than resolving relative to itself.

Actions (`-a`):
- `c` / `connect` — open ssh/rdp session
- `p` / `ping` — ping the resolved host
- `l` / `list` — print resolved IP without connecting
- `d` / `dump` — dump all entries in `details.yaml`
- `r` / `regex` / `search` / `s` — regex search across server keys/IPs, then interactively prompts to connect/ping/quit against the matches
- `h` / `check` — port-scan resolved host(s) across `-p` port list
- `k` / `key` — `ssh-copy-id` the configured user's key to the host
- `push` / `pull` — `scp` a file (`-f`) to/from the host
- `a` / `add` — append a new server key/IP into `details.yaml` (writes a `.bak` backup first)
- `f` / `file` — batch-run connections defined in a YAML file (see `config/testcon.yaml` for the shape: `action` + list of `server: env` pairs)
- `last` — reconnect to the most recent history entry
- `H` / `hist` — show connection history table, prompt to reconnect by number

There is no automated test suite, linter, or CI config in this repo — verify changes by running `connect.rb` directly with the actions above.

## Architecture

**Entry points**: `connect.rb` (CLI, actively maintained) and `ui/cg.rb` (FXRuby GUI wrapper, requires the `fox16` gem which is *not* in the Gemfile — treat as legacy/unmaintained unless told otherwise).

**Config loading** (all via `load_yaml`/`YAML.safe_load` in `connect.rb`, paths relative to repo root):
- `config/settings.yaml` — per-user settings: default SSH user, per-OS ssh/rdp command templates (`winapp`/`linuxapp`/`macapp`/`herdrapp` + matching `*profile`/`*tail` suffixes), history size.
- `config/envs.yaml` — maps environment name (`dev`/`test`/`live`) to a numeric octet substituted into IPs.
- `config/details.yaml` — maps a server *key* to `{ip: "...", user: "..."}`. IPs containing the literal string `xxx` are templates — the `xxx` is replaced with the env's octet from `envs.yaml` at resolution time (see `GenIP`). `user` is optional per-entry override of the default user.
- `config/history.yaml` — read/written by `History` (`lib/history.rb`); a capped, deduped list of recently-connected IPs.

**Core resolution flow**: `GenIP` (`lib/gen_ip.rb`) is the single place IP resolution happens — given `(details_hash, envs_hash, key, env)` it returns `[ip, valid]`. If `key` is already a literal IPv4 address it's passed through as-is; otherwise it looks up `key` in the details hash and substitutes the env octet into any `xxx` placeholder. Both `connect.rb` and `ui/cg.rb` route all lookups through this class — any change to the lookup/templating semantics belongs here, not duplicated at call sites.

**OS/terminal dispatch**: `lib/os.rb` (`OS.windows?`/`mac?`/`linux?`, via `RUBY_PLATFORM` regex) and `terminal_manager` in `connect.rb` (detects `$HERDR_ENV` / `$TMUX`) together pick which ssh command template and tail from `settings.yaml` to use — this determines whether a connection opens in a new tmux window, a "herdr" pane (see `scripts/herd_ssh`), a raw putty/mstsc invocation, or an iTerm tab (`scripts/iterm.scpt` / `scripts/itermtab.scpt`, invoked from macOS). When adding a new terminal integration, extend this dispatch plus add the corresponding `*app`/`*profile`/`*tail` keys to `settings.yaml`.

**`Action`** (in `connect.rb`) is the single dispatcher that turns a resolved `(action, ip, user, ssh_com, ...)` tuple into a spawned/system command (ssh, ping, ssh-copy-id, scp push/pull). All action handling funnels through here.

**`Flatten`** (`lib/flatten.rb`) turns OptionParser's array-of-repeated-flags (e.g. multiple `-s`) into a flat list, also splitting any comma-separated values within a single `-s`/`-e`/`-p` — this is how `-s app1,app2 -e dev,test` expands into a cartesian product of connections in `connect.rb`.

**`search_server`** in `connect.rb` implements the `r`/`search` action: regex-matches against a hash merged with its own inversion (so it matches either keys or IPs), presents a numbered table, then reads an interactive comma-separated response (`c`/`p`/`q`/number) from stdin to act on selected results.
