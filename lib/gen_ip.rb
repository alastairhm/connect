# GenIP: lookup an IP address based on passed hashes and keys
# Alastair Montgomery 2014 (refactored)

require 'resolv'

class GenIP
  attr_reader :ip, :valid

  def initialize(myhash, envs, key, env)
    @ip, @valid = resolve_ip(myhash, envs, key, env)
  end

  private

  def resolve_ip(myhash, envs, key, env)
    if key.match?(Resolv::IPv4::Regex)
      [key, true]
    elsif myhash.key?(key) && envs.key?(env)
      ip_raw = myhash[key]["ip"]
      [ip_raw.gsub("xxx", envs[env].to_s), true]
    else
      ["", false]
    end
  end
end

