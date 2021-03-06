module Durian
  class Cache::IPAddress
    property collects : Immutable::Map(String, Entry)
    property capacity : Int32
    property cleanInterval : Time::Span
    property recordExpires : Time::Span
    property cleanAt : Time
    property maximumCleanup : Int32

    def initialize(@collects : Immutable::Map(String, Entry) = Immutable::Map(String, Entry).new, @capacity : Int32 = 256_i32,
                   @cleanInterval : Time::Span = 3600_i32.seconds, @recordExpires : Time::Span = 1800_i32.seconds)
      @cleanAt = Time.local
      @maximumCleanup = (capacity / 2_i32).to_i32
    end

    def insert(name : String, ip_address : Array(Socket::IPAddress))
      insert = collects.set name, Entry.new ip_address
      @collects = insert
    end

    def refresh
      @cleanAt = Time.local
    end

    def full?
      capacity <= size
    end

    def clean_expired?
      (Time.local - cleanAt) > cleanInterval
    end

    def reset
      @collects = collects.clear
    end

    def []=(name, value : Socket::IPAddress)
      set name, value
    end

    def []=(name, value : Array(Socket::IPAddress))
      set name, value
    end

    def [](name : String)
      value = collects[name]

      if value
        value.refresh
        value.tap
      end

      value
    end

    def []?(name : String)
      value = collects[name]?

      if value
        value.refresh
        value.tap
      end

      value
    end

    def expired?(name : String)
      return unless item = collects[name]?
      return true if item.ipAddress.empty?

      (Time.local - item.accessAt) > recordExpires
    end

    def get(name : String, port : Int32) : Array(Socket::IPAddress)?
      return unless item = collects[name]?

      item.refresh ensure item.tap
      address = [] of Socket::IPAddress

      item.ipAddress.each do |ip_address|
        address << Socket::IPAddress.new ip_address.address, port
      end

      return if address.empty?
      address
    end

    def get(name : String) : Array(Socket::IPAddress)?
      return unless item = collects[name]?

      item.refresh ensure item.tap
      item.ipAddress
    end

    def set(name : String, ip_address : Socket::IPAddress)
      set name, [ip_address]
    end

    def set(name : String, ip_address : Array(Socket::IPAddress))
      return if ip_address.empty?
      inactive_clean

      insert name, ip_address unless item = collects[name]?
      return unless item = collects[name]?

      item.ipAddress = ip_address
      item.refresh
    end

    def size
      collects.size
    end

    def empty?
      collects.empty?
    end

    def inactive_clean
      case {full?, clean_expired?}
      when {true, false}
        clean_by_tap
        refresh
      when {true, true}
        clean_by_access_at
        refresh
      end
    end

    {% for name in ["tap", "access_at"] %}
    private def clean_by_{{name.id}}
      {% if name.id == "access_at" %}
      	temporary = [] of Tuple(Time, String)
      {% elsif name.id == "tap" %}
      	temporary = [] of Tuple(Int32, String)
      {% end %}

      _maximum = maximumCleanup - 1_i32
      _collects = collects

      _collects.each do |name, item|
      	{% if name.id == "access_at" %}
          temporary << Tuple.new item.accessAt, name
      	{% elsif name.id == "tap" %}
      	  temporary << Tuple.new item.tapCount, name
      	{% end %}
      end

      _sort = temporary.sort do |x, y|
        x.first <=> y.first
      end

      _sort.each_with_index do |sort, index|
        break if index > _maximum
        _collects = _collects.delete sort.last
      end

      @collects = _collects
      temporary.clear ensure _sort.clear
    end
    {% end %}

    class Entry
      property ipAddress : Array(Socket::IPAddress)
      property accessAt : Time
      property tapCount : Int32

      def initialize(@ipAddress : Array(Socket::IPAddress))
        @accessAt = Time.local
        @tapCount = 0_i32
      end

      def tap
        @tapCount = tapCount + 1_i32
      end

      def refresh
        @accessAt = Time.local
      end
    end
  end
end
