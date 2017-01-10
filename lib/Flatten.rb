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

