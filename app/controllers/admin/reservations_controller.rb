# app/controllers/admin/reservations_controller.rb

class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_reservation, only: [:show, :edit, :update, :destroy]

  def index
    @today_reservations = Reservation.includes(:user)
      .where(start_time: Time.current.beginning_of_day..Time.current.end_of_day)
      .where.not(status: :cancelled)
      .order(:start_time)
    
    respond_to do |format|
      format.html
      format.json do
        if request.format.json?
          Rails.logger.info "🔍 JSON request received for calendar events"
          Rails.logger.info "📋 All params: #{params.inspect}"

          begin
            # システム設定を取得
            @settings = ApplicationSetting.current
            system_interval = @settings&.reservation_interval_minutes || 15
            Rails.logger.info "✅ System interval: #{system_interval} minutes"
            
            # 予約を取得（キャンセル済みは除外）
          reservations = Reservation.includes(:user)
            .where(start_time: params[:start]..params[:end])
              .where.not(status: :cancelled)
            .order(:start_time)

                      # シフトデータを取得
          begin
            Rails.logger.info "🔍 Shift params: start=#{params[:start]}, end=#{params[:end]}"
            
            if params[:start].present? && params[:end].present?
              shifts = Shift.where(date: params[:start].to_date..params[:end].to_date)
                .order(:date)
              Rails.logger.info "📋 Found #{shifts.count} shifts"
              shifts.each do |shift|
                Rails.logger.info "  - Shift #{shift.id}: #{shift.date} (#{shift.shift_type})"
              end
            else
              Rails.logger.warn "⚠️ Missing start/end params for shifts, using default range"
              shifts = Shift.where(date: Date.current..Date.current + 7.days).order(:date)
              Rails.logger.info "📋 Found #{shifts.count} shifts (default range)"
            end
          rescue => e
            Rails.logger.error "❌ Error loading shifts: #{e.message}"
            shifts = []
          end

          Rails.logger.info "📋 Found #{reservations.count} reservations"

          events = []

            # 予約イベントを生成
            reservations.each do |reservation|
              Rails.logger.info "🔍 Processing reservation ID=#{reservation.id}"
              
              # 顧客名を取得
              customer_name = reservation.name.present? ? reservation.name : reservation.user&.name || '未設定'
              
              # JST時間として処理
              start_in_jst = reservation.start_time.in_time_zone('Asia/Tokyo')
              
              # 🔧 重要：コース時間を正確に抽出
              course_duration_minutes = extract_course_duration(reservation.course)
              
              # 🔧 重要：インターバル時間を正確に取得
              # 個別設定があればそれを使用、なければシステム設定
              interval_duration_minutes = if reservation.individual_interval_minutes.present?
                reservation.individual_interval_minutes
              else
                system_interval
              end
              
              # 🔧 重要：合計時間を計算
              total_duration_minutes = course_duration_minutes + interval_duration_minutes
              
              # 🔧 重要：終了時間を開始時間から計算（DBの値は使わない）
              calculated_end_time = start_in_jst + total_duration_minutes.minutes
              
              Rails.logger.info "🕐 Complete time calculation for reservation #{reservation.id}:"
              Rails.logger.info "  course_string: '#{reservation.course}'"
              Rails.logger.info "  course_duration: #{course_duration_minutes} minutes"
              Rails.logger.info "  individual_interval: #{reservation.individual_interval_minutes || 'nil (using system)'}"
              Rails.logger.info "  interval_duration: #{interval_duration_minutes} minutes"
              Rails.logger.info "  total_duration: #{total_duration_minutes} minutes"
              Rails.logger.info "  start_time: #{start_in_jst}"
              Rails.logger.info "  calculated_end: #{calculated_end_time}"
              Rails.logger.info "  db_end_time: #{reservation.end_time&.in_time_zone('Asia/Tokyo')}"
              Rails.logger.info "  slots_needed: #{total_duration_minutes / 10.0} (10min intervals)"
              
              # FullCalendar用のISO文字列（タイムゾーン情報なし）
              start_iso = start_in_jst.strftime('%Y-%m-%dT%H:%M:%S')
              end_iso = calculated_end_time.strftime('%Y-%m-%dT%H:%M:%S')
              
              # インターバル情報
              has_interval = interval_duration_minutes > 0
              is_individual_interval = reservation.individual_interval_minutes.present?
              
              # ステータスに応じた色設定
              colors = get_status_colors(reservation.status)
              
              # 🎯 重要：イベントオブジェクトを作成（正確な時間データ付き）
              event = {
                id: reservation.id.to_s,
                title: "#{customer_name} - #{reservation.course}",
                start: start_iso,
                end: end_iso,  # 📅 計算された正確な終了時間
                backgroundColor: colors[:bg],
                borderColor: colors[:border],
                textColor: colors[:text] || 'white',
                classNames: build_event_classes(reservation, has_interval),
                      extendedProps: {
                  type: 'reservation',
                  customer_name: customer_name,
                  course: reservation.course,
                  course_duration: course_duration_minutes,
                  interval_duration: interval_duration_minutes,
                  total_duration: total_duration_minutes,
                  has_interval: has_interval,
                  is_individual_interval: is_individual_interval,
                  effective_interval_minutes: interval_duration_minutes,
                  individual_interval_minutes: reservation.individual_interval_minutes,
                  system_interval_minutes: system_interval,
                  status: reservation.status,
                  note: reservation.note,
                  cancellation_reason: reservation.cancellation_reason,
                  created_at: reservation.created_at.iso8601,
                  updated_at: reservation.updated_at.iso8601,
                  createdAt: reservation.created_at.iso8601,
                  updatedAt: reservation.updated_at.iso8601,
                  # 計算検証用
                  calculated_slots: total_duration_minutes / 10.0,
                  expected_height_px: (total_duration_minutes / 10.0) * 40,
                  customer: {
                    id: reservation.user&.id,
                    name: customer_name,
                    phone: reservation.user&.phone_number,
                    email: reservation.user&.email,
                    kana: reservation.user&.respond_to?(:kana) ? reservation.user.kana : nil,
                    birth_date: reservation.user&.birth_date&.strftime('%Y-%m-%d')
                  }
                }
              }
              
              events << event
              
              # 🎯 各コースの組み合わせをログ出力
              course_type = case course_duration_minutes
              when 40 then "40分コース"
              when 60 then "60分コース"  
              when 80 then "80分コース"
              else "不明(#{course_duration_minutes}分)"
              end
              
              interval_type = is_individual_interval ? "個別#{interval_duration_minutes}分" : "システム#{interval_duration_minutes}分"
              
              Rails.logger.info "✅ Event created: #{course_type} + #{interval_type} = #{total_duration_minutes}分 (#{total_duration_minutes/10.0}スロット)"
            end

            # シフトイベントを生成（無効化）
            # Rails.logger.info "🎯 Starting shift event generation for #{shifts.count} shifts"
            # shifts.each do |shift|
            #   begin
            #     Rails.logger.info "🔍 Processing shift ID=#{shift.id} for date=#{shift.date}"
                
                # シフトの開始時間と終了時間を設定
                # shift_start_time = if shift.start_time.present?
                #   shift.date.to_time.change(hour: shift.start_time.hour, min: shift.start_time.min)
                # else
                #   shift.date.to_time.change(hour: 9, min: 0) # デフォルト9:00
                # end
                # 
                # shift_end_time = if shift.end_time.present?
                #   shift.date.to_time.change(hour: shift.end_time.hour, min: shift.end_time.min)
                # else
                #   shift.date.to_time.change(hour: 18, min: 0) # デフォルト18:00
                # end
              
                # シフトタイプに応じた色設定
                # シフトイベントを作成（表示しない）
                # shift_event = {
                #   id: "shift_#{shift.id}",
                #   title: "#{shift.shift_type_display} - #{shift.business_hours}",
                #   start: shift_start_time.strftime('%Y-%m-%dT%H:%M:%S'),
                #   end: shift_end_time.strftime('%Y-%m-%dT%H:%M:%S'),
                #   backgroundColor: '#6c757d',
                #   borderColor: '#545b62',
                #   textColor: 'white',
                #   classNames: ['fc-timegrid-event', 'shift-event', shift.shift_type],
                #   extendedProps: {
                #     type: 'shift',
                #     shift_id: shift.id,
                #     shift_type: shift.shift_type,
                #     shift_type_display: shift.shift_type_display,
                #     business_hours: shift.business_hours,
                #     breaks: shift.breaks,
                #     notes: shift.notes
                #   }
                # }
                
                # Rails.logger.info "✅ Shift event created: #{shift.shift_type_display} (#{shift.business_hours})"
                
                # events << shift_event
              # rescue => e
              #   Rails.logger.error "❌ Error processing shift #{shift.id}: #{e.message}"
              #   Rails.logger.error e.backtrace.first(5).join("\n")
              # end
              # end
              
              # Rails.logger.info "🎯 Shift event generation completed. Total events: #{events.count}"
            
            # 🎯 全体のサマリーログ
            Rails.logger.info "📊 Event creation summary:"
            events.group_by { |e| e[:extendedProps][:total_duration] }.each do |duration, events_group|
              # nil チェックを追加
              if duration.present? && duration.is_a?(Numeric)
                slots = duration / 10.0
                Rails.logger.info "  #{duration}分 (#{slots}スロット): #{events_group.length}件"
              else
                Rails.logger.warn "⚠️ Invalid duration found: #{duration.inspect} for #{events_group.length} events"
                # デバッグ用に最初のイベントの詳細を出力
                if events_group.first
                  Rails.logger.warn "  Sample event: #{events_group.first[:extendedProps].inspect}"
                end
              end
            end
            
            render json: events, content_type: 'application/json'

        rescue => e
          Rails.logger.error "❌ Calendar data fetch error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: {
              error: 'カレンダーデータの取得に失敗しました',
              details: e.message,
              backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
          }, status: :internal_server_error
          end
        else
          render json: { error: 'Invalid request format' }, status: :bad_request
        end
      end
    end
  end

  def calendar
    # 現在の週の予約データを取得（デフォルト）
    start_date = Date.current.beginning_of_week
    end_date = start_date + 6.days
    
    @reservations = Reservation.includes(:user)
      .where(start_time: start_date.beginning_of_day..end_date.end_of_day)
      .where.not(status: :cancelled)
      .order(:start_time)
  end



  def create_booking
    Rails.logger.info "🔄 Create booking called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    # パラメータの検証
    if params[:reservation].blank?
      Rails.logger.error "❌ Missing reservation parameters"
      render json: {
        success: false,
        errors: ['予約パラメータが不足しています'],
        message: '予約の作成に失敗しました'
      }, status: :unprocessable_entity
      return
    end
    
    # ユーザーを検索または作成
    user = nil
    if params[:reservation][:user_id].present?
      user = User.find_by(id: params[:reservation][:user_id])
      Rails.logger.info "🔍 Found user by ID: #{user&.name} (ID: #{user&.id})"
    elsif params[:reservation][:user_attributes].present?
      user_attrs = params[:reservation][:user_attributes]
      user = User.find_by(phone_number: user_attrs[:phone_number])
      
      if user.nil?
        user = User.create!(
          name: user_attrs[:name],
          phone_number: user_attrs[:phone_number],
          email: user_attrs[:email]
        )
        Rails.logger.info "🔄 Created new user: #{user.name} (ID: #{user.id})"
      else
        Rails.logger.info "🔍 Found existing user: #{user.name} (ID: #{user.id})"
      end
    end

    if user.nil?
      Rails.logger.error "❌ No user found or created"
      render json: {
        success: false,
        errors: ['ユーザー情報が不足しています'],
        message: '予約の作成に失敗しました'
      }, status: :unprocessable_entity
      return
    end

    # 予約パラメータを準備
    reservation_attrs = reservation_params.except(:user_attributes, :user_id)
    reservation_attrs[:user_id] = user.id

    @reservation = Reservation.new(reservation_attrs)
    @reservation.status = params[:reservation][:status] || :tentative
    
    # 明示的にend_timeを設定（バリデーションエラーを防ぐため）
    if @reservation.start_time.present? && @reservation.course.present?
      duration = @reservation.get_duration_minutes
      @reservation.end_time = @reservation.start_time + duration.minutes
      Rails.logger.info "🔍 Manually set end_time: #{@reservation.start_time} + #{duration} minutes = #{@reservation.end_time}"
    end
    
    # 管理者用の制限をスキップ
    @reservation.skip_business_hours_validation = true
    @reservation.skip_advance_booking_validation = true
    @reservation.skip_advance_notice_validation = true
    @reservation.skip_overlap_validation = true
    @reservation.skip_time_validation = true  # 時間間隔バリデーションもスキップ
    
    if @reservation.save
      render json: {
        success: true,
        reservation: @reservation.as_json(include: :user),
        message: '予約が作成されました'
      }
    else
      render json: {
        success: false,
        errors: @reservation.errors.full_messages,
        message: '予約の作成に失敗しました'
      }, status: :unprocessable_entity
    end
  end

  def delete_reservation
    Rails.logger.info "🔄 Delete reservation called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      reservation_id = params[:reservation_id]
      @reservation = Reservation.find(reservation_id)
      
      # 削除前にキャンセル通知を送信
      send_cancellation_notifications_before_delete(@reservation)
      
      if @reservation.destroy
        Rails.logger.info "✅ Reservation #{reservation_id} deleted successfully"
        render json: {
          success: true,
          message: '予約が削除されました'
        }
      else
        Rails.logger.error "❌ Failed to delete reservation #{reservation_id}"
        render json: {
          success: false,
          message: '予約の削除に失敗しました'
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation #{reservation_id} not found"
      render json: {
        success: false,
        message: '予約が見つかりませんでした'
      }, status: :not_found
    rescue => e
      Rails.logger.error "❌ Error deleting reservation: #{e.message}"
      render json: {
        success: false,
        message: "予約の削除中にエラーが発生しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def search_users
    Rails.logger.info "🔍 Search users called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      query = params[:query]&.strip
      
      if query.blank?
        render json: {
          success: true,
          users: []
        }
        return
      end
      
      # 名前、電話番号、メールアドレスで検索（PostgreSQL対応）
      users = User.where(
        "LOWER(name) LIKE LOWER(?) OR LOWER(phone_number) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?)",
        "%#{query}%", "%#{query}%", "%#{query}%"
      ).limit(10).order(:name)
      
      user_data = users.map do |user|
        {
          id: user.id,
          name: user.name,
          phone_number: user.phone_number || '',
          email: user.email || '',
          active_tickets: user.active_ticket_count,
          last_visit: user.last_usage_date&.strftime('%Y-%m-%d') || 'なし'
        }
      end
      
      Rails.logger.info "✅ Found #{users.count} users matching '#{query}'"
      
      render json: {
        success: true,
        users: user_data
      }
    rescue => e
      Rails.logger.error "❌ Error searching users: #{e.message}"
      render json: {
        success: false,
        message: "ユーザー検索中にエラーが発生しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def update_reservation_status
    Rails.logger.info "🔄 Update reservation status called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      reservation_id = params[:reservation_id]
      new_status = params[:status]
      cancellation_reason = params[:cancellation_reason]
      
      @reservation = Reservation.find(reservation_id)
      @reservation.status = new_status
      @reservation.cancellation_reason = cancellation_reason if cancellation_reason.present?
      
      # 管理者用のバリデーションスキップ
      @reservation.skip_business_hours_validation = true
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      @reservation.skip_time_validation = true
      @reservation.skip_overlap_validation = true
      
      if @reservation.save
        Rails.logger.info "✅ Reservation #{reservation_id} status updated to #{new_status}"
        render json: {
          success: true,
          message: '予約ステータスが更新されました',
          reservation: {
            id: @reservation.id,
            status: @reservation.status
          }
        }
      else
        Rails.logger.error "❌ Failed to update reservation status: #{@reservation.errors.full_messages}"
        render json: {
          success: false,
          message: "予約ステータスの更新に失敗しました: #{@reservation.errors.full_messages.join(', ')}"
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation #{reservation_id} not found"
      render json: {
        success: false,
        message: '予約が見つかりませんでした'
      }, status: :not_found
    rescue => e
      Rails.logger.error "❌ Error updating reservation status: #{e.message}"
      render json: {
        success: false,
        message: "予約ステータスの更新中にエラーが発生しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def load_reservations
    Rails.logger.info "🔄 load_reservations called with params: #{params}"
    week_start_date = params[:week_start_date]
    
    if week_start_date.blank?
      render json: { success: false, message: 'Week start date is required' }
      return
    end
    
    begin
      start_date = Date.parse(week_start_date)
      end_date = start_date + 6.days
      
      reservations = Reservation.includes(:user)
        .where(start_time: start_date.beginning_of_day..end_date.end_of_day)
        .where.not(status: :cancelled)
        .order(:start_time)
      
      # Format reservations by date with full timestamp data
      reservations_by_date = {}
      
      reservations.each do |reservation|
        date_key = reservation.start_time.strftime('%Y-%m-%d')
        reservations_by_date[date_key] ||= []
        
        reservations_by_date[date_key] << {
          id: reservation.id,
          time: reservation.start_time.strftime('%H:%M'),
          start_time: reservation.start_time.iso8601, # Add start_time for validation
          date: reservation.start_time.strftime('%Y-%m-%d'), # Add date for validation
          duration: reservation.get_duration_minutes,
          customer: reservation.name || reservation.user&.name || '未設定',
          phone: reservation.user&.phone_number || '',
          email: reservation.user&.email || '',
          note: reservation.note || '',
          status: reservation.status,
          is_break: false, # is_break column doesn't exist in database
          createdAt: reservation.created_at.iso8601,
          updatedAt: reservation.updated_at.iso8601,
          userId: reservation.user_id,
          effective_interval_minutes: reservation.effective_interval_minutes,
          individual_interval_minutes: reservation.individual_interval_minutes.presence
        }
      end
      
      render json: {
        success: true,
        reservations: reservations_by_date
      }
    rescue Date::Error
      render json: { success: false, message: 'Invalid date format' }
    rescue => e
      Rails.logger.error "❌ Error in load_reservations: #{e.message}"
      render json: { success: false, message: 'Server error' }
    end
  end



  def update_interval
    Rails.logger.info "🔄 update_interval called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      reservation_id = params[:id]
      @reservation = Reservation.find(reservation_id)
      new_interval = params[:reservation][:individual_interval_minutes]
      
      Rails.logger.info "🔄 Updating interval for reservation #{reservation_id} to #{new_interval} minutes"
      
      # Admin can bypass validations
      @reservation.skip_business_hours_validation = true
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      @reservation.skip_time_validation = true
      @reservation.skip_overlap_validation = true
      
      if @reservation.update(individual_interval_minutes: new_interval)
        Rails.logger.info "✅ Interval updated successfully to #{new_interval} minutes"
        render json: {
          success: true,
          message: '予約が更新されました',
          reservation: {
            id: @reservation.id,
            individual_interval_minutes: @reservation.individual_interval_minutes,
            effective_interval_minutes: @reservation.effective_interval_minutes,
            updated_at: @reservation.updated_at.iso8601
          }
        }
      else
        Rails.logger.error "❌ Failed to update interval: #{@reservation.errors.full_messages}"
        render json: {
          success: false,
          message: "インターバルの更新に失敗しました: #{@reservation.errors.full_messages.join(', ')}"
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation #{reservation_id} not found"
      render json: {
        success: false,
        message: '予約が見つかりませんでした'
      }, status: :not_found
    rescue => e
      Rails.logger.error "❌ Error updating interval: #{e.message}"
      render json: {
        success: false,
        message: "インターバルの更新中にエラーが発生しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def update_booking
    Rails.logger.info "🔄 Update booking called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      reservation_id = params[:id]
      @reservation = Reservation.find(reservation_id)
      
      # ユーザーを検索または作成
      user = nil
      
      # 直接user_idが指定された場合の処理を追加
      if params[:reservation][:user_id].present?
        user = User.find(params[:reservation][:user_id])
        Rails.logger.info "🔄 Found user by ID: #{user.name} (ID: #{user.id})"
      elsif params[:reservation][:user_attributes].present?
        user_attrs = params[:reservation][:user_attributes]
        user = User.find_by(phone_number: user_attrs[:phone_number])
        
        if user.nil?
          user = User.create!(
            name: user_attrs[:name],
            phone_number: user_attrs[:phone_number],
            email: user_attrs[:email]
          )
        else
          # 既存ユーザーの情報を更新
          user.update!(
            name: user_attrs[:name],
            email: user_attrs[:email]
          )
        end
      end
      
      # 予約パラメータを準備
      reservation_attrs = reservation_params.except(:user_attributes, :user_id)
      if user
        reservation_attrs[:user_id] = user.id
        reservation_attrs[:name] = user.name  # 予約のnameフィールドも更新
        Rails.logger.info "🔄 Updating reservation name to: #{user.name}"
      end
      
      # バリデーション設定（管理者用の制限をスキップ）
      Rails.logger.info "🔍 Setting validation flags for reservation #{@reservation.id}"
      
      # 管理者用の制限をスキップ
      @reservation.skip_business_hours_validation = true
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      @reservation.skip_time_validation = true
      @reservation.skip_overlap_validation = true
      Rails.logger.info "🔄 Admin validation flags: skip_time=#{@reservation.skip_time_validation}, skip_business_hours=#{@reservation.skip_business_hours_validation}, skip_overlap=#{@reservation.skip_overlap_validation}"
      
      Rails.logger.info "🔍 Final validation flags: skip_time=#{@reservation.skip_time_validation}, skip_business_hours=#{@reservation.skip_business_hours_validation}, skip_overlap=#{@reservation.skip_overlap_validation}"
      
      # start_timeが更新される場合は、end_timeも再計算する必要がある
      if reservation_attrs[:start_time].present?
        Rails.logger.info "🔄 start_time update detected: #{reservation_attrs[:start_time]}"
        Rails.logger.info "🔄 Current reservation course: #{@reservation.course}"
        
        # 既存のコース時間を使用してend_timeを計算
        if @reservation.course.present?
          course_duration = extract_course_duration(@reservation.course)
          begin
            new_start_time = Time.zone.parse(reservation_attrs[:start_time])
            new_end_time = new_start_time + course_duration.minutes
            
            reservation_attrs[:end_time] = new_end_time
            Rails.logger.info "🔄 Recalculated end_time: #{new_end_time} (course: #{course_duration}分)"
            Rails.logger.info "🔄 Final reservation_attrs: #{reservation_attrs}"
          rescue => e
            Rails.logger.error "❌ Error parsing start_time: #{e.message}"
            Rails.logger.error "❌ start_time value: #{reservation_attrs[:start_time]}"
            # Continue without updating end_time if parsing fails
          end
        else
          Rails.logger.warn "⚠️ No course found for reservation, skipping end_time calculation"
        end
      else
        Rails.logger.info "🔍 No start_time update, reservation_attrs: #{reservation_attrs}"
      end
      
      Rails.logger.info "🔄 Attempting to update reservation with attributes: #{reservation_attrs}"
      Rails.logger.info "🔄 Current reservation state: start_time=#{@reservation.start_time}, end_time=#{@reservation.end_time}, course=#{@reservation.course}"
      
      if @reservation.update(reservation_attrs)
        Rails.logger.info "✅ Reservation #{reservation_id} updated successfully"
        Rails.logger.info "✅ Updated reservation state: start_time=#{@reservation.start_time}, end_time=#{@reservation.end_time}, course=#{@reservation.course}"
        render json: {
          success: true,
          message: '予約が更新されました',
          reservation: {
            id: @reservation.id,
            start_time: @reservation.start_time.iso8601,
            end_time: @reservation.end_time.iso8601,
            course: @reservation.course,
            name: @reservation.name,
            note: @reservation.note,
            status: @reservation.status,
            created_at: @reservation.created_at.iso8601,
            updated_at: @reservation.updated_at.iso8601,
            user: {
              name: @reservation.user&.name,
              phone_number: @reservation.user&.phone_number,
              email: @reservation.user&.email
            }
          }
        }
      else
        Rails.logger.error "❌ Failed to update reservation: #{@reservation.errors.full_messages}"
        Rails.logger.error "❌ Validation details: #{@reservation.errors.details}"
        Rails.logger.error "❌ Reservation attributes: #{@reservation.attributes}"
        Rails.logger.error "❌ Attempted attributes: #{reservation_attrs}"
        render json: {
          success: false,
          message: "予約の更新に失敗しました: #{@reservation.errors.full_messages.join(', ')}"
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation #{reservation_id} not found"
      render json: {
        success: false,
        message: '予約が見つかりませんでした'
      }, status: :not_found
    rescue => e
      Rails.logger.error "❌ Error updating reservation: #{e.message}"
      render json: {
        success: false,
        message: "予約の更新中にエラーが発生しました: #{e.message}"
      }, status: :internal_server_error
    end
  end

  def save_shift_settings
    Rails.logger.info "🔄 Save shift settings called"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      schedule_data = params[:schedule_data]
      is_recurring = params[:is_recurring] || false
      week_start_date = params[:week_start_date]
      
      Rails.logger.info "🔍 Processing schedule data: #{schedule_data.inspect}"
      Rails.logger.info "🔍 is_recurring: #{is_recurring}"
      Rails.logger.info "🔍 week_start_date: #{week_start_date}"
      
      if is_recurring
        # デフォルトスケジュールを保存 - 使用する特別な日付（例：1900-01-01）
        default_date = Date.new(1900, 1, 1)
        Rails.logger.info "🔍 Saving recurring schedule with default date: #{default_date}"
        weekly_schedule = WeeklySchedule.find_or_initialize_by(week_start_date: default_date)
        Rails.logger.info "🔍 Found/created weekly schedule: #{weekly_schedule.inspect}"
        result = weekly_schedule.update!(schedule: schedule_data)
        Rails.logger.info "✅ Recurring schedule saved successfully: #{result}"
      else
        # 特定の週のスケジュールを保存
        Rails.logger.info "🔍 Saving specific week schedule for: #{week_start_date}"
        weekly_schedule = WeeklySchedule.find_or_initialize_by(week_start_date: week_start_date)
        Rails.logger.info "🔍 Found/created weekly schedule: #{weekly_schedule.inspect}"
        result = weekly_schedule.update!(schedule: schedule_data)
        Rails.logger.info "✅ Specific week schedule saved successfully: #{result}"
      end
      
      Rails.logger.info "✅ Final weekly_schedule state: #{weekly_schedule.inspect}"
      Rails.logger.info "✅ Final schedule attribute: #{weekly_schedule.schedule.inspect}"
      
      render json: {
        success: true,
        message: 'シフト設定が保存されました'
      }
    rescue => e
      Rails.logger.error "❌ Error saving shift settings: #{e.message}"
      Rails.logger.error "❌ Error backtrace: #{e.backtrace.join("\n")}"
      render json: {
        success: false,
        message: "シフト設定の保存に失敗しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def load_shift_settings
    Rails.logger.info "🔄 Load shift settings called"
    
    begin
      week_start_date = params[:week_start_date]
      Rails.logger.info "📅 Loading settings for week: #{week_start_date}"
      
      # デフォルトスケジュールを取得（クラスメソッドを使用）
      default_schedule = WeeklySchedule.schedule_for_javascript
      Rails.logger.info "🔍 Default schedule: #{default_schedule.inspect}"
      
      # 特定の週のスケジュールを取得
      weekly_schedule = WeeklySchedule.find_by(week_start_date: week_start_date)
      Rails.logger.info "🔍 Weekly schedule record: #{weekly_schedule.inspect}"
      
      if weekly_schedule
        # 既存の週固有スケジュールがある場合
        Rails.logger.info "🔍 Raw schedule from database: #{weekly_schedule.schedule.inspect}"
        current_week_schedule = weekly_schedule.schedule_for_javascript
        Rails.logger.info "✅ Found custom schedule for week #{week_start_date}: #{current_week_schedule.inspect}"
      else
        # 週固有スケジュールがない場合、デフォルトを使用
        # デフォルトスケジュールをデータベースから取得
        default_date = Date.new(1900, 1, 1)
        default_weekly_schedule = WeeklySchedule.find_by(week_start_date: default_date)
        Rails.logger.info "🔍 Default weekly schedule from DB: #{default_weekly_schedule.inspect}"
        
        if default_weekly_schedule
          Rails.logger.info "🔍 Raw default schedule from DB: #{default_weekly_schedule.schedule.inspect}"
          current_week_schedule = default_weekly_schedule.schedule_for_javascript
          Rails.logger.info "✅ Found default schedule in database: #{current_week_schedule.inspect}"
        else
          current_week_schedule = default_schedule
          Rails.logger.info "ℹ️ No default schedule in database, using hardcoded default: #{current_week_schedule.inspect}"
        end
      end
      
      response_data = {
        success: true,
        default_schedule: default_schedule,
        current_week_schedule: current_week_schedule,
        has_custom_schedule: weekly_schedule.present?,
        week_start_date: week_start_date
      }
      
      Rails.logger.info "🔍 Final response data: #{response_data.inspect}"
      
      render json: response_data
    rescue => e
      Rails.logger.error "❌ Error loading shift settings: #{e.message}"
      Rails.logger.error "❌ Error backtrace: #{e.backtrace.join("\n")}"
      render json: {
        success: false,
        message: "シフト設定の読み込みに失敗しました: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def show
      respond_to do |format|
      format.html
      format.json do
          render json: {
            success: true,
            id: @reservation.id,
          start_time: @reservation.start_time.in_time_zone('Asia/Tokyo').iso8601,  # JST時間で送信
          end_time: @reservation.end_time.in_time_zone('Asia/Tokyo').iso8601,      # JST時間で送信
            course: @reservation.course,
            status: @reservation.status,
            note: @reservation.note,
          user_id: @reservation.user_id,
          user: {
            id: @reservation.user&.id,
            name: @reservation.user&.name,
            kana: @reservation.user&.respond_to?(:kana) ? @reservation.user.kana : nil,
            phone: @reservation.user&.phone_number,
            email: @reservation.user&.email,
            birth_date: @reservation.user&.birth_date&.strftime('%Y-%m-%d')
          }
        }
      end
    end
  end

  def new
    @reservation = Reservation.new
  end

  # 空き時間取得用のAPIエンドポイント
  def available_times
    Rails.logger.info "🔍 Available times request received: #{params.inspect}"
    
    date = Date.parse(params[:date])
    duration = params[:duration].to_i
    
    Rails.logger.info "📅 Date: #{date}, Duration: #{duration} minutes"
    
    available_slots = get_available_time_slots(date, duration)
    
    Rails.logger.info "✅ Found #{available_slots.length} available slots"
    
    render json: {
      success: true,
      slots: available_slots.map { |slot| {
        time: slot[:start_time].strftime('%H:%M'),
        display: "#{slot[:start_time].strftime('%H:%M')} - #{slot[:end_time].strftime('%H:%M')}",
        value: slot[:start_time].strftime('%H:%M'),
        start_datetime: slot[:start_time].iso8601,
        end_datetime: slot[:end_time].iso8601
      }}
    }
  rescue => e
    Rails.logger.error "❌ Error in available_times: #{e.message}"
    Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
    render json: { success: false, error: e.message }
  end

  def create
    Rails.logger.info "🔄 Create reservation"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      # パラメータの処理（時間をJST として適切に処理）
      processed_params = reservation_params.dup
      
      # start_time, end_time が含まれている場合、JST として処理
      if processed_params[:start_time].present?
        # ISO8601形式の文字列をJST時間としてパース
        processed_params[:start_time] = Time.zone.parse(processed_params[:start_time])
        Rails.logger.info "🕐 Parsed start_time: #{processed_params[:start_time]} (JST)"
      end
      
      if processed_params[:end_time].present?
        processed_params[:end_time] = Time.zone.parse(processed_params[:end_time])  
        Rails.logger.info "🕐 Parsed end_time: #{processed_params[:end_time]} (JST)"
      end
      
      # date と time パラメータがある場合は統合処理
      if processed_params[:date].present? && processed_params[:time].present?
        start_datetime = Time.zone.parse("#{processed_params[:date]} #{processed_params[:time]}")
        processed_params[:start_time] = start_datetime
        
        # コースから終了時間を計算
        if processed_params[:course].present?
          duration = case processed_params[:course]
                    when '40分' then 40.minutes
                    when '60分' then 60.minutes
                    when '80分' then 80.minutes
                    else 60.minutes
                    end
          processed_params[:end_time] = start_datetime + duration
        end
        
        # date, time パラメータは削除
        processed_params.delete(:date)
        processed_params.delete(:time)
      end
      
      # individual_interval_minutesの処理（空文字列をnullに変換）
      if processed_params[:individual_interval_minutes].present?
        if processed_params[:individual_interval_minutes].to_s.strip == ''
          processed_params[:individual_interval_minutes] = nil
        else
          processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
        end
      end
      
      # 予約オブジェクトを作成
      @reservation = Reservation.new(processed_params)
      
      # 管理者用のバリデーションスキップ設定（営業時間はチェックする）
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      
      # インターバル設定がある場合は時間バリデーションをスキップ
      effective_interval = @reservation.effective_interval_minutes
      if effective_interval && effective_interval > 0
        @reservation.skip_time_validation = true
      end
      
      # キャンセルステータスで作成する場合はcancel!メソッドを使用
      if processed_params[:status] == 'cancelled'
        Rails.logger.info "🔄 Creating cancelled reservation"
        if @reservation.save
          @reservation.cancel!(processed_params[:cancellation_reason])
          success = true
        else
          success = false
        end
      else
        success = @reservation.save
      end
      
      if success
        Rails.logger.info "✅ Reservation created successfully"
        respond_to do |format|
          format.html { redirect_to calendar_admin_reservations_path, notice: '予約を作成しました' }
          format.json { render json: { success: true, id: @reservation.id } }
        end
      else
        Rails.logger.error "❌ Reservation creation failed: #{@reservation.errors.full_messages}"
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { success: false, error: @reservation.errors.full_messages.join(', ') } }
        end
      end
    rescue => e
      Rails.logger.error "❌ Create error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  def edit
  end

  def update
    Rails.logger.info "🔄 Update reservation #{@reservation.id}"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      # パラメータの処理（時間をJST として適切に処理）
      processed_params = reservation_params.dup
      
      # start_time, end_time が含まれている場合、JST として処理
      if processed_params[:start_time].present?
        # ISO8601形式の文字列をJST時間としてパース
        processed_params[:start_time] = Time.zone.parse(processed_params[:start_time])
        Rails.logger.info "🕐 Parsed start_time: #{processed_params[:start_time]} (JST)"
      end
      
      if processed_params[:end_time].present?
        processed_params[:end_time] = Time.zone.parse(processed_params[:end_time])  
        Rails.logger.info "🕐 Parsed end_time: #{processed_params[:end_time]} (JST)"
      end
      
      # date と time パラメータがある場合は統合処理
      if processed_params[:date].present? && processed_params[:time].present?
        start_datetime = Time.zone.parse("#{processed_params[:date]} #{processed_params[:time]}")
        processed_params[:start_time] = start_datetime
        
        # コースから終了時間を計算
        if processed_params[:course].present?
          duration = case processed_params[:course]
                    when '40分' then 40.minutes
                    when '60分' then 60.minutes
                    when '80分' then 80.minutes
                    else 60.minutes
                    end
          processed_params[:end_time] = start_datetime + duration
        end
        
        # date, time パラメータは削除
        processed_params.delete(:date)
        processed_params.delete(:time)
      end
      
      # individual_interval_minutesの処理（空文字列をnullに変換）
      if processed_params[:individual_interval_minutes].present?
        if processed_params[:individual_interval_minutes].to_s.strip == ''
          processed_params[:individual_interval_minutes] = nil
        else
          processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
        end
      end

      # ドラッグ更新の場合はインターバル時間を追加しない
      is_drag_update = params[:is_drag_update] == true
      effective_interval = nil
      
      if !is_drag_update
        # インターバル設定を反映して予約の終了時間を調整
        
        if processed_params[:individual_interval_minutes].present? && processed_params[:individual_interval_minutes] > 0
          # 個別インターバル設定がある場合
          effective_interval = processed_params[:individual_interval_minutes]
        elsif processed_params[:individual_interval_minutes].nil?
          # システム設定を使用する場合
          effective_interval = ApplicationSetting.current.reservation_interval_minutes
        end
        
        if effective_interval && effective_interval > 0 && processed_params[:end_time].present?
          # インターバル時間をそのまま追加（丸め処理なし）
          processed_params[:end_time] = processed_params[:end_time] + effective_interval.minutes
          Rails.logger.info "🕐 Adjusted end_time with interval: #{processed_params[:end_time]} (+#{effective_interval}分)"
        end
      else
        Rails.logger.info "🔄 Drag update detected, skipping interval adjustment"
      end
      
      Rails.logger.info "🔄 Processed params: #{processed_params.inspect}"
      Rails.logger.info "🔄 Individual interval minutes: #{processed_params[:individual_interval_minutes]}"
      
      # 管理者用のバリデーションスキップ設定（営業時間はチェックする）
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      
      # インターバル設定がある場合、またはドラッグ更新の場合は時間バリデーションをスキップ
      if (effective_interval && effective_interval > 0) || is_drag_update
        @reservation.skip_time_validation = true
        Rails.logger.info "🔄 Skipping time validation for #{is_drag_update ? 'drag update' : 'interval adjustment'}"
      end
      
      # ドラッグ更新時は、送信された時間をそのまま使用（インターバル時間は既に含まれている）
      if is_drag_update
        Rails.logger.info "🔄 Drag update detected, using time as-is for overlap validation"
      end
      
      # キャンセルステータスに変更する場合はcancel!メソッドを使用
      if processed_params[:status] == 'cancelled' && @reservation.status != 'cancelled'
        Rails.logger.info "🔄 Cancelling reservation #{@reservation.id}"
        @reservation.cancel!(processed_params[:cancellation_reason])
        success = true
      else
        success = @reservation.update(processed_params)
      end
      
      if success
        Rails.logger.info "✅ Reservation updated successfully"
        
        respond_to do |format|
          format.html { redirect_to calendar_admin_reservations_path, notice: '予約を更新しました' }
          format.json { 
            render json: { 
              success: true, 
              id: @reservation.id,
              start_time: @reservation.start_time.in_time_zone('Asia/Tokyo').iso8601,
              end_time: @reservation.end_time.in_time_zone('Asia/Tokyo').iso8601
            } 
          }
        end
      else
        Rails.logger.error "❌ Reservation update failed: #{@reservation.errors.full_messages}"
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { success: false, error: @reservation.errors.full_messages.join(', ') } }
        end
      end
    rescue => e
      Rails.logger.error "❌ Update error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  def destroy
    # 削除前にキャンセル通知を送信
    send_cancellation_notifications_before_delete(@reservation)
    
    @reservation.destroy
      
    respond_to do |format|
      format.html { redirect_to calendar_admin_reservations_path, notice: '予約を削除しました' }
      format.json { render json: { success: true } }
    end
  end

  # キャンセル統計と履歴を取得
  def cancellation_stats
    Rails.logger.info "📊 Fetching cancellation stats"
    
    # 今月の統計
    current_month = Time.current.beginning_of_month
    this_month_reservations = Reservation.where(created_at: current_month..current_month.end_of_month)
    this_month_cancelled = this_month_reservations.where(status: :cancelled).count
    this_month_total = this_month_reservations.count
    cancelled_rate = this_month_total > 0 ? (this_month_cancelled.to_f / this_month_total * 100).round(1) : 0

    Rails.logger.info "📊 This month stats: total=#{this_month_total}, cancelled=#{this_month_cancelled}, rate=#{cancelled_rate}%"

    # 最近のキャンセル履歴（過去30日、最新5件）
    recent_cancelled = Reservation.includes(:user)
      .where(status: :cancelled)
      .where('updated_at >= ?', 30.days.ago)  # cancelled_atの代わりにupdated_atを使用
      .order(updated_at: :desc)
      .limit(5)

    Rails.logger.info "📊 Found #{recent_cancelled.count} recent cancelled reservations"

    cancelled_history = recent_cancelled.map do |reservation|
      {
        id: reservation.id,
        customer_name: reservation.name || reservation.user&.name || '未設定',
        cancelled_at: reservation.updated_at.strftime('%m/%d %H:%M'),  # updated_atを使用
        reason: reservation.cancellation_reason,
        course: reservation.course
      }
    end

    Rails.logger.info "📊 Cancellation history: #{cancelled_history.inspect}"

    render json: {
      cancelled_count: this_month_cancelled,
      cancelled_rate: cancelled_rate,
      total_reservations: this_month_total,
      cancelled_history: cancelled_history
    }
  end

  # チケット情報を取得
  def tickets
    Rails.logger.info "🔍 Tickets request for reservation ID: #{params[:id]}"
    
    @reservation = Reservation.find(params[:id])
    Rails.logger.info "📋 Found reservation: #{@reservation.inspect}"
    Rails.logger.info "👤 User ID: #{@reservation.user_id}"
    
    if @reservation.user_id.present?
      user = @reservation.user
      Rails.logger.info "👤 Found user: #{user.name} (ID: #{user.id})"
      
      tickets = user.tickets.includes(:ticket_template)
        .order(created_at: :desc)
      
      Rails.logger.info "🎫 Found #{tickets.count} tickets for user"
      
      ticket_data = tickets.map do |ticket|
        ticket_info = {
          id: ticket.id,
          ticket_template_name: ticket.ticket_template.name,
          remaining_count: ticket.remaining_count,
          total_count: ticket.total_count,
          expiry_date: ticket.expiry_date,
          unit_type: ticket.ticket_template.name.include?('分') ? '分' : '枚'
        }
        Rails.logger.info "🎫 Ticket: #{ticket_info}"
        ticket_info
      end
      
      Rails.logger.info "✅ Returning #{ticket_data.length} tickets"
      render json: { success: true, tickets: ticket_data }
    else
      Rails.logger.warn "⚠️ No user ID for reservation #{@reservation.id}"
      render json: { success: false, message: 'ユーザー情報がありません' }
    end
  end

  # 予約履歴を取得
  def history
    @reservation = Reservation.find(params[:id])
    
    if @reservation.user_id.present?
      reservations = @reservation.user.reservations
        .where.not(id: @reservation.id) # 現在の予約を除外
        .order(start_time: :desc)
        .limit(10) # 最新10件
        .map do |reservation|
          {
            id: reservation.id,
            start_time: reservation.start_time,
            course: reservation.course,
            status: reservation.status
          }
        end
      
      render json: { success: true, reservations: reservations }
    else
      render json: { success: false, message: 'ユーザー情報がありません' }
    end
  end

  # テスト
  def test_api
    render json: { message: "test works" }
  end

  # テスト用 - by_day_of_week が動作するかチェック
  def test_by_day_of_week
    render json: { message: "by_day_of_week test works", timestamp: Time.current }
  end

  # 超シンプルテスト - デプロイが動作するかチェック
  def simple_test
    render json: { message: "SIMPLE TEST WORKS!", method: "simple_test" }
  end

  # 最小限テスト - 基本的な動作確認
  def minimal_test
    render plain: "MINIMAL TEST WORKS!"
  end

  # 特定の曜日の全予約を取得（定期的なスケジュール変更の影響チェック用）
  def by_day_of_week
    Rails.logger.info "🔍 by_day_of_week called - FIXED VISIBILITY"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      day_of_week = params[:day_of_week].to_i
      from_date = Date.parse(params[:from_date])
      
      Rails.logger.info "🔍 Searching for reservations: day_of_week=#{day_of_week}, from_date=#{from_date}"
      
      # 指定日以降の全予約を取得してフィルタリング
      all_reservations = Reservation.includes(:user)
                                   .where('start_time >= ?', from_date.beginning_of_day)
                                   .where.not(status: :cancelled)
                                   .order(:start_time)
      
      # 曜日でフィルタリング
      matching_reservations = all_reservations.select { |r| r.start_time.wday == day_of_week }
      
      Rails.logger.info "📊 Found #{matching_reservations.count} reservations for day #{day_of_week} from #{from_date}"
      
      reservations_data = matching_reservations.map do |reservation|
        {
          id: reservation.id,
          customer: reservation.name || reservation.user&.name || '未設定',
          date: reservation.start_time.strftime('%Y-%m-%d'),
          time: reservation.start_time.strftime('%H:%M'),
          duration: extract_course_duration(reservation.course),
          effective_interval_minutes: reservation.individual_interval_minutes || 
                                     ApplicationSetting.current&.reservation_interval_minutes || 10
        }
      end
      
      Rails.logger.info "✅ Returning #{reservations_data.count} reservations for validation"
      
      render json: reservations_data
    rescue Date::Error => e
      Rails.logger.error "❌ Invalid date format: #{e.message}"
      render json: { error: 'Invalid date format' }, status: :bad_request
    rescue => e
      Rails.logger.error "❌ Error fetching reservations by day of week: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end
  
  # 削除前にキャンセル通知を送信
  def send_cancellation_notifications_before_delete(reservation)
    Rails.logger.info "📧 Sending cancellation notifications before delete for reservation #{reservation.id}"
    
    begin
      # 削除前にcancelled_atを設定（通知用）
      reservation.update_column(:cancelled_at, Time.current) unless reservation.cancelled_at.present?
      
      # メール通知
      if reservation.user&.email.present?
        ReservationMailer.cancellation_notification(reservation).deliver_now
        Rails.logger.info "✅ Cancellation email sent to: #{reservation.user.email}"
      end
      
      # LINE通知
      if reservation.user&.line_user_id.present?
        LineBookingNotifier.send_cancellation_notification(reservation)
        Rails.logger.info "✅ LINE cancellation notification sent to: #{reservation.user.line_user_id}"
      end
      
      Rails.logger.info "📧 Cancellation notifications completed for reservation #{reservation.id}"
    rescue => e
      Rails.logger.error "❌ Error sending cancellation notifications: #{e.message}"
      # 通知エラーでも削除処理は続行
    end
  end

  def reservation_params
    params.require(:reservation).permit(
      :start_time, :end_time, :course, :status, :cancellation_reason, :note, :user_id,
              :name, :date, :time, :ticket_id, :individual_interval_minutes,
      user_attributes: [:name, :phone_number, :email]
    )
  end

  def get_status_colors(status)
    case status.to_s
    when 'confirmed'
      { bg: '#28a745', border: '#1e7e34', text: 'white' }
    when 'tentative'
      { bg: '#ffc107', border: '#e0a800', text: '#212529' }
    when 'cancelled'
      { bg: '#dc3545', border: '#bd2130', text: 'white' }
    when 'completed'
      { bg: '#6f42c1', border: '#59359a', text: 'white' }
    when 'no_show'
      { bg: '#6c757d', border: '#545b62', text: 'white' }
    else
      { bg: '#17a2b8', border: '#138496', text: 'white' }
    end
  end

  def process_reservation_params(params)
    processed_params = params.permit(
      :name, :course, :status, :note, :user_id, :ticket_id,
      :start_time, :end_time, :date, :time, :individual_interval_minutes
    ).to_h.with_indifferent_access
  
    Rails.logger.info "🔍 Raw params: #{params.inspect}"
    Rails.logger.info "🔍 Processed params before: #{processed_params.inspect}"
    
    # date + time から start_time を作成
    if processed_params[:date].present? && processed_params[:time].present?
      begin
        date = Date.parse(processed_params[:date])
        time_parts = processed_params[:time].split(':').map(&:to_i)
        start_datetime = Time.zone.local(date.year, date.month, date.day, time_parts[0], time_parts[1])
        processed_params[:start_time] = start_datetime
        
        # end_timeの計算（コース時間のみ、インターバルは含めない）
        if processed_params[:course].present?
          duration = case processed_params[:course]
                    when '40分' then 40.minutes
                    when '60分' then 60.minutes  
                    when '80分' then 80.minutes
                    else 60.minutes
                    end
          # 重要: end_timeはコース時間のみ。インターバルは含めない
          processed_params[:end_time] = start_datetime + duration
          
          Rails.logger.info "🕐 Set end_time to course duration only: #{processed_params[:end_time]} (course: #{duration/60}分)"
        end
        
        # date, time パラメータは削除
        processed_params.delete(:date)
        processed_params.delete(:time)
      rescue => e
        Rails.logger.error "日時変換エラー: #{e.message}"
      end
    end
    
    # individual_interval_minutesの処理（空文字列をnullに変換）
    if processed_params[:individual_interval_minutes].present?
      if processed_params[:individual_interval_minutes].to_s.strip == ''
        processed_params[:individual_interval_minutes] = nil
      else
        processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
      end
    end
  
    Rails.logger.info "🔄 Final processed params: #{processed_params.inspect}"
    
    processed_params
  end

  def extract_course_duration(course_string)
    Rails.logger.info "🔍 extract_course_duration called: course_string='#{course_string}'"
    
    return 60 unless course_string.present? # デフォルト
    
    case course_string.to_s.strip
    when "40分", "40分コース"
      Rails.logger.info "🔍 Matched 40分 format"
      40
    when "60分", "60分コース"
      Rails.logger.info "🔍 Matched 60分 format"
      60
    when "80分", "80分コース"
      Rails.logger.info "🔍 Matched 80分 format"
      80
    when /(\d+)分/ # 数字+分の形式
      duration = $1.to_i
      Rails.logger.info "🔍 Extracted duration from regex: #{duration} minutes"
      duration
    else
      Rails.logger.warn "⚠️ Unknown course format: '#{course_string}', defaulting to 60 minutes"
      60
    end
  end

  helper_method :extract_course_duration

  def build_event_classes(reservation, has_interval)
    classes = ['fc-timegrid-event', reservation.status]
    classes << 'has-interval' if has_interval
    classes << 'individual-interval' if reservation.individual_interval_minutes.present?
    classes
  end

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end
  
  # 削除前にキャンセル通知を送信
  def send_cancellation_notifications_before_delete(reservation)
    Rails.logger.info "📧 Sending cancellation notifications before delete for reservation #{reservation.id}"
    
    begin
      # 削除前にcancelled_atを設定（通知用）
      reservation.update_column(:cancelled_at, Time.current) unless reservation.cancelled_at.present?
      
      # メール通知
      if reservation.user&.email.present?
        ReservationMailer.cancellation_notification(reservation).deliver_now
        Rails.logger.info "✅ Cancellation email sent to: #{reservation.user.email}"
      end
      
      # LINE通知
      if reservation.user&.line_user_id.present?
        LineBookingNotifier.send_cancellation_notification(reservation)
        Rails.logger.info "✅ LINE cancellation notification sent to: #{reservation.user.line_user_id}"
      end
      
      Rails.logger.info "📧 Cancellation notifications completed for reservation #{reservation.id}"
    rescue => e
      Rails.logger.error "❌ Error sending cancellation notifications: #{e.message}"
      # 通知エラーでも削除処理は続行
    end
  end

  def reservation_params
    params.require(:reservation).permit(
      :start_time, :end_time, :course, :status, :cancellation_reason, :note, :user_id,
              :name, :date, :time, :ticket_id, :individual_interval_minutes,
      user_attributes: [:name, :phone_number, :email]
    )
  end

  def get_status_colors(status)
    case status.to_s
    when 'confirmed'
      { bg: '#28a745', border: '#1e7e34', text: 'white' }
    when 'tentative'
      { bg: '#ffc107', border: '#e0a800', text: '#212529' }
    when 'cancelled'
      { bg: '#dc3545', border: '#bd2130', text: 'white' }
    when 'completed'
      { bg: '#6f42c1', border: '#59359a', text: 'white' }
    when 'no_show'
      { bg: '#6c757d', border: '#545b62', text: 'white' }
    else
      { bg: '#17a2b8', border: '#138496', text: 'white' }
    end
  end

  def process_reservation_params(params)
    processed_params = params.dup
    
    # start_time, end_time が含まれている場合、JST として処理
    if processed_params[:start_time].present?
      # ISO8601形式の文字列をJST時間としてパース
      processed_params[:start_time] = Time.zone.parse(processed_params[:start_time])
      Rails.logger.info "🕐 Parsed start_time: #{processed_params[:start_time]} (JST)"
    end
    
    if processed_params[:end_time].present?
      processed_params[:end_time] = Time.zone.parse(processed_params[:end_time])  
      Rails.logger.info "🕐 Parsed end_time: #{processed_params[:end_time]} (JST)"
    end
    
    # individual_interval_minutesの処理（空文字列をnullに変換）
    if processed_params[:individual_interval_minutes].present?
      if processed_params[:individual_interval_minutes].to_s.strip == ''
        processed_params[:individual_interval_minutes] = nil
      else
        processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
      end
    end
    
    processed_params
  end

  def extract_course_duration(course_string)
    return 60 unless course_string.present?
    
    case course_string
    when /40分/
      40
    when /60分/
      60
    when /80分/
      80
    when /90分/
      90
    when /120分/
      120
    else
      60  # デフォルト
    end
  end

  def build_event_classes(reservation, has_interval)
    classes = ['fc-timegrid-event', reservation.status]
    classes << 'has-interval' if has_interval
    classes << 'individual-interval' if reservation.individual_interval_minutes.present?
    classes
  end

  # 空き時間スロットを取得
  def get_available_time_slots(date, duration)
    Rails.logger.info "🔍 Getting available time slots for #{date}, duration: #{duration} minutes"
    
    # 営業時間の設定
    opening_time = Time.zone.parse("#{date} 10:00")
    closing_time = Time.zone.parse("#{date} 19:00")
    
    Rails.logger.info "🕐 Business hours: #{opening_time.strftime('%H:%M')} - #{closing_time.strftime('%H:%M')}"
    
    # インターバル時間を取得
    interval_minutes = Reservation.interval_minutes
    Rails.logger.info "⏱️ Interval minutes: #{interval_minutes}"
    
    # 30分刻みでスロットを生成
    slot_interval = 30.minutes
    available_slots = []
    
    current_time = opening_time
    while current_time + duration.minutes <= closing_time
      end_time = current_time + duration.minutes
      
      # インターバルを考慮した空きチェック
      if time_slot_available_with_interval?(current_time, end_time)
        available_slots << {
          start_time: current_time,
          end_time: end_time,
          interval_info: interval_minutes > 0 ? "（準備時間#{interval_minutes}分含む）" : ""
        }
        Rails.logger.info "✅ Available slot: #{current_time.strftime('%H:%M')} - #{end_time.strftime('%H:%M')}"
      else
        Rails.logger.info "❌ Slot not available: #{current_time.strftime('%H:%M')} - #{end_time.strftime('%H:%M')}"
      end
      
      current_time += slot_interval
    end
    
    Rails.logger.info "📊 Total available slots: #{available_slots.length}"
    available_slots
  end

  # インターバルを考慮した時間スロットの空きチェック
  def time_slot_available_with_interval?(start_time, end_time)
    # 既存の予約との重複チェック
    overlapping_reservations = Reservation.where(
      'start_time < ? AND end_time > ?',
      end_time, start_time
    ).where.not(status: :cancelled)
    
    return false if overlapping_reservations.exists?
    
    # インターバル時間を考慮した重複チェック
    interval_minutes = Reservation.interval_minutes
    if interval_minutes > 0
      interval_end_time = end_time + interval_minutes.minutes
      interval_overlapping = Reservation.where(
        'start_time < ? AND end_time > ?',
        interval_end_time, start_time
      ).where.not(status: :cancelled)
      
      return false if interval_overlapping.exists?
    end
    
    true
  end

end