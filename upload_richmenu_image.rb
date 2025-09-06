#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# LINE Channel Token
token = ENV['LINE_CHANNEL_TOKEN']
richmenu_id = "richmenu-5005d2bfa1c4ed08106e37fa2770c5da"

if token.nil?
  puts "❌ LINE_CHANNEL_TOKENが設定されていません"
  exit 1
end

puts "🖼️ リッチメニュー画像をアップロード中..."
puts "🔑 トークン: #{token[0..20]}..."
puts "📱 リッチメニューID: #{richmenu_id}"

# 画像ファイルのパス
image_path = "app/assets/images/mobilis_richmenu.png"

unless File.exist?(image_path)
  puts "❌ 画像ファイルが見つかりません: #{image_path}"
  exit 1
end

puts "📁 画像ファイル: #{image_path}"

# 画像をアップロード
uri = URI.parse("https://api-data.line.me/v2/bot/richmenu/#{richmenu_id}/content")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri.request_uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = "image/png"

# 画像ファイルを読み込み
image_data = File.read(image_path)
request.body = image_data

response = http.request(request)

puts "📊 レスポンスコード: #{response.code}"

if response.code == '200'
  puts "✅ 画像のアップロードが成功しました！"
  
  # リッチメニューをユーザーに適用
  puts "🔗 リッチメニューをユーザーに適用中..."
  
  apply_uri = URI.parse("https://api.line.me/v2/bot/user/all/richmenu/#{richmenu_id}")
  apply_http = Net::HTTP.new(apply_uri.host, apply_uri.port)
  apply_http.use_ssl = true
  
  apply_request = Net::HTTP::Post.new(apply_uri.request_uri)
  apply_request['Authorization'] = "Bearer #{token}"
  
  apply_response = apply_http.request(apply_request)
  
  if apply_response.code == '200'
    puts "✅ リッチメニューの適用が成功しました！"
    puts "🎉 完了！LINEアプリでリッチメニューが表示されるはずです。"
  else
    puts "❌ リッチメニューの適用に失敗しました: #{apply_response.code}"
    puts "📋 レスポンス: #{apply_response.body}"
  end
  
else
  puts "❌ 画像のアップロードに失敗しました: #{response.code}"
  puts "📋 レスポンス: #{response.body}"
end
