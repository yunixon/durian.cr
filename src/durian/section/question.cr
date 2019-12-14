module Durian::Section
  class Question
    alias ResourceFlag = Record::ResourceFlag
    alias Cls = Record::Cls

    property flag : ResourceFlag
    property query : String
    property cls : Cls

    def initialize(@flag : ResourceFlag = ResourceFlag::ANY, @query : String = String.new, @cls : Cls = Cls::IN)
    end

    def encode(io : IO)
      encode flag, io
    end

    def encode(flag : ResourceFlag, io : IO)
      return unless _query = query

      Durian.encode_chunk_ipv4_address _query, io

      io.write_bytes flag.to_u16, IO::ByteFormat::BigEndian
      io.write_bytes cls.to_u16, IO::ByteFormat::BigEndian
    end

    def self.encode(flag : ResourceFlag, query : String, io : IO, cls : Cls = Cls::IN)
      question = new flag, query, cls
      question.encode io
    end

    def self.decode(io : IO, buffer : IO)
      query = Durian.parse_chunk_address io, buffer
      flag = io.read_bytes UInt16, IO::ByteFormat::BigEndian
      _cls = io.read_bytes UInt16, IO::ByteFormat::BigEndian

      question = new ResourceFlag.new flag.to_i32
      question.query = query
      question.cls = Cls.new _cls.to_i32

      buffer.write_bytes flag, IO::ByteFormat::BigEndian
      buffer.write_bytes _cls, IO::ByteFormat::BigEndian

      question
    end
  end
end
