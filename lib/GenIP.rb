#
# GenIP, lookup an IP address based on passed hashs and keys
# Alastair Montgomery 2014
#

require 'resolv'

class GenIP
    attr_reader :ip, :valid
    def initialize(myhash,envs,key,env)
        @ip = ""
        @valid = false
        if (key =~ Resolv::IPv4::Regex) then
            #We got passed an IP address just return that
            @ip = key
            @valid = true
        else
            #Generate required IP for passed key and environment
            if myhash.has_key?(key) and envs.has_key?(env) then
                ipRaw =myhash[key]
                @ip = ipRaw.gsub("xxx",envs[env].to_s)
                @valid = true
            end
        end
    end
end
