#!/usr/bin/ruby
# Alastair Montgomery 2014
require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'optparse'
require 'ostruct'
require 'socket'
require 'pp'
require 'terminal-table'
require 'fileutils'
require 'rainbow'
require 'resolv'

require File.expand_path(File.join(File.dirname(__FILE__), "lib/gen_ip"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/os"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/flatten"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/history"))

#--------------------------------------------------
class Action
    def initialize(action,ip,p_user,ssh_com,env,key,type,tail)
        case action
        when "c"
            puts ">>>> Connection to #{ip}"
            $history.push(ip)
            if type == "ssh" then
                spawn ssh_com+" #{p_user}@#{ip}"+tail
                sleep 1
            else
                spawn ssh_com+ip
            end
        when "p"
            system "ping #{ip}"
        when "key","k"
            puts "Copying #{p_user}'s ssh key to #{ip}"
            system "ssh-copy-id #{p_user}@#{ip}"
        when "push"
            puts "Copying file #{tail} to #{ip}"
            system "scp #{tail} #{p_user}@#{ip}:/home/#{p_user}/"
        when "pull"
            puts "Copying file #{tail} from #{ip}"
            system "scp #{p_user}@#{ip}:/home/#{p_user}/#{tail} ./" 
        when "l"
            puts "The IP for #{key} in #{env} is #{ip}"
        else
            puts "The IP for #{key} in #{env} is #{ip}"
        end
    end
end
#--------------------------------------------------
def get_name(ip)
    name = 'Not Found'
#    begin
#        Resolv::DNS.open() do |r|
#            name = r.getname(ip)
#        end
#    rescue
#        name = 'DNS Entry Not Found'
#    end
    return name.to_s
end
#--------------------------------------------------
def bright(text)
   puts Rainbow(text).bright.red
end
#--------------------------------------------------
def prompt(text)
    puts Rainbow(text).green
end
#--------------------------------------------------
def open_port(host, port)
  print "Checking #{host} on port #{port}"
  sock = Socket.new(:INET, :STREAM)
  raw = Socket.sockaddr_in(port, host)
  if sock.connect(raw) then
    puts " - open."
  else
    puts " - closed."
  end

rescue (Errno::ECONNREFUSED)
    puts " - closed."
  rescue(Errno::ETIMEDOUT)
    puts " - closed."
end
#--------------------------------------------------
def terminal_manager
  return :herdr if ENV["HERDR_ENV"] == "1"
  return :tmux if ENV["TMUX"]

  :none
end
#--------------------------------------------------
def valid_ip(address)
    address =~ Resolv::IPv4::Regex
end
#--------------------------------------------------
def load_yaml(filename)
    path = File.expand_path(File.join(File.dirname(__FILE__), filename))
    YAML.safe_load(File.read(path), permitted_classes: [Symbol])
end
def save_yaml(hash,filename)
    pathfile = File.expand_path(File.join(File.dirname(__FILE__), filename))
    FileUtils.cp pathfile, pathfile+'.bak'
    File.open(pathfile,'w') do |f2|
        f2.puts hash.to_yaml
    end
end
#--------------------------------------------------
def search_server(pattern,my_hash,options,envs,ssh_com,tail)
    merged = my_hash.merge(my_hash.invert)
    result = merged.keys.select{|i| i[Regexp.new(options.server[0], "i")]}
    if result.size != 0
        prompt("Details matching #{options.server[0]}")
        rows = []
        counter = 0
        result.each {|key| rows << [counter+1,key,merged[key]["ip"]]
            counter +=1
        }
        table = Terminal::Table.new :headings => ['','Name', 'IP'], :rows => rows
        puts table
        prompt("Do Connect, Ping or Quit [cpq] ?")
        actions = $stdin.gets.chomp
        act_arr = actions.split(',')
        t_env = ""
        act_arr.each { |action|
            value = action.to_i
            if value > result.size then
                value = 0
                action = 'q'
            end
            if value != 0 then
                env = 'dev'
                puts merged[result[value-1]]["ip"].to_s
                if valid_ip(merged[result[value-1]]["ip"]) then
                    ip = merged[result[value-1]]["ip"]
                else
                    if t_env.empty? then
                        prompt("Which environment? #{envs.keys} ?")
                        t_env = $stdin.gets.chomp
                    end
                    my_ip = GenIP.new(merged,envs,result[value-1]["ip"],t_env)
                    ip = my_ip.ip
                    env = t_env
                end
                user = options.user
                if merged[result[value-1]]["user"] then
                    user = merged[result[value-1]]["user"]
                end
                Action.new('c',ip,user,ssh_com,env,result[value-1],options.type,tail)
            elsif action != "q" and action != "" then
                prompt("Which environment? #{envs.keys} ?")
                env = $stdin.gets.chomp
                result.each { |key|
                    my_ip = GenIP.new(merged,envs,key,env)
                    if my_ip.valid then
                        user = merged[result[value-1]]["user"] || options.user
                        Action.new(action,my_ip.ip,user,ssh_com,env,key,options.type,tail)
                    else
                        puts "Key '#{key}' or environment '#{env}' not found"
                    end
                }
            end
        }
    else
        puts "Error: No matching details found for '#{options.server[0]}'"
    end
end
#--------------------------------------------------
#--------------------------------------------------
#Load data


puts "Aghhh I'm running on Windows ):" if OS.windows?
bright("Linux, everything is right with the world (:") if OS.linux?
bright("Mac, shiny :)") if OS.mac?
puts "\n"
my_hash   = load_yaml('config/details.yaml')
envs     = load_yaml('config/envs.yaml')
settings = load_yaml('config/settings.yaml')

prompt("Loaded #{my_hash.size} server details")
prompt("Loaded #{envs.size} environments")

$history = History.new('../config/history.yaml',settings['historysize'])
user = settings['user']
profile = settings['profile']
win_ssh = settings['winapp'] + " " + settings['winprofile']
linux_ssh = settings['linuxapp'] + " " + settings['linuxprofile']
herdr_ssh = settings['herdrapp'] + " " + settings['herdrprofile']
mac_ssh = settings['macapp'] + " " + settings['macprofile']
rdp_win = settings['rdpwin']
rdp_linux = settings['rdplinux']
rdp_mac = settings['macrdp'] 
mac_tail = settings['mactail']
linux_tail = settings['linuxtail']
herdr_tail = settings['herdrtail']
win_tail = settings['wintail']
ssh_com = ""
tail = ""
#Check options
opts = OptionParser.new
options = OpenStruct.new
options.action = ''
options.server = []
options.envs = []
options.port = []
options.file = ''
options.type = 'ssh'
options.user = user

opts.on("-a [cpldrhkH]", "--action", String, "Connect, Ping, List, Dump, Regex, cHeck ports, copy ssh Key, History") { |v| options.action = v}
opts.on("-s server", "--servers", String, "List of servers to action") { |v| options.server << v }
opts.on("-e environment", "--env", String, "List of environments") { |v| options.envs << v }
opts.on("-p port", "--port", String, "Port for connection or scanning") { |v| options.port << v }
opts.on("-f file", "--file", String, "YAML file of servers to process") { |v| options.file = v}
opts.on("-t type", "--type", String, "ssh or rdp") { |v| options.type = v }
opts.on("-u user", "--user", String, "Username") { |u| options.user = u.chomp}
begin
    opts.parse!(ARGV)
rescue OptionParser::ParseError => e
    puts e
end

help = opts.help


case options.type
when "ssh"
    case
    when OS.windows?
        ssh_com = win_ssh
        tail = win_tail
    when OS.linux?
        if terminal_manager == :herdr
          ssh_com = herdr_ssh
          tail = herdr_tail
        else
          ssh_com = linux_ssh
          tail = linux_tail
        end
    when OS.mac?
        ssh_com = mac_ssh
        tail = mac_tail
    else
        puts 'Sorry, do not recognize your OS'
        exit 1
    end
else
    ssh_com = case
        when OS.windows? then rdp_win
        when OS.linux?   then rdp_linux
        when OS.mac?     then rdp_mac
        else
            puts 'Sorry, do not recognize your OS'
            exit 1
        end
end

case options.action
when "d", "dump"
    #Dump the details list
    rows = []
    count = 1
    my_hash.sort.each { |array|
        rows << [count,array[0],array[1]]
        count +=1
    }
    table   = Terminal::Table.new :headings => ['','Name', 'IP'], :rows => rows
    puts table
when "h", "check"
    #Port Scan through servers and ports
    multi_servers = Flatten.new(options.server)
    multi_ports = Flatten.new(options.port)
    multi_env = Flatten.new(options.envs)

    multi_servers.thin_array.each { |address|
        multi_env.thin_array.each { |env|
            #Check if we've got an IP passed
            if (address =~ Resolv::IPv4::Regex) then
                server = address
            else
                my_ip = GenIP.new(my_hash,envs,address,env)
                server = my_ip.ip
            end
            multi_ports.thin_array.each { |port|
                open_port(server,port)
            }
        }
    }
when "r","regex","search","s"
    #Search for pattern in details list
    pattern = options.server

    if pattern.size == 1 then
        search_server(pattern,my_hash,options,envs,ssh_com,tail)
    else
        puts "Incorrect search pattern #{pattern.to_s}"
        puts help
    end
when "c","p","l","k","connect","ping","list","key","push","pull"
    #Connect, Ping or list details
    action = options.action

    multi_keys = Flatten.new(options.server)
    multi_env = Flatten.new(options.envs)

    if action == 'push' or action == 'pull' then
	tail=options.file.strip()
    end

    if multi_env.thin_array.size != 0 and multi_keys.thin_array.size !=0 then
        multi_keys.thin_array.each { |key|
            multi_env.thin_array.each { |env|
                my_ip = GenIP.new(my_hash,envs,key,env)
                if my_ip.valid then
                    Action.new(action,my_ip.ip,options.user,ssh_com,env,key,options.type,tail)
                else
                    bright("Key '#{key}' or environment '#{env}' not found, searching...")
                    search_server(key,my_hash,options,envs,ssh_com,tail)
                end
            }
        }
    else
        if valid_ip(multi_keys.thin_array[0]) then
            Action.new(action,multi_keys.thin_array[0],options.user,ssh_com,'dev',multi_keys.thin_array[0],options.type,tail)
        else
            bright("Error: you must pass both server and environment options")
            puts help
        end
    end
when 'f', 'file'
    connections = YAML.safe_load(File.read(options.file), permitted_classes: [Symbol])
    servers = connections["servers"].inject(:merge)
    servers.each { |key,value|
        my_ip = GenIP.new(my_hash,envs,key,value)
        if my_ip.valid then
            Action.new(connections["action"],my_ip.ip,options.user,ssh_com,value,key,options.type,tail)
        else
            bright("Key '#{key}' or environment '#{value}' not found")
        end
    }
when 'a','add'
    puts "Adding #{options.server[0]}, #{options.envs[0]} to the YAML"
    my_hash[options.server[0]] = {"ip" => options.envs[0]}
    save_yaml(my_hash,'config/details.yaml')
when 'last'
    ip = $history.history[$history.history.length()-1]
    if valid_ip(ip) then
        Action.new('c',ip,options.user,ssh_com,"dev","",options.type,tail)
    end
when 'H','hist'
    rows = []
    counter = 0
    prompt('Working...')
    merged = my_hash.merge(my_hash.invert)
        $history.history.each {|key| 
             tmp = merged[key]
	     fqdn = get_name(key)
             rows << [counter+1,key,tmp,fqdn]
             counter +=1
        }
    table = Terminal::Table.new :headings =>['','IP','Key','FQDN'], :rows => rows
    puts table
    prompt('Enter number to connect or Enter to quit')
    actions = $stdin.gets.chomp
    act_arr = actions.split(',')
    act_arr.each { |action|
    value = action.to_i
        if value != 0 and value <= $history.history.size then
            ip = $history.history[value-1]
            if valid_ip(ip) then
                Action.new('c',ip,options.user,ssh_com,"dev","",options.type,tail)
            end
        end
    }
else
    puts help
end
