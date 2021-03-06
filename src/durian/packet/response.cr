module Durian::Packet
  class Response
    property protocol : Protocol
    property queries : Array(Section::Question)
    property answers : Array(Section::Answer)
    property authority : Array(Section::Authority)
    property additional : Array(Section::Additional)
    property transId : UInt16?
    property operationCode : OperationCode
    property responseCode : ResponseCode
    property authoritativeAnswer : AuthoritativeAnswer
    property truncated : Truncated
    property recursionDesired : RecursionDesired
    property recursionAvailable : RecursionAvailable
    property authenticatedData : AuthenticatedData
    property checkingDisabled : CheckingDisabled
    property questionCount : UInt16
    property answerCount : UInt16
    property authorityCount : UInt16
    property additionalCount : UInt16
    property buffer : IO::Memory?
    property random : Random

    def initialize(@protocol : Protocol = Protocol::UDP)
      @queries = [] of Section::Question
      @answers = [] of Section::Answer
      @authority = [] of Section::Authority
      @additional = [] of Section::Additional
      @transId = nil
      @operationCode = OperationCode::StandardQuery
      @responseCode = ResponseCode::NoError
      @authoritativeAnswer = AuthoritativeAnswer::False
      @truncated = Truncated::False
      @recursionDesired = RecursionDesired::False
      @recursionAvailable = RecursionAvailable::False
      @authenticatedData = AuthenticatedData::False
      @checkingDisabled = CheckingDisabled::False
      @questionCount = 0_u16
      @answerCount = 0_u16
      @authorityCount = 0_u16
      @additionalCount = 0_u16
      @buffer = nil
      @random = Random.new
    end

    private def self.parse_flags_count!(response : Response, io, buffer : IO)
      static_bits = ByteFormat.extract_uint16_bits io, buffer
      bits_io = IO::Memory.new static_bits.to_slice

      qr_flags = bits_io.read_byte || 0_u8
      raise MalformedPacket.new "Non-response Packet" if qr_flags != 1_i32

      operation_code = ByteFormat.parse_four_bit_integer bits_io
      authoritative_answer = bits_io.read_byte || 0_u8
      truncated = bits_io.read_byte || 0_u8
      recursion_desired = bits_io.read_byte || 0_u8
      recursion_available = bits_io.read_byte || 0_u8
      zero = bits_io.read_byte || 0_u8
      authenticated_data = bits_io.read_byte || 0_u8
      checking_disabled = bits_io.read_byte || 0_u8
      response_code = ByteFormat.parse_four_bit_integer bits_io

      response.operationCode = OperationCode.new operation_code
      response.authoritativeAnswer = AuthoritativeAnswer.new authoritative_answer.to_i32
      response.truncated = Truncated.new truncated.to_i32
      response.recursionDesired = RecursionDesired.new recursion_desired.to_i32
      response.recursionAvailable = RecursionAvailable.new recursion_available.to_i32
      response.authenticatedData = AuthenticatedData.new authenticated_data.to_i32
      response.checkingDisabled = CheckingDisabled.new checking_disabled.to_i32
      response.responseCode = ResponseCode.new response_code

      response.questionCount = io.read_bytes UInt16, IO::ByteFormat::BigEndian
      response.answerCount = io.read_bytes UInt16, IO::ByteFormat::BigEndian
      response.authorityCount = io.read_bytes UInt16, IO::ByteFormat::BigEndian
      response.additionalCount = io.read_bytes UInt16, IO::ByteFormat::BigEndian

      buffer.write_bytes response.questionCount, IO::ByteFormat::BigEndian
      buffer.write_bytes response.answerCount, IO::ByteFormat::BigEndian
      buffer.write_bytes response.authorityCount, IO::ByteFormat::BigEndian
      buffer.write_bytes response.additionalCount, IO::ByteFormat::BigEndian
    end

    def self.from_io(io : IO, protocol : Protocol = Protocol::UDP,
                     buffer : IO::Memory = IO::Memory.new, sync_buffer_close : Bool = true)
      from_io! io, protocol, buffer, sync_buffer_close rescue nil
    end

    def self.from_io!(io : IO, protocol : Protocol = Protocol::UDP,
                      buffer : IO::Memory = IO::Memory.new, sync_buffer_close : Bool = true)
      response = new
      response.protocol = protocol
      bad_decode = false

      begin
        length = io.read_bytes UInt16, IO::ByteFormat::BigEndian if protocol.tcp?
        trans_id = io.read_bytes UInt16, IO::ByteFormat::BigEndian

        buffer.write_bytes trans_id, IO::ByteFormat::BigEndian
      rescue ex
        raise MalformedPacket.new ex.message
      end

      response.transId = trans_id
      parse_flags_count! response, io, buffer

      response.questionCount.times do
        break if bad_decode

        response.queries << Section::Question.decode io, buffer rescue bad_decode = true
      end

      response.answerCount.times do
        break if bad_decode

        response.answers << Section::Answer.decode io, buffer rescue bad_decode = true
      end

      response.authorityCount.times do
        break if bad_decode

        response.authority << Section::Authority.decode io, buffer rescue bad_decode = true
      end

      response.additionalCount.times do
        break if bad_decode

        response.additional << Section::Additional.decode io, buffer rescue bad_decode = true
      end

      buffer.close if sync_buffer_close
      response.buffer = buffer unless sync_buffer_close
      response
    end
  end
end
