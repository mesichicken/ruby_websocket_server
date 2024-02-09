
require 'socket'
require 'digest/sha1'

server = TCPServer.new('localhost', 2345)

loop do
  # 接続を待機
  socket = server.accept
  STDERR.puts "リクエストが来ました！"

  # HTTPリクエストを読み込む。\r\nの行によって終了を検知する
  http_request = ""
  while (line = socket.gets) && (line != "\r\n")
    http_request += line
  end

  if matches = http_request.match(/^Sec-WebSocket-Key: (\S+)/)
    websocket_key = matches[1]
    STDERR.puts "Websocket handshake detected with key: #{ websocket_key }"
  else
    STDERR.puts "Aborting non-websocket connection"
    socket.close
    next
  end

  response_key = Digest::SHA1.base64digest([websocket_key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"].join)
  STDERR.puts "Responding to handshake with key: #{ response_key }"

  handshake_response = [
    "HTTP/1.1 101 Switching Protocols",
    "Upgrade: websocket",
    "Connection: Upgrade",
    "Sec-WebSocket-Accept: #{response_key}",
    "\r\n"
  ].join("\r\n")

  socket.write(handshake_response)

  STDERR.puts "Handshake completed. Starting to parse the websocket frame."

  first_byte = socket.getbyte
  fin = first_byte & 0b10000000
  opcode = first_byte & 0b00001111

  raise "このサーバーは複数フレームには非対応です" unless fin
  raise "このサーバーではopcode 1(テキスト)のみに対応してます" unless opcode == 1

  second_byte = socket.getbyte
  is_masked = second_byte & 0b10000000
  payload_size = second_byte & 0b01111111

  raise "サーバーに送信されるすべてのフレームは、WebSocketの仕様に従ってマスクされる必要があります" unless is_masked
  raise "ペイロードの長さは126バイト未満のみサポートします" unless payload_size < 126

  STDERR.puts "Payload size: #{ payload_size } bytes"

  mask = 4.times.map { socket.getbyte }
  STDERR.puts "Got mask: #{ mask.inspect }"

  data = payload_size.times.map { socket.getbyte }
  STDERR.puts "Got masked data: #{ data.inspect }"

  unmasked_data = data.each_with_index.map { |byte, i| byte ^ mask[i % 4] }
  STDERR.puts "Unmasked the data: #{ unmasked_data.inspect }"

  STDERR.puts "Converted to a string: #{ unmasked_data.pack('C*').force_encoding('utf-8').inspect }"


  response = "Loud and clear!"
  STDERR.puts "Sending response: #{ response.inspect }"

  output = [0b10000001, response.size, response]

  socket.write output.pack("CCA#{ response.size }")

  socket.close
end
