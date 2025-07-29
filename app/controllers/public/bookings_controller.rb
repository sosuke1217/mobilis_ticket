# app/controllers/public/bookings_controller.rb の修正版

class Public::BookingsController < ApplicationController
  def new
    @reservation = Reservation.new
    @courses = [
      { name: '40分コース', duration: 40, price: 8000 },
      { name: '60分コース', duration: 60, price: 12000 },
      { name: '80分コース', duration: 80, price: 16000 }
    ]
    
    # 🆕 LINEユーザーの場合は情報を事前入力
    if params[:line_user_id].present?
      user = User.find_by(line_user_id: params[:line_user_id])
      if user
        @user_info = {
          name: user.name,
          phone_number: user.phone_number,
          email: user.email,
          address: user.address
        }
      end
    end
  end

  # 空き時間取得用のAPIエンドポイント
  def available_times
    date = Date.parse(params[:date])
    duration = params[:duration].to_i
    
    available_slots = get_available_time_slots(date, duration)
    
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
    render json: { success: false, error: e.message }
  end

  def create
    @user = find_or_create_user
    return render :new, status: :unprocessable_entity unless @user.persisted?

    @reservation = build_reservation(@user)
    
    # 予約時間の重複チェック
    if time_conflict_exists?(@reservation)
      flash[:alert] = '選択された時間は既に予約が入っています。別の時間をお選びください。'
      @courses = load_courses
      return render :new, status: :unprocessable_entity
    end
    
    if @reservation.save
      # LINE通知を送信
      send_booking_notification(@reservation) if @reservation.user.line_user_id
      
      # 管理者への通知
      notify_admin(@reservation)
      
      redirect_to public_booking_path(@reservation), 
                  notice: 'ご予約リクエストを承りました。確認のご連絡をお待ちください。'
    else
      @courses = load_courses
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @reservation = Reservation.find(params[:id])
  end

  def cancel
    @reservation = Reservation.find(params[:id])
    
    if @reservation.cancellable?
      @reservation.cancel!('お客様都合によるキャンセル')
      
      # LINE通知
      send_cancellation_notification(@reservation) if @reservation.user.line_user_id
      
      redirect_to public_booking_path(@reservation), 
                  notice: 'ご予約をキャンセルいたしました。'
    else
      redirect_to public_booking_path(@reservation), 
                  alert: 'この予約はキャンセルできません。'
    end
  end

  private

  # 空き時間スロットを取得
  def get_available_time_slots(date, duration)
    # 営業時間の設定
    opening_time = Time.zone.parse("#{date} 10:00")
    closing_time = Time.zone.parse("#{date} 19:00")
    
    # インターバル時間を取得
    interval_minutes = Reservation.interval_minutes
    
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
      end
      
      current_time += slot_interval
    end
    
    available_slots
  end

  def time_slot_available_with_interval?(start_time, end_time)
    interval_minutes = Reservation.interval_minutes
    
    # インターバルを考慮した重複チェック
    overlapping_reservations = Reservation.active.where(
      '(start_time - INTERVAL ? MINUTE) < ? AND (end_time + INTERVAL ? MINUTE) > ?',
      interval_minutes, end_time, interval_minutes, start_time
    )
    
    overlapping_reservations.empty?
  end

  # 指定時間帯が空いているかチェック
  def time_slot_available?(start_time, end_time)
    # アクティブな予約（キャンセル以外）を検索
    overlapping_reservations = Reservation.active
      .where('start_time < ? AND end_time > ?', end_time, start_time)
    
    overlapping_reservations.empty?
  end

  # 予約時間の重複チェック
  def time_conflict_exists?(reservation)
    return false unless reservation.start_time && reservation.end_time
    
    Reservation.active
      .where.not(id: reservation.id)
      .where('start_time < ? AND end_time > ?', reservation.end_time, reservation.start_time)
      .exists?
  end

  def find_or_create_user
    phone = booking_params[:phone_number]
    
    user = User.find_by(phone_number: phone)
    return user if user

    # 新規ユーザー作成
    User.create(user_attributes)
  end

  def build_reservation(user)
    reservation = Reservation.new
    reservation.user = user
    reservation.name = user.name
    reservation.status = :tentative  # 仮予約
    reservation.course = booking_params[:course]
    reservation.note = booking_params[:notes]
    
    # 選択された時間を解析してstart_timeとend_timeを設定
    if booking_params[:selected_datetime].present?
      reservation.start_time = Time.zone.parse(booking_params[:selected_datetime])
      duration = course_duration(reservation.course)
      reservation.end_time = reservation.start_time + duration.minutes
    end
    
    reservation
  end

  def send_booking_notification(reservation)
    LineBookingNotifier.new_booking_request(reservation)
  rescue => e
    Rails.logger.error "LINE通知エラー: #{e.message}"
  end

  def notify_admin(reservation)
    AdminNotificationJob.perform_later(reservation)
  rescue => e
    Rails.logger.error "管理者通知エラー: #{e.message}"
  end

  def booking_params
    params.require(:booking).permit(
      :name, :phone_number, :email, :address, :building_info,
      :course, :selected_datetime, :notes, :access_notes
    )
  end

  def user_attributes
    {
      name: booking_params[:name],
      phone_number: booking_params[:phone_number],
      email: booking_params[:email],
      address: booking_params[:address]
    }
  end

  def course_duration(course)
    case course
    when '40分コース' then 40
    when '60分コース' then 60
    when '80分コース' then 80
    else 60
    end
  end

  def load_courses
    [
      { name: '40分コース', duration: 40, price: 8000 },
      { name: '60分コース', duration: 60, price: 12000 },
      { name: '80分コース', duration: 80, price: 16000 }
    ]
  end
end