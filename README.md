# README #

This README would normally document whatever steps are necessary to get your application up and running.

### What is this repository for? ###

* Ruby based command line SSH connection manager
* 1.0

### How do I get set up? ###

* Requires Ruby, SSH client (Putty or OpenSSH) and RDP client (Windows own or rdesktop on linux)
* Ruby Gem Terminal Table (gem install terminal-table)
* Configuration via settings.yaml
* Connection details in details.yaml
* Environment details in envs.yaml
* For GUI you need FXRuby [![Gem Version](https://badge.fury.io/rb/fxruby.svg)](http://badge.fury.io/rb/fxruby)

### Usage ###

Usage   :

    connect.rb -s <action> -s [<server>|<server1>,<server2>,...] -e [<environment>|<env1>,<env2>,...] -p ports

Actions :
* c = connect
* p = ping
* l = list ip
* d = dump connections
* r = search for details with regex
* h = check ports are open

Example :

    connect.rb -a c -s app1 -e dev              = connect to app1 in dev
    connect.rb -a l -s app1,app2,proxy -e live = list IPs for app1/2 and proxy in live
    connect.rb -a r -s proxy                     = search of details for connection like "proxy"

Or use the "rcon" scripts as shortcuts.
