# lib/services/line_richmenu_setup.rb

require 'net/http'
require 'uri'
require 'json'

ACCESS_TOKEN = ENV['LINE_CHANNEL_TOKEN']

def create_richmenu
  uri = URI.parse("https://api.line.me/v2/bot/richmenu")

  header = {
    "Content-Type": "application/json",
    "Authorization": "Bearer #{ACCESS_TOKEN}"
  }

  body = {
    size: { width: 2500, height: 1686 },
    selected: true,
    name: "MobilisMenu",
    chatBarText: "メニューを開く",
    areas: [
      { bounds: { x: 0,    y: 0,    width: 833, height: 843 }, action: { type: "postback", data: "booking" } },
      { bounds: { x: 834,  y: 0,    width: 833, height: 843 }, action: { type: "uri", uri: "https://mobilis-stretch.com/" } },
      { bounds: { x: 1667, y: 0,    width: 833, height: 843 }, action: { type: "postback", data: "news" } },
      { bounds: { x: 0,    y: 843,  width: 833, height: 843 }, action: { type: "postback", data: "reviews" } },
      { bounds: { x: 834,  y: 843,  width: 833, height: 843 }, action: { type: "postback", data: "check_tickets" } },
      { bounds: { x: 1667, y: 843,  width: 833, height: 843 }, action: { type: "postback", data: "usage_history" } }
    ]
  }

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = body.to_json

  response = http.request(request)
  puts "[🎉] リッチメニュー作成成功: #{response.body}"
end

create_richmenu
