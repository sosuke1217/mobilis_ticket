# lib/services/line_richmenu_setup.rb の改善版

require 'net/http'
require 'uri'
require 'json'

class LineRichMenuSetup
  ACCESS_TOKEN = ENV['LINE_CHANNEL_TOKEN']
  
  def self.setup_main_menu
    # 既存のリッチメニューを削除
    delete_all_richmenus
    
    # メインメニューを作成
    richmenu_id = create_main_richmenu
    
    # デフォルトリッチメニューとして設定
    set_default_richmenu(richmenu_id)
    
    puts "✅ メインリッチメニュー設定完了: #{richmenu_id}"
    richmenu_id
  end
  
  def self.create_main_richmenu
    uri = URI.parse("https://api.line.me/v2/bot/richmenu")
    
    richmenu_data = {
      size: { width: 2500, height: 1686 },
      selected: true,
      name: "MobilisMainMenu",
      chatBarText: "メニューを開く",
      areas: [
        # 上段左：予約
        { 
          bounds: { x: 0, y: 0, width: 833, height: 843 }, 
          action: { type: "postback", data: "booking" } 
        },
        # 上段中央：ホームページ
        { 
          bounds: { x: 834, y: 0, width: 833, height: 843 }, 
          action: { type: "uri", uri: ENV['app_host'] || "https://mobilis-stretch.com" } 
        },
        # 上段右：最新情報
        { 
          bounds: { x: 1667, y: 0, width: 833, height: 843 }, 
          action: { type: "postback", data: "news" } 
        },
        # 下段左：口コミ
        { 
          bounds: { x: 0, y: 843, width: 833, height: 843 }, 
          action: { type: "postback", data: "reviews" } 
        },
        # 下段中央：チケット確認
        { 
          bounds: { x: 834, y: 843, width: 833, height: 843 }, 
          action: { type: "postback", data: "check_tickets" } 
        },
        # 下段右：履歴
        { 
          bounds: { x: 1667, y: 843, width: 833, height: 843 }, 
          action: { type: "postback", data: "usage_history" } 
        }
      ]
    }
    
    response = send_request(uri, richmenu_data.to_json)
    result = JSON.parse(response.body)
    
    if response.code == '200'
      puts "✅ リッチメニュー作成成功: #{result['richMenuId']}"
      result['richMenuId']
    else
      puts "❌ リッチメニュー作成失敗: #{response.body}"
      nil
    end
  end
  
  def self.delete_all_richmenus
    uri = URI.parse("https://api.line.me/v2/bot/richmenu/list")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{ACCESS_TOKEN}"
    
    response = http.request(request)
    result = JSON.parse(response.body)
    
    if result['richmenus']
      result['richmenus'].each do |richmenu|
        delete_richmenu(richmenu['richMenuId'])
      end
    end
  end
  
  def self.delete_richmenu(richmenu_id)
    uri = URI.parse("https://api.line.me/v2/bot/richmenu/#{richmenu_id}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Delete.new(uri.request_uri)
    request['Authorization'] = "Bearer #{ACCESS_TOKEN}"
    
    response = http.request(request)
    puts "🗑️ リッチメニュー削除: #{richmenu_id} (#{response.code})"
  end
  
  def self.set_default_richmenu(richmenu_id)
    uri = URI.parse("https://api.line.me/v2/bot/user/all/richmenu/#{richmenu_id}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{ACCESS_TOKEN}"
    
    response = http.request(request)
    
    if response.code == '200'
      puts "✅ デフォルトリッチメニュー設定完了"
    else
      puts "❌ デフォルトリッチメニュー設定失敗: #{response.body}"
    end
  end
  
  # 🆕 ユーザー固有のリッチメニュー設定
  def self.set_user_richmenu(user_id, richmenu_id)
    uri = URI.parse("https://api.line.me/v2/bot/user/#{user_id}/richmenu/#{richmenu_id}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{ACCESS_TOKEN}"
    
    response = http.request(request)
    
    if response.code == '200'
      puts "✅ ユーザー#{user_id}のリッチメニュー設定完了"
    else
      puts "❌ ユーザー#{user_id}のリッチメニュー設定失敗: #{response.body}"
    end
  end
  
  private
  
  def self.send_request(uri, body)
    header = {
      "Content-Type": "application/json",
      "Authorization": "Bearer #{ACCESS_TOKEN}"
    }
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = body
    
    http.request(request)
  end
end

# 実行用スクリプト
if __FILE__ == $0
  puts "🔧 LINEリッチメニュー設定を開始します..."
  puts "📱 アクセストークン: #{ENV['LINE_CHANNEL_TOKEN'] ? '設定済み' : '未設定'}"
  puts "🔑 トークンの値: #{ENV['LINE_CHANNEL_TOKEN']}"
  puts "🔑 トークンの長さ: #{ENV['LINE_CHANNEL_TOKEN']&.length || 0}"
  
  if ENV['LINE_CHANNEL_TOKEN'].nil?
    puts "❌ LINE_CHANNEL_TOKENが設定されていません"
    exit 1
  end
  
  LineRichMenuSetup.setup_main_menu
end
