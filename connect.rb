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

require File.expand_path(File.join(File.dirname(__FILE__), "lib/GenIP"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/OS"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/Flatten"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/History"))

#--------------------------------------------------
class Action
    def initialize(action,ip,puser,sshcom,env,key,type,tail)
        case action
        when "c"
            puts ">>>> Connection to #{ip}"
            $history.push(ip)
            if type == "ssh" then
                spawn sshcom+" #{puser}@#{ip}"+tail
                sleep 1
            else
                spawn sshcom+ip
            end
        when "p"
            system "ping #{ip}"
        when "key","k"
            puts "Copying #{puser}'s ssh key to #{ip}"
            system "ssh-copy-id #{puser}@#{ip}"
        when "push"
            puts "Copying file #{tail} to #{ip}"
            system "scp #{tail} #{puser}@#{ip}:/home/#{puser}/" 
        when "pull"
            puts "Copying file #{tail} from #{ip}"
            system "scp #{puser}@#{ip}:/home/#{puser}/#{tail} ./" 
        when "l"
            puts "The IP for #{key} in #{env} is #{ip}"
        else
            puts "The IP for #{key} in #{env} is #{ip}"
        end
    end
end
#--------------------------------------------------
def getName(ip)
    name = 'Not Found'
    begin
        Resolv::DNS.open() do |r|
            name = r.getname(ip)
        end
    rescue
        name = 'DNS Entry Not Found'
    end
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
def validIP(address)
    address =~ Resolv::IPv4::Regex
end
#--------------------------------------------------
def loadYAML(filename)
    YAML::load_file(File.expand_path(File.join(File.dirname(__FILE__), filename)))
end
def saveYAML(hash,filename)
    pathfile = File.expand_path(File.join(File.dirname(__FILE__), filename))
    FileUtils.cp pathfile, pathfile+'.bak'
    File.open(pathfile,'w') do |f2|
        f2.puts hash.to_yaml
    end
end
#--------------------------------------------------
def searchServer(pattern,myhash,options,envs,sshcom,tail)
    merged = myhash.merge(myhash.invert)
    result = merged.keys.select{|i| i[Regexp.new(options.server[0], "i")]}
    if result.size != 0
        prompt("Details matching #{options.server[0]}")
        rows = []
        counter = 0
        result.each {|key| rows << [counter+1,key,merged[key]]
            counter +=1
        }
        table = Terminal::Table.new :headings => ['','Name', 'IP'], :rows => rows
        puts table
        prompt("Do Connect, Ping or Quit [cpq] ?")
        actions = $stdin.gets.chomp
        actarr = actions.split(',')
        tenv = ""
        actarr.each { |action|
            value = action.to_i
            if value > result.size then
                value = 0
                action = 'q'
            end
            if value != 0 then
                env = 'dev'
                if validIP(merged[result[value-1]]) then
                    ip = merged[result[value-1]]
                else
                    if tenv.empty? then
                        prompt("Which environment? #{envs.keys} ?")
                        tenv = $stdin.gets.chomp
                    end
                    myIP = GenIP.new(merged,envs,result[value-1],tenv)
                    ip = myIP.ip
                    env = tenv
                end
                Action.new('c',ip,options.user,sshcom,env,result[value-1],options.type,tail)
            elsif action != "q" and action != "" then
                prompt("Which environment? #{envs.keys} ?")
                env = $stdin.gets.chomp
                result.each { |key|
                    myIP = GenIP.new(merged,envs,key,env)
                    if myIP.valid then
                        Action.new(action,myIP.ip,options.user,sshcom,env,key,options.type,tail)
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
myhash   = loadYAML('details.yaml')
envs     = loadYAML('envs.yaml')
settings = loadYAML('settings.yaml')

$history = History.new('../history.yaml',settings['historysize'])
user = settings['user']
profile = settings['profile']
winssh = settings['winapp'] + " " + settings['winprofile']
linuxssh = settings['linuxapp'] + " " + settings['linuxprofile']
macssh = settings['macapp'] + " " + settings['macprofile']
rdpwin = settings['rdpwin']
rdplinux = settings['rdplinux']
rdpmac = settings['mac1pp'] 
mactail = settings['mactail']
linuxtail = settings['linuxtail']
wintail = settings['wintail']
sshcom = ""
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


if options.type == "ssh" then
    if OS.windows? then
        sshcom = winssh
        tail = wintail
    elsif OS.linux? then
        sshcom = linuxssh
        tail = linuxtail
    elsif OS.mac? then
        sshcom = macssh
        tail = mactail
    else
        puts 'Sorry do not reckonize your OS'
        exit 1
    end
else
    sshcom = rdpwin if OS.windows?
    sshcom = rdplinux if OS.linux?
    sshcom = rdpmac if OS.mac?
end

case options.action
when "d", "dump"
    #Dump the details list
    rows = []
    count = 1
    myhash.sort.each { |array|
        rows << [count,array[0],array[1]]
        count +=1
    }
    table   = Terminal::Table.new :headings => ['','Name', 'IP'], :rows => rows
    puts table
when "h", "check"
    #Port Scan through servers and ports
    multiservers = Flatten.new(options.server)
    multiports = Flatten.new(options.port)
    multiEnv = Flatten.new(options.envs)

    multiservers.thinArray.each { |address|
        multiEnv.thinArray.each { |env|
            #Check if we've got an IP passed
            if (address =~ Resolv::IPv4::Regex) then
                server = address
            else
                myIP = GenIP.new(myhash,envs,address,env)
                server = myIP.ip
            end
            multiports.thinArray.each { |port|
                open_port(server,port)
            }
        }
    }
when "r","regex","search","s"
    #Search for pattern in details list
    pattern = options.server

    if pattern.size == 1 then
        searchServer(pattern,myhash,options,envs,sshcom,tail)
    else
        puts "Incorrect search pattern #{pattern.to_s}"
        puts help
    end
when "c","p","l","k","connect","ping","list","key","push","pull"
    #Connect, Ping or list details
    action = options.action

    multiKeys = Flatten.new(options.server)
    multiEnv = Flatten.new(options.envs)

    if action == 'push' or action == 'pull' then
	tail=options.file.strip()
    end

    if multiEnv.thinArray.size != 0 and multiKeys.thinArray.size !=0 then
        multiKeys.thinArray.each { |key|
            multiEnv.thinArray.each { |env|
                myIP = GenIP.new(myhash,envs,key,env)
                if myIP.valid then
                    Action.new(action,myIP.ip,options.user,sshcom,env,key,options.type,tail)
                else
                    bright("Key '#{key}' or environment '#{env}' not found, searching...")
                    searchServer(key,myhash,options,envs,sshcom,tail)
                end
            }
        }
    else
        if validIP(multiKeys.thinArray[0]) then
            Action.new(action,multiKeys.thinArray[0],options.user,sshcom,'dev',multiKeys.thinArray[0],options.type,tail)
        else
            brght("Error: you must pass both server and environment options")
            puts help
        end
    end
when 'f', 'file'
    connections = YAML::load_file(options.file)
    servers = connections["servers"].inject(:merge)
    servers.each { |key,value|
        myIP = GenIP.new(myhash,envs,key,value)
        if myIP.valid then
            Action.new(connections["action"],myIP.ip,options.user,sshcom,value,key,options.type,tail)
        else
            bright("Key '#{key}' or environment '#{value}' not found")
        end
    }
when 'a','add'
    puts "Adding #{options.server[0]}, #{options.envs[0]} to the YAML"
    myhash[options.server[0]]=options.envs[0]
    saveYAML(myhash,'details.yaml')
when 'last'
    ip = $history.history[$history.history.length()-1]
    if validIP(ip) then
        Action.new('c',ip,options.user,sshcom,"dev","",options.type,tail)
    end
when 'H','hist'
    rows = []
    counter = 0
    prompt('Working...')
    merged = myhash.merge(myhash.invert)
        $history.history.each {|key| 
             tmp = merged[key]
	     fqdn = getName(key)
             rows << [counter+1,key,tmp,fqdn]
             counter +=1
        }
    table = Terminal::Table.new :headings =>['','IP','Key','FQDN'], :rows => rows
    puts table
    prompt('Enter number to connect or Enter to quit')
    actions = $stdin.gets.chomp
    actarr = actions.split(',')
    actarr.each { |action|
    value = action.to_i
        if value != 0 and value <= $history.history.size then
            ip = $history.history[value-1]
            if validIP(ip) then
                Action.new('c',ip,options.user,sshcom,"dev","",options.type,tail)
            end
        end
    }
else
    puts help
end
