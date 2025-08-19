# app/helpers/news_helper.rb - 最新情報ヘルパー

module NewsHelper
  # 最新情報を読み込む
  def load_news_items
    news_file = Rails.root.join('config', 'news_items.yml')
    
    if File.exist?(news_file)
      YAML.load_file(news_file)['news_items'] || []
    else
      # ファイルが存在しない場合はデフォルトデータを返す
      default_news_items
    end
  rescue => e
    Rails.logger.error "最新情報の読み込みエラー: #{e.message}"
    default_news_items
  end

  # カテゴリ情報を読み込む
  def load_categories
    news_file = Rails.root.join('config', 'news_items.yml')
    
    if File.exist?(news_file)
      YAML.load_file(news_file)['categories'] || []
    else
      # ファイルが存在しない場合はデフォルトカテゴリを返す
      default_categories
    end
  rescue => e
    Rails.logger.error "カテゴリ情報の読み込みエラー: #{e.message}"
    default_categories
  end

  # カテゴリ別の色を取得
  def get_category_color(category_name)
    categories = load_categories
    category = categories.find { |cat| cat['name'] == category_name }
    category&.dig('color') || '#FF6B35' # デフォルト色
  end

  # カテゴリ別のアイコンを取得
  def get_category_icon(category_name)
    categories = load_categories
    category = categories.find { |cat| cat['name'] == category_name }
    category&.dig('icon') || '📢' # デフォルトアイコン
  end

  private

  # デフォルトの最新情報
  def default_news_items
    [
      { 
        title: "🎉 新年のご挨拶", 
        content: "2024年も引き続き、皆様の健康とリラクゼーションをサポートさせていただきます。本年もよろしくお願いいたします。", 
        date: "2024/01/01",
        category: "お知らせ",
        priority: 1
      },
      { 
        title: "📅 年末年始営業時間のお知らせ", 
        content: "12月30日〜1月3日は休業とさせていただきます。1月4日より通常営業いたします。", 
        date: "2023/12/20",
        category: "営業時間",
        priority: 2
      }
    ]
  end

  # デフォルトのカテゴリ
  def default_categories
    [
      { name: "お知らせ", color: "#FF6B35", icon: "📢" },
      { name: "営業時間", color: "#4CAF50", icon: "🕒" },
      { name: "サービス", color: "#2196F3", icon: "🌟" }
    ]
  end
end
