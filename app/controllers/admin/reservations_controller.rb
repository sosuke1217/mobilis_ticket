# app/controllers/admin/reservations_controller.rb
# この内容で既存のファイルを更新してください

class Admin::ReservationsController < ApplicationController
  include ErrorHandling
  before_action :authenticate_admin_user!

  def calendar
  end

  # app/controllers/admin/reservations_controller.rb の index アクション修正版
  def index
    respond_to do |format|
      format.html { redirect_to admin_reservations_calendar_path }
      format.json do
        begin
          Rails.logger.info "🔍 Starting calendar data fetch"

          begin
            settings_count = ApplicationSetting.count
            Rails.logger.info "📊 ApplicationSetting count: #{settings_count}"

            @settings = ApplicationSetting.current
            Rails.logger.info "✅ ApplicationSetting loaded: interval=#{@settings.reservation_interval_minutes}min"
          rescue => e
            Rails.logger.error "❌ ApplicationSetting error: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            @settings = OpenStruct.new(
              reservation_interval_minutes: 15,
              business_hours_start: 10,
              business_hours_end: 20
            )
            Rails.logger.info "🔧 Using fallback settings"
          end

          Rails.logger.info "🔍 Querying reservations from #{params[:start]} to #{params[:end]}"

          reservations = Reservation.includes(:user)
            .where(start_time: params[:start]..params[:end])
            .order(:start_time)

          Rails.logger.info "📋 Found #{reservations.count} reservations"

          events = []

          reservations.each_with_index do |reservation, index|
            Rails.logger.info "🔍 Processing reservation #{index + 1}/#{reservations.count}: ID=#{reservation.id}"

            begin
              calendar_json = reservation.as_calendar_json
              events << calendar_json
              Rails.logger.info "✅ Successfully processed reservation #{reservation.id}"

              begin
                interval_minutes = reservation.effective_interval_minutes
                Rails.logger.info "📏 Reservation #{reservation.id} interval: #{interval_minutes}min"

                if interval_minutes && interval_minutes > 0
                  interval_end_after = reservation.end_time + interval_minutes.minutes
                  if interval_end_after <= Time.zone.parse(params[:end])
                    events << {
                      id: "interval-after-#{reservation.id}",
                      title: "整理時間 (#{interval_minutes}分#{reservation.has_individual_interval? ? ' - 個別設定' : ''})",
                      start: reservation.end_time.iso8601,
                      end: interval_end_after.iso8601,
                      backgroundColor: reservation.has_individual_interval? ? '#ffeaa7' : '#e9ecef',
                      borderColor: reservation.has_individual_interval? ? '#fdcb6e' : '#ced4da',
                      textColor: '#6c757d',
                      className: reservation.has_individual_interval? ? 'interval-event individual-interval' : 'interval-event system-interval',
                      editable: true,
                      durationEditable: true,
                      extendedProps: {
                        type: 'interval',
                        reservation_id: reservation.id,
                        interval_type: 'after',
                        interval_minutes: interval_minutes,
                        is_individual: reservation.has_individual_interval?,
                        interval_description: reservation.interval_description
                      }
                    }
                    Rails.logger.info "✅ Added interval event for reservation #{reservation.id}"
                  end
                end
              rescue => interval_error
                Rails.logger.error "❌ Interval processing error for reservation #{reservation.id}: #{interval_error.message}"
                Rails.logger.error interval_error.backtrace.join("\n")
              end

            rescue => reservation_error
              Rails.logger.error "❌ Error processing reservation #{reservation.id}: #{reservation_error.message}"
              Rails.logger.error reservation_error.backtrace.join("\n")
            end
          end

          Rails.logger.info "✅ Successfully processed #{events.count} events"
          render json: events

        rescue => e
          Rails.logger.error "❌ Calendar data fetch error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")

          render json: {
            success: false,
            error: "カレンダーデータの取得に失敗しました: #{e.message}",
            details: e.backtrace.first(5)
          }, status: :internal_server_error
        end
      end
    end
  end

  def update_interval
    reservation = Reservation.find(params[:id])
    new_minutes = params[:interval_minutes].to_i

    if new_minutes > 0
      reservation.update(individual_interval_minutes: new_minutes)
      render json: { success: true, interval: new_minutes }
    else
      render json: { success: false, error: "無効な時間です" }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "❌ Interval update error: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def show
    Rails.logger.info "📋 SHOW request for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.includes(:user).find(params[:id])
      Rails.logger.info "✅ Found reservation: #{@reservation.name} at #{@reservation.start_time}"
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path }
        format.json {
          render json: {
            success: true,
            id: @reservation.id,
            name: @reservation.name,
            user_id: @reservation.user_id,
            user_name: @reservation.user&.name,
            course: @reservation.course,
            status: @reservation.status,
            note: @reservation.note,
            start_time: @reservation.start_time.iso8601,
            end_time: @reservation.end_time.iso8601,
            cancellation_reason: @reservation.cancellation_reason,
            cancelled_at: @reservation.cancelled_at&.iso8601,
            confirmation_sent_at: @reservation.confirmation_sent_at&.iso8601,
            reminder_sent_at: @reservation.reminder_sent_at&.iso8601,
            recurring: @reservation.recurring || false,
            recurring_type: @reservation.recurring_type,
            recurring_until: @reservation.recurring_until&.iso8601,
            created_at: @reservation.created_at.iso8601,
            updated_at: @reservation.updated_at.iso8601
          }
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found: #{params[:id]}"
      
      respond_to do |format|
        format.html { 
          redirect_to admin_reservations_calendar_path, 
          alert: "予約が見つかりません。" 
        }
        format.json { 
          render json: { 
            success: false, 
            error: "予約が見つかりません" 
          }, status: :not_found 
        }
      end
      
    rescue => e
      Rails.logger.error "❌ Show action error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html { 
          redirect_to admin_reservations_calendar_path, 
          alert: "予約データの取得中にエラーが発生しました。" 
        }
        format.json { 
          render json: { 
            success: false, 
            error: "予約データの取得中にエラーが発生しました: #{e.message}" 
          }, status: :internal_server_error 
        }
      end
    end
  end

  def new
    @reservation = Reservation.new
  
    # URLクエリ（?start_time=...）から hidden_field に値を渡す
    if params[:start_time].present?
      begin
        @reservation.start_time = Time.zone.parse(params[:start_time])
      rescue ArgumentError
        # パースできない場合の保険
        flash.now[:alert] = "開始時間が不正です"
      end
    end
  end

  def create
    Rails.logger.info "🆕 Creating reservation with params: #{params.inspect}"
    
    # 新規ユーザー作成が必要かチェック
    if params[:new_user].present?
      Rails.logger.info "👤 Creating with new user"
      create_reservation_with_new_user
    else
      Rails.logger.info "👤 Creating with existing user"
      create_reservation_with_existing_user
    end
  rescue => e
    Rails.logger.error "❌ Create action failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      format.json { render json: { success: false, error: "予約作成中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      format.html { redirect_to admin_reservations_calendar_path, alert: "予約作成中にエラーが発生しました" }
    end
  end
  
  def update
    unless params[:id].to_s.match?(/^\d+$/)
      logger.warn "⚠️ 不正なIDによるPATCHリクエスト: #{params[:id]}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "不正なIDです。" }
        format.json { render json: { success: false, error: "不正なID" }, status: :not_found }
      end
      return
    end
  
    begin
      @reservation = Reservation.find(params[:id])
      
      # 管理者による更新の場合、制限を解除
      update_params = reservation_params
      
      # 管理者用の制限なし更新を使用
      if @reservation.update_as_admin!(update_params)
        Rails.logger.info "✅ Reservation updated successfully by admin"
        respond_to do |format|
          format.json { 
            render json: { 
              success: true, 
              message: "予約を更新しました",
              reservation: {
                id: @reservation.id,
                start_time: @reservation.start_time,
                end_time: @reservation.end_time,
                status: @reservation.status
              }
            }
          }
          format.html { 
            redirect_to admin_reservations_calendar_path, 
            notice: "予約を更新しました" 
          }
        end
      else
        Rails.logger.error "❌ Reservation update failed: #{@reservation.errors.full_messages}"
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: @reservation.errors.full_messages.join(', ') 
            }, status: :unprocessable_entity 
          }
          format.html { 
            redirect_to admin_reservations_calendar_path, 
            alert: "予約の更新に失敗しました: #{@reservation.errors.full_messages.join(', ')}" 
          }
        end
      end

    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found: ID #{params[:id]}"
      respond_to do |format|
        format.json { 
          render json: { success: false, error: "予約が見つかりません" }, 
          status: :not_found 
        }
        format.html { 
          redirect_to admin_reservations_calendar_path, 
          alert: "予約が見つかりません" 
        }
      end
    end
  end

  def destroy
    Rails.logger.info "🗑️ DELETE request for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.find(params[:id])
      Rails.logger.info "✅ Found reservation: #{@reservation.name}"
      
      @reservation.destroy!
      Rails.logger.info "✅ Reservation destroyed successfully"
  
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約を削除しました。" }
        format.json { 
          render json: { 
            success: true, 
            message: "予約を削除しました" 
          }, status: :ok
        }
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found: #{params[:id]}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "❌ 予約削除エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "削除中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "削除中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  def cancel
    Rails.logger.info "❌ CANCEL request for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.find(params[:id])
      Rails.logger.info "✅ Found reservation for cancel: #{@reservation.name}"
      
      if @reservation.cancellable?
        cancellation_reason = params[:cancellation_reason] || "管理者によるキャンセル"
        @reservation.cancel!(cancellation_reason)
        Rails.logger.info "✅ Reservation cancelled successfully"
        
        respond_to do |format|
          format.html { redirect_to admin_reservations_calendar_path, notice: "予約をキャンセルしました。" }
          format.json { 
            render json: { 
              success: true, 
              message: "予約をキャンセルしました",
              reservation_id: @reservation.id
            }, status: :ok
          }
        end
      else
        Rails.logger.warn "⚠️ Reservation not cancellable: #{@reservation.status}"
        respond_to do |format|
          format.html { redirect_to admin_reservations_calendar_path, alert: "この予約はキャンセルできません。" }
          format.json { 
            render json: { 
              success: false, 
              error: "この予約はキャンセルできません" 
            }, status: :unprocessable_entity 
          }
        end
      end
      
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found for cancel: #{params[:id]}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "❌ 予約キャンセルエラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "キャンセル中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "キャンセル中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  def update_individual_interval
    Rails.logger.info "🔧 Updating individual interval for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.find(params[:id])
      new_interval = params[:individual_interval_minutes]&.to_i
      
      Rails.logger.info "📏 Current interval: #{@reservation.effective_interval_minutes}分, New interval: #{new_interval}分"
      
      # バリデーション
      if new_interval && (new_interval < 0 || new_interval > 120)
        return render json: { 
          success: false, 
          error: "インターバル時間は0分から120分の間で設定してください" 
        }, status: :unprocessable_entity
      end
      
      # インターバル時間を設定
      @reservation.set_individual_interval!(new_interval)
      
      Rails.logger.info "✅ Individual interval updated successfully"
      
      respond_to do |format|
        format.json {
          render json: {
            success: true,
            message: @reservation.has_individual_interval? ? 
              "インターバルを#{@reservation.individual_interval_minutes}分に設定しました" :
              "システム設定（#{ApplicationSetting.current.reservation_interval_minutes}分）に戻しました",
            reservation: {
              id: @reservation.id,
              individual_interval_minutes: @reservation.individual_interval_minutes,
              effective_interval_minutes: @reservation.effective_interval_minutes,
              has_individual_interval: @reservation.has_individual_interval?,
              interval_description: @reservation.interval_description,
              interval_setting_type: @reservation.interval_setting_type
            }
          }
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found: #{params[:id]}"
      render json: { 
        success: false, 
        error: "予約が見つかりません" 
      }, status: :not_found
      
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Individual interval update failed: #{e.record.errors.full_messages}"
      render json: { 
        success: false, 
        error: e.record.errors.full_messages.join(', ') 
      }, status: :unprocessable_entity
      
    rescue => e
      Rails.logger.error "❌ Individual interval update error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        success: false, 
        error: "インターバル更新中にエラーが発生しました: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  # 個別インターバル設定をリセット（システムデフォルトに戻す）
  def reset_individual_interval
    Rails.logger.info "🔄 Resetting individual interval for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.find(params[:id])
      @reservation.reset_to_system_interval!
      
      Rails.logger.info "✅ Individual interval reset successfully"
      
      render json: {
        success: true,
        message: "システム設定（#{ApplicationSetting.current.reservation_interval_minutes}分）に戻しました",
        reservation: {
          id: @reservation.id,
          individual_interval_minutes: @reservation.individual_interval_minutes,
          effective_interval_minutes: @reservation.effective_interval_minutes,
          has_individual_interval: @reservation.has_individual_interval?,
          interval_description: @reservation.interval_description
        }
      }
      
    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        error: "予約が見つかりません" 
      }, status: :not_found
      
    rescue => e
      Rails.logger.error "❌ Individual interval reset error: #{e.message}"
      render json: { 
        success: false, 
        error: "リセット中にエラーが発生しました" 
      }, status: :internal_server_error
    end
  end

  private

  # ステータスに基づく色を返すメソッド
  def color_for_status(status)
    case status.to_s
    when 'tentative'
      '#ffc107'  # 黄色（仮予約）
    when 'confirmed'
      '#28a745'  # 緑色（確定）
    when 'cancelled'
      '#dc3545'  # 赤色（キャンセル）
    when 'completed'
      '#6c757d'  # グレー（完了）
    when 'no_show'
      '#fd7e14'  # オレンジ（無断欠席）
    else
      '#007bff'  # 青色（デフォルト）
    end
  end

  def reservation_params
    params.require(:reservation).permit(
      :name, :start_time, :end_time, :course, :note, :user_id, :status, :ticket_id,
      :recurring, :recurring_type, :recurring_until, :cancellation_reason,
      :individual_interval_minutes  # 追加
    )
  end

  def create_reservation_with_new_user
    Rails.logger.info "📝 Creating reservation with new user"
    
    new_user_name = params[:new_user][:name]
    new_user_phone = params[:new_user][:phone_number]
    new_user_email = params[:new_user][:email]
    
    # 新規ユーザー作成
    user = User.create!(
      name: new_user_name,
      phone_number: new_user_phone,
      email: new_user_email,
      birth_date: params[:new_user][:birth_date],
      address: params[:new_user][:address],
      admin_memo: params[:new_user][:admin_memo]
    )
    
    Rails.logger.info "👤 New user created: #{user.name} (ID: #{user.id})"
    
    reservation_attrs = reservation_params.merge(
      name: user.name,
      user: user
    )
    
    # 管理者用の制限なし作成を使用
    @reservation = Reservation.create_as_admin!(reservation_attrs)
    
    Rails.logger.info "✅ Reservation created successfully with new user by admin: ID=#{@reservation.id}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "新規ユーザーと予約を作成しました",
          reservation: {
            id: @reservation.id,
            title: @reservation.name,
            start: @reservation.start_time.iso8601,
            end: @reservation.end_time.iso8601,
            description: @reservation.course,
            status: @reservation.status
          }
        }, status: :created 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        notice: "新規ユーザーと予約を作成しました" 
      }
    end
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ User or reservation creation failed: #{e.record.errors.full_messages}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          errors: e.record.errors.full_messages,
          error: e.record.errors.full_messages.join(', ')
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        alert: "ユーザー・予約作成に失敗しました: #{e.record.errors.full_messages.join(', ')}" 
      }
    end
  end
  
  def create_reservation_with_existing_user
    Rails.logger.info "📝 Creating reservation with existing user"
    
    user_id = params[:reservation][:user_id]
    user = User.find(user_id)
    Rails.logger.info "👤 User found: #{user.name} (ID: #{user.id})"
    
    reservation_attrs = reservation_params.merge(
      name: user.name,
      user: user
    )
    
    Rails.logger.info "📝 Final reservation attributes: #{reservation_attrs.inspect}"
    
    # 管理者用の制限なし作成を使用
    @reservation = Reservation.create_as_admin!(reservation_attrs)
    
    Rails.logger.info "✅ Reservation created successfully by admin: ID=#{@reservation.id}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "予約を作成しました",
          reservation: {
            id: @reservation.id,
            title: @reservation.name,
            start: @reservation.start_time.iso8601,
            end: @reservation.end_time.iso8601,
            description: @reservation.course,
            status: @reservation.status
          }
        }, status: :created 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        notice: "予約を作成しました" 
      }
    end
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Reservation creation failed: #{e.record.errors.full_messages}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          errors: e.record.errors.full_messages,
          error: e.record.errors.full_messages.join(', ')
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        alert: "予約作成に失敗しました: #{e.record.errors.full_messages.join(', ')}" 
      }
    end
  end
end