# activerecord-session_store 用のセッションテーブル
# 本番でCookieベースのセッションが維持されない問題の対策
class CreateSessionsTable < ActiveRecord::Migration[7.2]
  def change
    create_table :sessions do |t|
      t.string :session_id, null: false
      t.text :data
      t.timestamps
    end

    add_index :sessions, :session_id, unique: true
    add_index :sessions, :updated_at
  end
end
