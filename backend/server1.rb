require 'socket'

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
  STDERR.puts http_request
  socket.close
end