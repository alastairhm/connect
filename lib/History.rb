#Alastair Montgomery 2016

require 'yaml'
require 'resolv'
require 'pp'

class History
    attr_reader :history, :file, :size
    def initialize(filename,size)
        @history = Array.new()
        @file = File.expand_path(File.join(File.dirname(__FILE__), filename))
        @history = YAML::load_file(@file)
        if size > 0 && size != nil then
            @size = size
	else
	    @size = 10
	end
    end

    def pop()
	@history.pop()
    end

    def push(details)
	@history.push(details)
        length = @history.length()
	if length > @size then
            @history = @history.slice(length-@size,length)
	end
        @history = @history.uniq
        File.open(@file,'w') do |f2|
            f2.puts @history.to_yaml
        end
     end

     def dump()
       Resolv::DNS.open() do |r|
         @history.each do |item|
             puts item, r.getname(item) 
         end
       end
     end
end

