#!/usr/bin/ruby
# Alastair Montgomery 2014
require 'yaml'
require 'optparse'
require 'ostruct'
require 'socket'
require 'pp'
require 'terminal-table'

require File.expand_path(File.join(File.dirname(__FILE__), "lib/GenIP"))
require File.expand_path(File.join(File.dirname(__FILE__), "lib/OS"))

#--------------------------------------------------
class Action
    def initialize(action,ip,puser,sshcom,env,key,type)
        #puts "#{action},#{ip},#{puser},#{sshcom},#{env},#{key},#{type}"

        case action
        when "c"
            puts ">>>> Connection to #{ip}"
            if type == "ssh" then
                #puts "#{sshcom} #{puser}@#{ip}"
                spawn sshcom+" #{puser}@#{ip}" if OS.windows?
                spawn sshcom+"#{puser}@#{ip}\" > /dev/null 2>&1 &" if OS.linux?
            else
                spawn sshcom+ip
            end
        when "p"
            system "ping #{ip}"
        when "l"
            puts "The IP for #{key} in #{env} is #{ip}"
        else
            puts "The IP for #{key} in #{env} is #{ip}"
        end
    end
end
#--------------------------------------------------
class Flatten
    attr_reader :thinArray, :origArray
    def initialize(fatArray)
        @origArray = fatArray
        tmp = Array.new()
        fatArray.each {|d| tmp << d.split(',')}
        tmp.flatten!
        @thinArray = tmp
    end
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
#--------------------------------------------------
def searchServer(pattern,myhash,options,envs,sshcom)
    result = myhash.keys.select{|i| i[Regexp.new options.server[0]]}
    if result.size != 0
        puts "Details matching #{options.server[0]}"
        rows = []
        counter = 0
        result.each {|key| rows << [counter+1,key,myhash[key]]
            counter +=1
        }
        table = Terminal::Table.new :headings => ['','Name', 'IP'], :rows => rows
        puts table
        puts "Do Connect, Ping or Quit [cpq] ?"
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
                if validIP(myhash[result[value-1]]) then
                    ip = myhash[result[value-1]]
                else
                    if tenv.empty? then
                        puts "Which environment? #{envs.keys} ?"
                        tenv = $stdin.gets.chomp
                    end
                    myIP = GenIP.new(myhash,envs,result[value-1],tenv)
                    ip = myIP.ip
                    env = tenv
                end
                Action.new('c',ip,options.user,sshcom,env,result[value-1],options.type)
            elsif action != "q" and action != "" then
                puts "Which environment? #{envs.keys} ?"
                env = $stdin.gets.chomp
                result.each { |key|
                    myIP = GenIP.new(myhash,envs,key,env)
                    if myIP.valid then
                        Action.new(action,myIP.ip,options.user,sshcom,env,key,options.type)
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
puts "Windows" if OS.windows?
puts "Linux " if OS.linux?
myhash   = loadYAML('details.yaml')
envs     = loadYAML('envs.yaml')
settings = loadYAML('settings.yaml')

user = settings['user']
profile = settings['profile']
winssh = settings['winapp'] + " " + settings['winprofile']
linuxssh = settings['linuxapp'] + " " + settings['linuxprofile']
rdpwin = settings['rdpwin']
rdplinux = settings['rdplinux']

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

opts.on("-a [cpldrh]", "--action", String, "Connect, Ping, List, Dump, Regex or cHeck ports") { |v| options.action = v}
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
#raise OptionParser::MissingArgument, "Action [-a]" if options.action?nil
#raise OptionParser::MissingArgument, "Servers [-s]" if options.server?nil
#raise OptionParser::MissingArgument, "Environment [-e]" if options.envs?

help = opts.help

#pp options

if options.type == "ssh" then
    sshcom = winssh if OS.windows?
    sshcom = linuxssh if OS.linux?
else
    sshcom = rdpwin if OS.windows?
    sshcom = rdplinux if OS.linux?
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
        searchServer(pattern,myhash,options,envs,sshcom)
    else
        puts "Incorrect search pattern #{pattern.to_s}"
        puts help
    end
when "c","p","l","connect","ping","list"
    #Connect, Ping or list details
    action = options.action

    multiKeys = Flatten.new(options.server)
    multiEnv = Flatten.new(options.envs)
    if multiEnv.thinArray.size != 0 and multiKeys.thinArray.size !=0 then
        multiKeys.thinArray.each { |key|
            multiEnv.thinArray.each { |env|
                myIP = GenIP.new(myhash,envs,key,env)
                if myIP.valid then
                    Action.new(action,myIP.ip,options.user,sshcom,env,key,options.type)
                else
                    puts "Key '#{key}' or environment '#{env}' not found, searching..."
                    searchServer(key,myhash,options,envs,sshcom)
                end
            }
        }
    else
        if validIP(multiKeys.thinArray[0]) then
            Action.new(action,multiKeys.thinArray[0],options.user,sshcom,'dev',multiKeys.thinArray[0],options.type)
        else
            puts "Error: you must pass both server and environment options"
            puts help
        end
    end
when "f", "file"
    connections = YAML::load_file(options.file)
    servers = connections["servers"].inject(:merge)
    servers.each { |key,value|
        myIP = GenIP.new(myhash,envs,key,value)
        if myIP.valid then
            Action.new(connections["action"],myIP.ip,options.user,sshcom,value,key,options.type)
        else
            puts "Key '#{key}' or environment '#{value}' not found"
        end
    }
else
    puts help
end
