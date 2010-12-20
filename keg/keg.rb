# delete is writing a special tombstone value

require 'zlib'

class Keg

  def initialize(directory)
    Thread.current[:keg] ||= {}
    @directory = File.expand_path(directory)
    @file = File.join(@directory, "foo.keg.data")
  end

  def get(key)
    if value = Thread.current[:keg][key]
      file, data_length, data_position, data_timestamp = value
      data = IO.read(file, data_length, data_position)
      # file => [crc, 32 bit int timestamp, key length, value length, key, value]
      crc, timestamp, key_length, value_length = data.unpack('IIII')
      if crc != Zlib::crc32(data[4..-1])
        raise 'crc mismatch'
      end
      key_start = 16
      key_end = key_start + key_length
      key = data[key_start...key_end]
      value_start = key_end
      value_end = value_start + value_length
      value = data[value_start...value_end]
    else
      nil
    end
  end

  def put(key, value)
    # force encoding to make sure lengths
    for thing in [key, value]
      if thing.respond_to?(:force_encoding)
        thing.force_encoding('BINARY')
      end
    end

    file = File.new(@file, 'a')
    file.flock(File::LOCK_EX)
    data_start = file.pos
    data_timestamp = Time.now
    # file => [crc, 32 bit int timestamp, key length, value length, key, value]
    file_data = [data_timestamp.to_i, key.length, value.length].pack('III')
    file_data << key
    file_data << value
    file_data = [Zlib::crc32(file_data)].pack('I') << file_data
    if file_data.respond_to?(:force_encoding)
      file_data.force_encoding('BINARY')
    end
    file.write(file_data)
    data_end = file.pos
    file.flock(File::LOCK_UN)
    file.close

    # memory => { key => [file id, value length, value position, timestamp]
    data_length = data_end - data_start
    memory_data = [@file, data_length, data_start, data_timestamp]
    # ? also write hint file
    Thread.current[:keg][key] = memory_data
  end

end

if __FILE__ == $0
  keg = Keg.new(File.expand_path('~/keg'))
  p keg.put('foo', 'bar')
  p keg.get('foo')
end