# lib/tasks/backup.rake

namespace :backup do
  desc "Create backup of reservation data"
  task reservations: :environment do
    puts "[#{Time.current}] 予約データバックアップ開始"
    
    backup_dir = Rails.root.join('backups')
    FileUtils.mkdir_p(backup_dir) unless Dir.exist?(backup_dir)
    
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = backup_dir.join("reservations_backup_#{timestamp}.json")
    
    # 過去1年間の予約データを取得
    reservations = Reservation.includes(:user, :ticket)
      .where('start_time > ?', 1.year.ago)
      .order(:start_time)
    
    backup_data = {
      created_at: Time.current.iso8601,
      version: "1.0",
      total_records: reservations.count,
      reservations: reservations.map do |reservation|
        {
          id: reservation.id,
          name: reservation.name,
          start_time: reservation.start_time&.iso8601,
          end_time: reservation.end_time&.iso8601,
          course: reservation.course,
          status: reservation.status,
          note: reservation.note,
          created_at: reservation.created_at.iso8601,
          updated_at: reservation.updated_at.iso8601,
          cancelled_at: reservation.cancelled_at&.iso8601,
          cancellation_reason: reservation.cancellation_reason,
          user: reservation.user ? {
            id: reservation.user.id,
            name: reservation.user.name,
            phone_number: reservation.user.phone_number,
            email: reservation.user.email,
            address: reservation.user.address
          } : nil,
          ticket: reservation.ticket ? {
            id: reservation.ticket.id,
            title: reservation.ticket.title,
            template_name: reservation.ticket.ticket_template&.name
          } : nil
        }
      end
    }
    
    File.write(backup_file, JSON.pretty_generate(backup_data))
    
    puts "✅ バックアップ完了: #{backup_file}"
    puts "📊 バックアップ件数: #{reservations.count}件"
    
    # 古いバックアップファイルを削除（30日以上前）
    cleanup_old_backups(backup_dir, 30)
  end
  
  desc "Create backup of ticket data"
  task tickets: :environment do
    puts "[#{Time.current}] チケットデータバックアップ開始"
    
    backup_dir = Rails.root.join('backups')
    FileUtils.mkdir_p(backup_dir) unless Dir.exist?(backup_dir)
    
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = backup_dir.join("tickets_backup_#{timestamp}.json")
    
    # 全チケットデータを取得
    tickets = Ticket.includes(:user, :ticket_template, :ticket_usages)
    
    backup_data = {
      created_at: Time.current.iso8601,
      version: "1.0",
      total_records: tickets.count,
      tickets: tickets.map do |ticket|
        {
          id: ticket.id,
          title: ticket.title,
          total_count: ticket.total_count,
          remaining_count: ticket.remaining_count,
          purchase_date: ticket.purchase_date&.iso8601,
          expiry_date: ticket.expiry_date&.iso8601,
          created_at: ticket.created_at.iso8601,
          user: {
            id: ticket.user.id,
            name: ticket.user.name,
            line_user_id: ticket.user.line_user_id
          },
          template: ticket.ticket_template ? {
            id: ticket.ticket_template.id,
            name: ticket.ticket_template.name,
            price: ticket.ticket_template.price
          } : nil,
          usages: ticket.ticket_usages.map do |usage|
            {
              id: usage.id,
              used_at: usage.used_at.iso8601,
              note: usage.note
            }
          end
        }
      end
    }
    
    File.write(backup_file, JSON.pretty_generate(backup_data))
    
    puts "✅ チケットバックアップ完了: #{backup_file}"
    puts "📊 バックアップ件数: #{tickets.count}件"
    
    cleanup_old_backups(backup_dir, 30)
  end
  
  desc "Create full system backup"
  task full: :environment do
    puts "[#{Time.current}] フルバックアップ開始"
    
    Rake::Task['backup:reservations'].invoke
    Rake::Task['backup:tickets'].invoke
    
    # ユーザーデータのバックアップ
    backup_users
    
    puts "[#{Time.current}] フルバックアップ完了"
  end
  
  desc "Restore reservation data from backup"
  task :restore, [:backup_file] => :environment do |t, args|
    backup_file = args[:backup_file]
    
    unless backup_file && File.exist?(backup_file)
      puts "❌ バックアップファイルが見つかりません: #{backup_file}"
      exit 1
    end
    
    puts "⚠️  データ復元を開始します: #{backup_file}"
    puts "⚠️  既存データは上書きされる可能性があります"
    print "続行しますか? (y/N): "
    
    response = STDIN.gets.chomp
    unless response.downcase == 'y'
      puts "❌ 復元をキャンセルしました"
      exit 0
    end
    
    backup_data = JSON.parse(File.read(backup_file))
    
    puts "📊 復元対象: #{backup_data['total_records']}件"
    puts "📅 バックアップ作成日: #{backup_data['created_at']}"
    
    restored_count = 0
    errors = []
    
    backup_data['reservations'].each do |reservation_data|
      begin
        # ユーザーを検索または作成
        user = if reservation_data['user']
          User.find_or_create_by(
            name: reservation_data['user']['name'],
            phone_number: reservation_data['user']['phone_number']
          ) do |u|
            u.email = reservation_data['user']['email']
            u.address = reservation_data['user']['address']
          end
        else
          nil
        end
        
        # 予約を作成または更新
        reservation = Reservation.find_or_initialize_by(id: reservation_data['id'])
        reservation.assign_attributes(
          name: reservation_data['name'],
          start_time: Time.zone.parse(reservation_data['start_time']),
          end_time: Time.zone.parse(reservation_data['end_time']),
          course: reservation_data['course'],
          status: reservation_data['status'],
          note: reservation_data['note'],
          user: user,
          cancellation_reason: reservation_data['cancellation_reason']
        )
        
        if reservation_data['cancelled_at']
          reservation.cancelled_at = Time.zone.parse(reservation_data['cancelled_at'])
        end
        
        if reservation.save
          restored_count += 1
        else
          errors << "ID #{reservation_data['id']}: #{reservation.errors.full_messages.join(', ')}"
        end
        
      rescue => e
        errors << "ID #{reservation_data['id']}: #{e.message}"
      end
    end
    
    puts "✅ 復元完了: #{restored_count}件"
    
    if errors.any?
      puts "⚠️  エラー (#{errors.count}件):"
      errors.first(10).each { |error| puts "  - #{error}" }
      puts "  ..." if errors.count > 10
    end
  end
  
  private
  
  def cleanup_old_backups(backup_dir, days)
    cutoff_date = days.days.ago
    old_files = Dir.glob(backup_dir.join("*_backup_*.json")).select do |file|
      File.mtime(file) < cutoff_date
    end
    
    old_files.each do |file|
      File.delete(file)
      puts "🗑️  古いバックアップファイルを削除: #{File.basename(file)}"
    end
    
    puts "📁 古いファイル削除: #{old_files.count}件"
  end
  
  def backup_users
    backup_dir = Rails.root.join('backups')
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = backup_dir.join("users_backup_#{timestamp}.json")
    
    users = User.includes(:notification_preference)
    
    backup_data = {
      created_at: Time.current.iso8601,
      version: "1.0",
      total_records: users.count,
      users: users.map do |user|
        {
          id: user.id,
          name: user.name,
          line_user_id: user.line_user_id,
          phone_number: user.phone_number,
          email: user.email,
          address: user.address,
          birth_date: user.birth_date&.iso8601,
          admin_memo: user.admin_memo,
          created_at: user.created_at.iso8601,
          notification_enabled: user.notification_preference&.enabled
        }
      end
    }
    
    File.write(backup_file, JSON.pretty_generate(backup_data))
    puts "✅ ユーザーバックアップ完了: #{backup_file}"
  end
end

# AWS S3バックアップ用のタスク（オプション）
namespace :backup do
  namespace :s3 do
    desc "Upload backup files to S3"
    task upload: :environment do
      # S3アップロード機能（aws-sdk-s3 gemが必要）
      puts "S3バックアップ機能は別途実装が必要です"
      # 実装例：
      # require 'aws-sdk-s3'
      # s3 = Aws::S3::Client.new
      # backup_files = Dir.glob(Rails.root.join('backups', '*.json'))
      # backup_files.each do |file|
      #   s3.put_object(
      #     bucket: ENV['S3_BACKUP_BUCKET'],
      #     key: "mobilis/#{File.basename(file)}",
      #     body: File.read(file)
      #   )
      # end
    end
  end
end