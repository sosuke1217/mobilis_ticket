class AddIndividualIntervalToReservations < ActiveRecord::Migration[7.2]
  def change
    add_column :reservations, :individual_interval_minutes, :integer, null: true
    
    # インデックスを追加（検索性能向上）
    add_index :reservations, :individual_interval_minutes
    
    # 既存のデータには null を設定（システムデフォルトを使用）
    # up migration で既存レコードの値を設定する場合：
    reversible do |dir|
      dir.up do
        # 既存の予約にはデフォルト値を設定しない（nullのままでシステム設定を使用）
        Rails.logger.info "✅ Added individual_interval_minutes column to reservations"
      end
      
      dir.down do
        Rails.logger.info "⬇️ Removing individual_interval_minutes column from reservations"
      end
    end
  end
end