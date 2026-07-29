class Flatten
  attr_reader :thin_array, :orig_array

  def initialize(fat_array)
    @orig_array = fat_array
    @thin_array = fat_array.flat_map { |d| d.split(',') }
  end
end

