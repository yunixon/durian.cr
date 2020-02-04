require "../src/durian.cr"

servers = [] of Tuple(Socket::IPAddress, Durian::Protocol)
servers << Tuple.new Socket::IPAddress.new("8.8.8.8", 53_i32), Durian::Protocol::UDP
servers << Tuple.new Socket::IPAddress.new("1.1.1.1", 53_i32), Durian::Protocol::UDP

buffer = uninitialized UInt8[4096_i32]

resolver = Durian::Resolver.new servers
resolver.ip_cache = Durian::Resolver::Cache::IPAddress.new

begin
  socket = Durian::TCPSocket.connect "www.example.com", 80_i32, resolver, 5_i32
  socket.read_timeout = 5_i32
  socket.write_timeout = 5_i32
rescue
  abort "Connect Failed"
end

begin
  socket << "GET / HTTP/1.1\r\nHost: www.example.com\r\nConnection: close\r\n\r\n"
rescue
  abort "Write Failed"
end

begin
  length = socket.read buffer.to_slice
rescue
  abort "Read Failed"
end

puts [length, String.new buffer.to_slice[0_i32, length]]
