#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# LINE Channel Token
token = ENV['LINE_CHANNEL_TOKEN']

if token.nil?
  puts "❌ LINE_CHANNEL_TOKENが設定されていません"
  exit 1
end

puts "🔍 リッチメニュー一覧を確認中..."
puts "🔑 トークン: #{token[0..20]}..."

# リッチメニュー一覧を取得
uri = URI.parse("https://api.line.me/v2/bot/richmenu/list")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri.request_uri)
request['Authorization'] = "Bearer #{token}"

response = http.request(request)

puts "📊 レスポンスコード: #{response.code}"
puts "📋 レスポンスボディ: #{response.body}"

if response.code == '200'
  result = JSON.parse(response.body)
  
  if result['richmenus'] && result['richmenus'].any?
    puts "✅ リッチメニューが見つかりました:"
    result['richmenus'].each do |richmenu|
      puts "  - ID: #{richmenu['richMenuId']}"
      puts "    Name: #{richmenu['name']}"
      puts "    Status: #{richmenu['status']}"
      puts "    ---"
    end
  else
    puts "❌ リッチメニューが見つかりません"
  end
else
  puts "❌ API呼び出しに失敗しました"
end
