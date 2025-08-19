# lib/tasks/production_setup.rake - 本番環境移行用タスク

namespace :production do
  desc "本番環境のセットアップ"
  task setup: :environment do
    puts "🚀 本番環境セットアップを開始します..."
    
    # 環境変数の確認
    check_environment_variables
    
    # データベースの確認
    check_database
    
    # アセットのプリコンパイル
    precompile_assets
    
    # LINEリッチメニューの設定
    setup_line_richmenu
    
    puts "✅ 本番環境セットアップが完了しました！"
  end

  desc "環境変数の確認"
  task check_env: :environment do
    check_environment_variables
  end

  desc "データベースの確認"
  task check_db: :environment do
    check_database
  end

  desc "アセットのプリコンパイル"
  task assets: :environment do
    precompile_assets
  end

  desc "LINEリッチメニューの設定"
  task line_menu: :environment do
    setup_line_richmenu
  end

  private

  def check_environment_variables
    puts "🔧 環境変数の確認中..."
    
    required_vars = [
      'RAILS_MASTER_KEY',
      'DATABASE_URL',
      'GMAIL_USERNAME',
      'GMAIL_APP_PASSWORD',
      'LINE_CHANNEL_SECRET',
      'LINE_CHANNEL_TOKEN'
    ]
    
    missing_vars = []
    
    required_vars.each do |var|
      if ENV[var].blank?
        missing_vars << var
        puts "❌ #{var}: 未設定"
      else
        puts "✅ #{var}: 設定済み"
      end
    end
    
    if missing_vars.any?
      puts "⚠️ 以下の環境変数が設定されていません: #{missing_vars.join(', ')}"
      puts "config/production.env.example を参考に設定してください"
    else
      puts "✅ すべての必須環境変数が設定されています"
    end
  end

  def check_database
    puts "🗄️ データベースの確認中..."
    
    begin
      # データベース接続テスト
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ データベース接続成功"
      
      # テーブルの確認
      tables = ActiveRecord::Base.connection.tables
      puts "✅ テーブル数: #{tables.count}"
      
      # 重要なテーブルの確認
      important_tables = ['users', 'reservations', 'tickets', 'notification_preferences']
      missing_tables = important_tables - tables
      
      if missing_tables.any?
        puts "⚠️ 以下のテーブルが存在しません: #{missing_tables.join(', ')}"
        puts "マイグレーションを実行してください: rails db:migrate"
      else
        puts "✅ 重要なテーブルがすべて存在します"
      end
      
    rescue => e
      puts "❌ データベース接続エラー: #{e.message}"
      puts "データベース設定を確認してください"
    end
  end

  def precompile_assets
    puts "🎨 アセットのプリコンパイル中..."
    
    begin
      # アセットのプリコンパイル
      Rake::Task['assets:precompile'].invoke
      puts "✅ アセットのプリコンパイルが完了しました"
    rescue => e
      puts "❌ アセットプリコンパイルエラー: #{e.message}"
    end
  end

  def setup_line_richmenu
    puts "📱 LINEリッチメニューの設定中..."
    
    begin
      # LINEリッチメニューの設定
      if defined?(LineRichMenuSetup)
        LineRichMenuSetup.setup_main_menu
        puts "✅ LINEリッチメニューの設定が完了しました"
      else
        puts "⚠️ LineRichMenuSetupクラスが見つかりません"
      end
    rescue => e
      puts "❌ LINEリッチメニュー設定エラー: #{e.message}"
      puts "環境変数 LINE_CHANNEL_TOKEN が正しく設定されているか確認してください"
    end
  end
end
