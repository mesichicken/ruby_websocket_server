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

  STDERR.puts "Handshake completed."

  socket.close
end
