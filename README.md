# README #

A Ruby command-line SSH/RDP connection manager. Give it a short server "key" (e.g. `app1`) and an environment (e.g. `dev`), and it resolves the real IP/hostname from YAML config and spawns an `ssh`/`rdp` session (or pings, port-checks, copies keys, pushes/pulls files, etc).

There is also an old, largely-vestigial FXRuby GUI (`ui/cg.rb`) built on the same lookup logic.

### What is this repository for? ###

* Ruby based command line SSH/RDP connection manager
* 1.0

### How do I get set up? ###

* Requires Ruby, an SSH client (PuTTY or OpenSSH), and an RDP client (Windows' own, `rdesktop`/`xfreerdp` on Linux/Mac)
* Install Ruby gems: `bundle install` (installs `terminal-table`, `rainbow`)
* Configuration is under `config/`:
    * `settings.yaml` — per-user settings: default SSH user, per-OS ssh/rdp command templates, history size
    * `details.yaml` — server key -> `{ip, user}` connection details
    * `envs.yaml` — environment name -> IP octet substitution
    * `history.yaml` — recent connection history (read/written automatically)
* For the GUI you additionally need the `fox16` gem (not in the Gemfile) — [![Gem Version](https://badge.fury.io/rb/fxruby.svg)](http://badge.fury.io/rb/fxruby)

### Usage ###

```
connect.rb -a <action> -s <server[,server2,...]> -e <environment[,env2,...]> [-p port] [-u user] [-t ssh|rdp] [-f file]
```

Or use the `rcon` (Linux/Mac) / `rcon.bat` (Windows) shortcuts, which wrap `connect.rb` positionally:

```
rcon <action> <server> <env>
```

Note: `rcon` currently has a hardcoded absolute path to `connect.rb` rather than resolving relative to itself, so it needs editing to match your install location.

### Actions (`-a`) ###

* `c` / `connect` — open ssh/rdp session
* `p` / `ping` — ping the resolved host
* `l` / `list` — print resolved IP without connecting
* `d` / `dump` — dump all entries in `details.yaml`
* `r` / `regex` / `search` / `s` — regex search across server keys/IPs, then interactively prompts to connect/ping/quit against the matches
* `h` / `check` — port-scan resolved host(s) across the `-p` port list
* `k` / `key` — `ssh-copy-id` the configured user's key to the host
* `push` / `pull` — `scp` a file (`-f`) to/from the host
* `a` / `add` — append a new server key/IP into `details.yaml` (writes a `.bak` backup first)
* `f` / `file` — batch-run connections defined in a YAML file (see `config/testcon.yaml` for the shape: `action` + list of `server: env` pairs)
* `last` — reconnect to the most recent history entry
* `H` / `hist` — show connection history table, prompt to reconnect by number

### Examples ###

```
connect.rb -a c -s app1 -e dev              # connect to app1 in dev
connect.rb -a l -s app1,app2,proxy -e live  # list IPs for app1/2 and proxy in live
connect.rb -a r -s proxy                    # search details for connections like "proxy"
```
