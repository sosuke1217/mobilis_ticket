class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user! # 管理者ログイン制限（必要に応じて）

  def calendar
  end
  
  def index
    @reservations = Reservation.order(start_time: :asc)
  
    respond_to do |format|
      format.html
      format.json do
        render json: @reservations.map { |r|
          {
            id: r.id,
            title: r.name,
            start: r.start_time,
            end: r.end_time,
            description: r.course,
            color: color_for_course(r.course),
            user_id: r.user_id
          }
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
    # 新規ユーザー作成が必要かチェック
    if params[:new_user].present?
      create_reservation_with_new_user
    else
      create_reservation_with_existing_user
    end
  end
  
  def available_slots
    date = Date.parse(params[:date])
    @slots = Reservation.available_slots_for(date)
  
    render partial: "available_slots", locals: { slots: @slots }
  end

  def destroy
    begin
      @reservation = Reservation.find(params[:id])
      @reservation.destroy
  
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約を削除しました。" }
        format.json { 
          if @reservation.destroyed?
            render json: { success: true, message: "予約を削除しました" }, status: :ok
          else
            render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity
          end
        }
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "予約削除エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "削除中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "削除中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
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
      
      # ドラッグ&ドロップからのリクエスト（時間のみ更新）の場合
      if drag_drop_request?
        # start_timeとend_timeのみを更新
        update_params = drag_drop_params
        
        # コースに基づいた終了時間の自動計算をスキップ
        # 手動でend_timeが指定されている場合はそれを使用
        if update_params[:end_time].blank? && update_params[:start_time].present?
          # end_timeが指定されていない場合は、既存のコースから計算
          start_time = Time.zone.parse(update_params[:start_time])
          duration = case @reservation.course
                     when "40分" then 40
                     when "60分" then 60
                     when "80分" then 80
                     else 60
                     end
          update_params[:end_time] = (start_time + duration.minutes).iso8601
        end
        
        # 時間の重複チェック
        if time_conflict_exists?(update_params, @reservation.id)
          respond_to do |format|
            format.json { render json: { success: false, errors: ["この時間帯には既に別の予約が入っています"] }, status: :unprocessable_entity }
          end
          return
        end
        
        Rails.logger.info "🕐 ドラッグ&ドロップによる時間更新: #{@reservation.name} -> #{update_params[:start_time]}"
        
        if @reservation.update(update_params)
          respond_to do |format|
            format.json { render json: { success: true, message: "予約時間を更新しました" } }
          end
        else
          respond_to do |format|
            format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      else
        # 通常のフォームからの更新
        if @reservation.update(reservation_params)
          respond_to do |format|
            format.json { render json: { success: true } }
            format.html { redirect_to admin_reservations_calendar_path, notice: "予約を更新しました" }
          end
        else
          respond_to do |format|
            format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
            format.html { render :edit, status: :unprocessable_entity }
          end
        end
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "予約更新エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "更新中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "更新中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  def cancel
    begin
      @reservation = Reservation.find(params[:id])
      
      if @reservation.cancellable?
        cancellation_reason = params[:cancellation_reason] || "管理者によるキャンセル"
        @reservation.cancel!(cancellation_reason)
        
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
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "予約キャンセルエラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "キャンセル中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "キャンセル中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
    end
  end
  
  # ステータス変更メソッド
  def change_status
    begin
      @reservation = Reservation.find(params[:id])
      new_status = params[:status]
      
      case new_status
      when 'confirmed'
        @reservation.update!(status: :confirmed)
        message = "予約を確定しました"
      when 'tentative'
        @reservation.update!(status: :tentative)
        message = "予約を仮予約に変更しました"
      when 'completed'
        @reservation.complete!
        message = "予約を完了にしました"
      when 'no_show'
        @reservation.mark_no_show!
        message = "無断キャンセルとして記録しました"
      else
        raise ArgumentError, "無効なステータスです: #{new_status}"
      end
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, notice: message }
        format.json { 
          render json: { 
            success: true, 
            message: message,
            status: @reservation.status,
            status_text: @reservation.status_text
          }
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "ステータス変更エラー: #{e.message}"
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "ステータス変更中にエラーが発生しました。" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end
  
  # 繰り返し予約作成メソッド
  def create_recurring
    begin
      @reservation = Reservation.find(params[:id])
      recurring_until = Date.parse(params[:recurring_until])
      recurring_type = params[:recurring_type] # 'weekly' or 'monthly'
      
      @reservation.update!(
        recurring: true,
        recurring_type: recurring_type,
        recurring_until: recurring_until
      )
      
      @reservation.create_recurring_reservations!
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, notice: "繰り返し予約を作成しました。" }
        format.json { 
          render json: { 
            success: true, 
            message: "繰り返し予約を作成しました",
            parent_id: @reservation.id
          }
        }
      end
      
    rescue Date::Error
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "日付の形式が正しくありません。" }
        format.json { render json: { success: false, error: "日付の形式が正しくありません" }, status: :unprocessable_entity }
      end
    rescue => e
      Rails.logger.error "繰り返し予約作成エラー: #{e.message}"
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "繰り返し予約の作成中にエラーが発生しました。" }
        format.json { render json: { success: false, error: e.message }, status: :internal_server_error }
      end
    end
  end
  
  # app/controllers/admin/reservations_controller.rb に追加するメソッド

  def send_email
    begin
      @reservation = Reservation.find(params[:id])
      email_type = params[:email_type]
      
      unless @reservation.user&.email.present?
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: "ユーザーのメールアドレスが登録されていません" 
            }, status: :unprocessable_entity 
          }
        end
        return
      end
      
      case email_type
      when 'confirmation'
        ReservationMailer.confirmation(@reservation).deliver_now
        @reservation.update!(confirmation_sent_at: Time.current)
        message = "確認メールを送信しました"
        
      when 'reminder'
        ReservationMailer.reminder(@reservation).deliver_now
        @reservation.update!(reminder_sent_at: Time.current)
        message = "リマインダーメールを送信しました"
        
      when 'cancellation'
        ReservationMailer.cancellation_notification(@reservation).deliver_now
        message = "キャンセル通知メールを送信しました"
        
      else
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: "無効なメールタイプです: #{email_type}" 
            }, status: :unprocessable_entity 
          }
        end
        return
      end
      
      Rails.logger.info "📧 [EMAIL] #{email_type} sent to #{@reservation.user.email} for reservation #{@reservation.id}"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            message: message,
            email_type: email_type,
            sent_at: Time.current.iso8601
          }
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue Net::SMTPError => e
      Rails.logger.error "📧 [EMAIL ERROR] SMTP error: #{e.message}"
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "メール送信に失敗しました（SMTP エラー）" 
          }, status: :internal_server_error 
        }
      end
    rescue => e
      Rails.logger.error "📧 [EMAIL ERROR] Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "メール送信中にエラーが発生しました: #{e.message}" 
          }, status: :internal_server_error 
        }
      end
    end
  end

  # JSONレスポンス用のindex修正
  def index
    @reservations = Reservation.includes(:user, :ticket).order(start_time: :asc)

    respond_to do |format|
      format.html
      format.json do
        render json: @reservations.map { |r|
          {
            id: r.id,
            title: r.name,
            start: r.start_time,
            end: r.end_time,
            description: r.course,
            color: r.status_color,
            textColor: text_color_for_status(r.status),
            user_id: r.user_id,
            status: r.status,
            recurring: r.recurring,
            recurring_type: r.recurring_type,
            recurring_until: r.recurring_until,
            confirmation_sent_at: r.confirmation_sent_at,
            reminder_sent_at: r.reminder_sent_at,
            cancelled_at: r.cancelled_at,
            cancellation_reason: r.cancellation_reason
          }
        }
      end
    end
  end

  # 繰り返し予約のキャンセル
  def cancel_recurring
    begin
      @reservation = Reservation.find(params[:id])
      
      if @reservation.recurring?
        # 親予約の繰り返し設定を無効化
        @reservation.update!(recurring: false)
        
        # 未来の子予約をキャンセル
        cancelled_count = @reservation.child_reservations
          .where('start_time > ?', Time.current)
          .active
          .update_all(
            status: :cancelled,
            cancelled_at: Time.current,
            cancellation_reason: '親予約の繰り返し設定停止によるキャンセル'
          )
        
        Rails.logger.info "🔄 [RECURRING] Cancelled #{cancelled_count} future reservations for parent #{@reservation.id}"
        
        respond_to do |format|
          format.json { 
            render json: { 
              success: true, 
              message: "繰り返し予約を停止しました（#{cancelled_count}件の予約をキャンセル）",
              cancelled_count: cancelled_count
            }
          }
        end
      else
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: "この予約は繰り返し予約ではありません" 
            }, status: :unprocessable_entity 
          }
        end
      end
      
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "繰り返し予約キャンセルエラー: #{e.message}"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "繰り返し予約の停止中にエラーが発生しました: #{e.message}" 
          }, status: :internal_server_error 
        }
      end
    end
  end

  # 子予約一覧取得
  def child_reservations
    begin
      @reservation = Reservation.find(params[:id])
      @child_reservations = @reservation.child_reservations
        .order(start_time: :asc)
        .includes(:user)
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true,
            reservations: @child_reservations.map { |r|
              {
                id: r.id,
                name: r.name,
                start_time: r.start_time,
                end_time: r.end_time,
                status: r.status,
                course: r.course
              }
            }
          }
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    end
  end

  # 予約詳細取得（JSON用）
  def show
    begin
      @reservation = Reservation.find(params[:id])
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path }
        format.json { 
          render json: { 
            success: true,
            reservation: {
              id: @reservation.id,
              name: @reservation.name,
              start_time: @reservation.start_time,
              end_time: @reservation.end_time,
              course: @reservation.course,
              note: @reservation.note,
              status: @reservation.status,
              user_id: @reservation.user_id,
              recurring: @reservation.recurring,
              recurring_type: @reservation.recurring_type,
              recurring_until: @reservation.recurring_until,
              cancelled_at: @reservation.cancelled_at,
              cancellation_reason: @reservation.cancellation_reason,
              confirmation_sent_at: @reservation.confirmation_sent_at,
              reminder_sent_at: @reservation.reminder_sent_at,
              created_at: @reservation.created_at,
              updated_at: @reservation.updated_at
            }
          }
        }
      end
      
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    end
  end

  # 強化されたcreate_recurringメソッド
  def create_recurring
    begin
      @reservation = Reservation.find(params[:id])
      recurring_until = Date.parse(params[:recurring_until])
      recurring_type = params[:recurring_type]
      options = params[:options] || {}
      
      # オプションの取得
      skip_holidays = options[:skip_holidays] == true
      auto_confirm = options[:auto_confirm] != false # デフォルトはtrue
      max_reservations = [options[:max_reservations].to_i, 100].min.positive? ? [options[:max_reservations].to_i, 100].min : 50
      reminder_days = options[:reminder_days].to_i.clamp(0, 7)
      
      # バリデーション
      if recurring_until <= Date.current
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: "終了日は今日より後の日付を選択してください" 
            }, status: :unprocessable_entity 
          }
        end
        return
      end
      
      created_count = 0
      errors = []
      
      ActiveRecord::Base.transaction do
        # 親予約を繰り返し予約として設定
        @reservation.update!(
          recurring: true,
          recurring_type: recurring_type,
          recurring_until: recurring_until
        )
        
        current_date = @reservation.start_time
        
        while current_date.to_date <= recurring_until && created_count < max_reservations
          # 次の日付を計算
          if recurring_type == 'weekly'
            current_date += 1.week
          elsif recurring_type == 'monthly'
            current_date += 1.month
          else
            break
          end
          
          # 祝日チェック（オプション）
          if skip_holidays && holiday?(current_date.to_date)
            next
          end
          
          # 重複チェック
          if Reservation.active
              .where('start_time < ? AND end_time > ?', 
                    current_date + (@reservation.end_time - @reservation.start_time), 
                    current_date)
              .exists?
            errors << "#{current_date.strftime('%Y/%m/%d %H:%M')} は既に予約が入っています"
            next
          end
          
          # 子予約を作成
          child_reservation = @reservation.child_reservations.build(
            name: @reservation.name,
            start_time: current_date,
            end_time: current_date + (@reservation.end_time - @reservation.start_time),
            course: @reservation.course,
            note: @reservation.note,
            user: @reservation.user,
            ticket: @reservation.ticket,
            status: auto_confirm ? :confirmed : :tentative
          )
          
          if child_reservation.save
            created_count += 1
            
            # 確認メール送信（オプション）
            if @reservation.user&.email.present?
              begin
                ReservationMailer.confirmation(child_reservation).deliver_later
                child_reservation.update_column(:confirmation_sent_at, Time.current)
              rescue => email_error
                Rails.logger.warn "確認メール送信失敗: #{email_error.message}"
              end
            end
            
            Rails.logger.info "🔄 [RECURRING] Created child reservation #{child_reservation.id} for #{current_date}"
          else
            errors << "#{current_date.strftime('%Y/%m/%d %H:%M')} の予約作成に失敗: #{child_reservation.errors.full_messages.join(', ')}"
          end
        end
      end
      
      Rails.logger.info "🔄 [RECURRING] Created #{created_count} reservations for parent #{@reservation.id}"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            message: "繰り返し予約を作成しました",
            created_count: created_count,
            errors: errors,
            child_count: @reservation.child_reservations.count
          }
        }
      end
      
    rescue Date::Error
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "日付の形式が正しくありません" 
          }, status: :unprocessable_entity 
        }
      end
    rescue => e
      Rails.logger.error "繰り返し予約作成エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "繰り返し予約の作成中にエラーが発生しました: #{e.message}" 
          }, status: :internal_server_error 
        }
      end
    end
  end

  # 一括ステータス変更
  def bulk_status_change
    begin
      reservation_ids = params[:reservation_ids]
      new_status = params[:status]
      
      if reservation_ids.blank? || new_status.blank?
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: "予約IDまたはステータスが指定されていません" 
            }, status: :unprocessable_entity 
          }
        end
        return
      end
      
      reservations = Reservation.where(id: reservation_ids)
      updated_count = 0
      errors = []
      
      reservations.each do |reservation|
        case new_status
        when 'confirmed'
          if reservation.update(status: :confirmed)
            updated_count += 1
          else
            errors << "ID #{reservation.id}: #{reservation.errors.full_messages.join(', ')}"
          end
        when 'cancelled'
          begin
            reservation.cancel!(params[:cancellation_reason] || "一括キャンセル")
            updated_count += 1
          rescue => e
            errors << "ID #{reservation.id}: #{e.message}"
          end
        else
          if reservation.update(status: new_status)
            updated_count += 1
          else
            errors << "ID #{reservation.id}: #{reservation.errors.full_messages.join(', ')}"
          end
        end
      end
      
      Rails.logger.info "📊 [BULK] Updated #{updated_count}/#{reservations.count} reservations to #{new_status}"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            message: "#{updated_count}件の予約を更新しました",
            updated_count: updated_count,
            total_count: reservations.count,
            errors: errors
          }
        }
      end
      
    rescue => e
      Rails.logger.error "一括ステータス変更エラー: #{e.message}"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "一括更新中にエラーが発生しました: #{e.message}" 
          }, status: :internal_server_error 
        }
      end
    end
  end

  private

  # 祝日判定（簡易版）
  def holiday?(date)
    # 日本の祝日判定ロジック
    # 実際の実装では、祝日ライブラリ（holidaysなど）を使用することを推奨
    weekday = date.wday
    
    # 土日は休日として扱う
    return true if weekday == 0 || weekday == 6
    
    # 固定祝日の例（実際にはもっと複雑）
    national_holidays = [
      [1, 1],   # 元日
      [2, 11],  # 建国記念の日
      [4, 29],  # 昭和の日
      [5, 3],   # 憲法記念日
      [5, 4],   # みどりの日
      [5, 5],   # こどもの日
      [8, 11],  # 山の日
      [11, 3],  # 文化の日
      [11, 23], # 勤労感謝の日
      [12, 23]  # 天皇誕生日
    ]
    
    national_holidays.include?([date.month, date.day])
  end
    
  private

  def reservation_params
    params.require(:reservation).permit(
      :name, :start_time, :end_time, :course, :note, :user_id, :status, :ticket_id,
      :recurring, :recurring_type, :recurring_until, :cancellation_reason
    )
  end
  
  # ドラッグ&ドロップリクエストかどうかを判定
  def drag_drop_request?
    # JSONリクエストで、start_timeまたはend_timeのみが送信されている場合
    request.format.json? && 
    params[:reservation] && 
    (params[:reservation].keys & ['start_time', 'end_time']).any? &&
    (params[:reservation].keys & ['name', 'course', 'note']).empty?
  end
  
  # ドラッグ&ドロップ用のパラメータ
  def drag_drop_params
    params.require(:reservation).permit(:start_time, :end_time)
  end
  
  # 時間の重複チェック
  def time_conflict_exists?(update_params, current_reservation_id)
    start_time = Time.zone.parse(update_params[:start_time])
    end_time = update_params[:end_time].present? ? Time.zone.parse(update_params[:end_time]) : nil
    
    return false unless end_time
    
    Reservation.where.not(id: current_reservation_id)
               .where('start_time < ? AND end_time > ?', end_time, start_time)
               .exists?
  end

  def color_for_course(course)
    case course
    when "40分" then "#5cb85c"  # 緑
    when "60分" then "#0275d8"  # 青
    when "80分" then "#d9534f"  # 赤
    else "#6c757d"              # グレー（未指定）
    end
  end

  def create_reservation_with_new_user
    Rails.logger.info "🆕 Creating reservation with new user"
    
    begin
      ActiveRecord::Base.transaction do
        # 新規ユーザーを作成
        @user = User.new(new_user_params)
        
        unless @user.save
          Rails.logger.error "❌ User creation failed: #{@user.errors.full_messages}"
          respond_to do |format|
            format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
            format.html { redirect_to admin_reservations_calendar_path, alert: "ユーザー作成に失敗しました: #{@user.errors.full_messages.join(', ')}" }
          end
          return
        end
        
        Rails.logger.info "✅ New user created: #{@user.name} (ID: #{@user.id})"
        
        # 予約を作成（ユーザーIDを設定）
        @reservation = Reservation.new(reservation_params)
        @reservation.user_id = @user.id
        
        unless @reservation.save
          Rails.logger.error "❌ Reservation creation failed: #{@reservation.errors.full_messages}"
          raise ActiveRecord::Rollback
        end
        
        Rails.logger.info "✅ New reservation created: #{@reservation.name} for #{@user.name}"
        
        respond_to do |format|
          format.json { render json: { success: true, message: "新規ユーザーと予約を作成しました", user_id: @user.id, reservation_id: @reservation.id }, status: :created }
          format.html { redirect_to admin_reservations_calendar_path, notice: "新規ユーザー「#{@user.name}」と予約を作成しました" }
        end
      end
      
    rescue => e
      Rails.logger.error "❌ Transaction failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { render json: { success: false, errors: ["予約作成中にエラーが発生しました: #{e.message}"] }, status: :internal_server_error }
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約作成中にエラーが発生しました" }
      end
    end
  end
  
  def create_reservation_with_existing_user
    Rails.logger.info "📝 Creating reservation with existing user"
    
    @reservation = Reservation.new(reservation_params)
  
    if @reservation.save
      Rails.logger.info "✅ Reservation created: #{@reservation.name}"
      
      respond_to do |format|
        format.json { render json: { success: true, message: "予約を作成しました" }, status: :created }
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約が完了しました" }
      end
    else
      Rails.logger.error "❌ Reservation creation failed: #{@reservation.errors.full_messages}"
      
      respond_to do |format|
        format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end
  
  def new_user_params
    params.require(:new_user).permit(:name, :phone_number, :email, :birth_date, :address, :admin_memo, :postal_code)
  end

  def text_color_for_status(status)
    case status
    when 'tentative'
      '#000000'  # 黄色背景には黒文字
    else
      '#FFFFFF'  # その他は白文字
    end
  end

end