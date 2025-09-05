# lib/tasks/google_business_setup.rake

namespace :google_business do
  desc "Googleビジネスプロフィールの設定を確認"
  task check_setup: :environment do
    puts "🔍 Googleビジネスプロフィール設定確認"
    puts "=" * 50
    
    # 環境変数の確認
    review_url = ENV['GOOGLE_REVIEW_URL']
    business_url = ENV['GOOGLE_BUSINESS_URL']
    
    puts "📝 Googleレビュー投稿URL: #{review_url || '未設定'}"
    puts "🏢 GoogleビジネスプロフィールURL: #{business_url || '未設定'}"
    
    if review_url.nil? || business_url.nil?
      puts "\n⚠️  環境変数が設定されていません"
      puts "以下の環境変数を設定してください："
      puts "GOOGLE_REVIEW_URL=https://search.google.com/local/writereview?placeid=YOUR_PLACE_ID"
      puts "GOOGLE_BUSINESS_URL=https://www.google.com/maps/place/YOUR_BUSINESS_NAME"
      puts "\nまたは、Herokuで設定する場合："
      puts "heroku config:set GOOGLE_REVIEW_URL='https://search.google.com/local/writereview?placeid=YOUR_PLACE_ID'"
      puts "heroku config:set GOOGLE_BUSINESS_URL='https://www.google.com/maps/place/YOUR_BUSINESS_NAME'"
    else
      puts "\n✅ 環境変数が設定されています"
    end
    
    puts "\n📋 Googleビジネスプロフィール設定手順："
    puts "1. Googleビジネスプロフィールを作成"
    puts "2. 店舗名: Mobilis Stretch"
    puts "3. カテゴリ: ストレッチ・マッサージ"
    puts "4. サービスエリア: 出張サービス"
    puts "5. Place IDを取得して環境変数に設定"
  end
  
  desc "GoogleビジネスプロフィールのURLを生成"
  task generate_urls: :environment do
    puts "🔗 GoogleビジネスプロフィールURL生成"
    puts "=" * 50
    
    business_name = "Mobilis Stretch"
    encoded_name = URI.encode_www_form_component(business_name)
    
    puts "🏢 ビジネス名: #{business_name}"
    puts "🔗 Google検索URL: https://www.google.com/search?q=#{encoded_name}"
    puts "🗺️  GoogleマップURL: https://www.google.com/maps/search/#{encoded_name}"
    
    puts "\n📝 レビュー投稿用URL（Place IDが必要）:"
    puts "https://search.google.com/local/writereview?placeid=YOUR_PLACE_ID"
    
    puts "\n💡 Place IDの取得方法："
    puts "1. Googleビジネスプロフィールを作成"
    puts "2. Google Places APIを使用してPlace IDを取得"
    puts "3. または、GoogleビジネスプロフィールのURLからPlace IDを抽出"
  end
end
