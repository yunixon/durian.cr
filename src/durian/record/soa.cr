class Durian::Record::SOA < Durian::Record
  property primaryNameServer : String
  property authorityMailBox : String
  property serialNumber : UInt32
  property refreshInterval : UInt32
  property retryInterval : UInt32
  property expireLimit : UInt32
  property minimiumTimeToLive : UInt32

  def initialize(@primaryNameServer : String = String.new, @cls : Cls = Cls::IN, @ttl : UInt32 = 0_u32, @from : String? = nil)
    @authorityMailBox = String.new
    @serialNumber = 0_u32
    @refreshInterval = 0_u32
    @retryInterval = 0_u32
    @expireLimit = 0_u32
    @minimiumTimeToLive = 0_u32
  end

  {% for name in ["authority", "answer", "additional"] %}
  def self.{{name.id}}_from_io?(resource_record : SOA, io : IO, buffer : IO, maximum_length : Int32 = 512_i32)
    data_length = io.read_network_short
    buffer.write_network_short data_length

    data_buffer = Durian.limit_length_buffer io, data_length

    begin
      IO.copy data_buffer, buffer ensure data_buffer.rewind

      resource_record.primaryNameServer = Durian.decode_address data_buffer, buffer
      resource_record.authorityMailBox = Durian.decode_address data_buffer, buffer

      resource_record.serialNumber = data_buffer.read_network_long
      resource_record.refreshInterval = data_buffer.read_network_long
      resource_record.retryInterval = data_buffer.read_network_long
      resource_record.expireLimit = data_buffer.read_network_long
      resource_record.minimiumTimeToLive = data_buffer.read_network_long

      buffer.write_network_long resource_record.serialNumber
      buffer.write_network_long resource_record.refreshInterval
      buffer.write_network_long resource_record.retryInterval
      buffer.write_network_long resource_record.expireLimit
      buffer.write_network_long resource_record.minimiumTimeToLive
    rescue ex
      data_buffer.close ensure raise ex
    end

    data_buffer.close
  end
  {% end %}

  def self.address_from_io?(io : IO, length : Int, buffer : IO, maximum_length : Int32 = 512_i32)
    Durian.parse_strict_length_address io, length, buffer, recursive_depth: 0_i32, maximum_length: maximum_length
  end

  def self.address_from_io?(io : IO, buffer : IO, maximum_length : Int32 = 512_i32)
    Durian.parse_chunk_address io, buffer, recursive_depth: 0_i32, maximum_length: maximum_length
  end

  def address_from_io?(io : IO, buffer : IO, maximum_length : Int32 = 512_i32)
    SOA.address_from_io? io, buffer, recursive_depth: 0_i32, maximum_length: maximum_length
  end

  def address_from_io?(io : IO, length : Int, buffer : IO, maximum_length : Int32 = 512_i32)
    SOA.address_from_io? io, length, buffer, recursive_depth: 0_i32, maximum_length: maximum_length
  end
end