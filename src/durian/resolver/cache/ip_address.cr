class Durian::Resolver
  class Cache::IPAddress
    property collects : Hash(String, Item)
    property maximumSave : Int32
    property cleanInterval : Time::Span
    property recordExpires : Time::Span
    property cleanAt : Time

    def initialize(@collects = Hash(String, Item).new, @maximumSave : Int32 = 256_i32,
                   @cleanInterval : Time::Span = 3600_i32.seconds, @recordExpires : Time::Span = 3600_i32.seconds)
      @cleanAt = Time.local
    end

    def insert(name : String, ip_address : Array(Socket::IPAddress))
      collects[name] = Item.new ip_address
    end

    def refresh
      @cleanAt = Time.local
    end

    def full?
      size == maximumSave
    end

    def clean_expires?
      (Time.local - cleanAt) > cleanInterval
    end

    def reset
      collects.clear
    end

    def []=(name, value : RecordKind)
      collects[name] = value
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

    def expires?(name : String)
      return unless item = collects[name]?

      (Time.local - item.accessAt) > recordExpires
    end

    def get(name : String, port : Int32) : Array(Socket::IPAddress)?
      return unless item = collects[name]?

      item.refresh ensure item.tap

      address = [] of Socket::IPAddress

      item.ipAddress.each do |ip_address|
        address << Socket::IPAddress.new ip_address.address, port
      end

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
      inactive_clean

      insert name, ip_address unless item = collects[name]?
      return unless item = collects[name]?

      item.ipAddress = ip_address
    end

    def maximum_clean=(value : Int32)
      @maximumClean = value
    end

    def maximum_clean
      @maximumClean || default_maximum_clean
    end

    def default_maximum_clean
      maximumSave / 2_i32
    end

    def size
      collects.size
    end

    def empty?
      collects.empty?
    end

    def inactive_clean
      case {full?, clean_expires?}
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
      	_collects = [] of Tuple(Time, String)
      {% elsif name.id == "tap" %}
      	_collects = [] of Tuple(Int32, String)
      {% end %}

      _maximum_clean = maximum_clean - 1_i32

      collects.each do |name, item|
      	{% if name.id == "access_at" %}
          _collects << Tuple.new item.accessAt, name
      	{% elsif name.id == "tap" %}
      	  _collects << Tuple.new item.tapCount, name
      	{% end %}
      end

      _sort = _collects.sort do |x, y|
        x.first <=> y.first
      end

      _sort.each_with_index do |sort, index|
        break if index > _maximum_clean
        collects.delete sort.last
      end

      _collects.clear ensure _sort.clear
    end
    {% end %}

    class Item
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