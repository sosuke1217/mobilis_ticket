// app/javascript/calendar/calendar_core.js の最終修正版

import { showMessage } from './utils.js';

// システム設定（HTMLから取得）
const systemSettings = {
  businessHoursStart: parseInt(document.querySelector('meta[name="business-hours-start"]')?.content || '10'),
  businessHoursEnd: parseInt(document.querySelector('meta[name="business-hours-end"]')?.content || '21'),
  slotIntervalMinutes: parseInt(document.querySelector('meta[name="slot-interval"]')?.content || '10'),
  reservationIntervalMinutes: parseInt(document.querySelector('meta[name="reservation-interval"]')?.content || '15'),
  sundayClosed: document.querySelector('meta[name="sunday-closed"]')?.content === 'true'
};

// 営業時間を動的に取得する関数（シフト設定を考慮）
async function getBusinessHoursForDate(date) {
  console.log(`🔍 getBusinessHoursForDate called with date:`, date);
  
  try {
    const dateStr = date.toISOString().split('T')[0];
    
    // シフト設定を取得
    const response = await fetch(`/admin/shifts/for_date?date=${dateStr}`);
    const data = await response.json();
    
    if (data.success && data.shift) {
      console.log(`📅 Found shift for ${dateStr}:`, data.shift);
      
      // 休業中の場合は営業時間なし
      if (data.shift.shift_type === 'closed') {
        console.log(`🚫 Shift is closed for ${dateStr}`);
        return { 
          start: null, 
          end: null, 
          shift: data.shift,
          isClosed: true
        };
      }
      
      // 営業時間がある場合
      if (data.shift.start_time && data.shift.end_time) {
        const startHour = parseInt(data.shift.start_time.split(':')[0]);
        const endHour = parseInt(data.shift.end_time.split(':')[0]);
        console.log(`🕐 Shift business hours: ${startHour}:00-${endHour}:00`);
        return { 
          start: startHour, 
          end: endHour, 
          shift: data.shift,
          isClosed: false
        };
      }
    }
    
    // シフト設定がない場合はデフォルト営業時間
    console.log(`🔄 No shift found for ${dateStr}, using default hours`);
    return { 
      start: systemSettings.businessHoursStart, 
      end: systemSettings.businessHoursEnd, 
      shift: null,
      isClosed: false
    };
    
  } catch (error) {
    console.error('❌ Error fetching shift data:', error);
    // エラーの場合はデフォルト営業時間
    return { 
      start: systemSettings.businessHoursStart, 
      end: systemSettings.businessHoursEnd, 
      shift: null,
      isClosed: false
    };
  }
}

// グリッドの背景色を動的に更新する関数（シフト設定を考慮）
async function updateGridBackgroundColors(date) {
  console.log(`🎨 updateGridBackgroundColors called with date:`, date);
  
  try {
    const businessHours = await getBusinessHoursForDate(date);
    const dateStr = date.toISOString().split('T')[0];
    
    console.log(`🎨 Business hours for ${dateStr}:`, businessHours);
    
    // 全てのスロットをリセット（背景色のみ）
    const allSlots = document.querySelectorAll('.fc-timegrid-slot');
    console.log(`🔄 Resetting ${allSlots.length} time slots`);
    
    allSlots.forEach(slot => {
      // 背景色のみをリセット、境界線は保持
      slot.style.backgroundColor = '';
      slot.style.opacity = '';
      slot.style.pointerEvents = '';
      slot.title = '';
    });
    
    // 休業中の場合は全てのスロットを暗く表示
    if (businessHours.isClosed) {
      console.log(`🚫 Setting all slots to closed state for ${dateStr}`);
      allSlots.forEach(slot => {
        slot.style.backgroundColor = 'rgba(220, 53, 69, 0.1)';
        slot.style.opacity = '0.3';
        slot.style.pointerEvents = 'none';
        slot.title = '休業日 - 予約不可';
      });
      
      // 休業日のラベルを追加
      const firstSlot = allSlots[0];
      if (firstSlot) {
        let closedLabel = firstSlot.querySelector('.closed-day-label');
        if (!closedLabel) {
          closedLabel = document.createElement('div');
          closedLabel.className = 'closed-day-label';
          closedLabel.style.cssText = `
            position: absolute;
            top: 5px;
            left: 5px;
            background: #dc3545;
            color: white;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: bold;
            z-index: 10;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
          `;
          closedLabel.textContent = '休業日';
          firstSlot.appendChild(closedLabel);
        }
      }
      
      console.log(`✅ Closed day styling applied for ${dateStr}`);
      return;
    }
    
    // 営業時間外のスロットを薄いグレーに設定
    for (let hour = 8; hour < businessHours.start; hour++) {
      const slots = document.querySelectorAll(`.fc-timegrid-slot[data-time^="${hour.toString().padStart(2, '0')}:"]`);
      console.log(`🌑 Setting ${slots.length} slots for hour ${hour} to light gray`);
      slots.forEach(slot => {
        slot.style.backgroundColor = '#f8f9fa';
        slot.style.opacity = '0.5';
        slot.style.pointerEvents = 'none';
        slot.title = '営業時間外 - 予約不可';
      });
    }
    
    // 営業時間後のスロットを薄いグレーに設定
    for (let hour = businessHours.end; hour <= 22; hour++) {
      const slots = document.querySelectorAll(`.fc-timegrid-slot[data-time^="${hour.toString().padStart(2, '0')}:"]`);
      console.log(`🌑 Setting ${slots.length} slots for hour ${hour} to light gray`);
      slots.forEach(slot => {
        slot.style.backgroundColor = '#f8f9fa';
        slot.style.opacity = '0.5';
        slot.style.pointerEvents = 'none';
        slot.title = '営業時間外 - 予約不可';
      });
    }
    
    // 営業時間内のスロットを明るく設定
    for (let hour = businessHours.start; hour < businessHours.end; hour++) {
      const slots = document.querySelectorAll(`.fc-timegrid-slot[data-time^="${hour.toString().padStart(2, '0')}:"]`);
      console.log(`☀️ Setting ${slots.length} slots for hour ${hour} to light background`);
      slots.forEach(slot => {
        slot.style.backgroundColor = '';
        slot.style.opacity = '1';
        slot.style.pointerEvents = 'auto';
        slot.title = '営業時間内 - 予約可能';
      });
    }
    
    // シフト情報のラベルを追加
    if (businessHours.shift) {
      const firstSlot = allSlots[0];
      if (firstSlot) {
        let shiftLabel = firstSlot.querySelector('.shift-info-label');
        if (!shiftLabel) {
          shiftLabel = document.createElement('div');
          shiftLabel.className = 'shift-info-label';
          shiftLabel.style.cssText = `
            position: absolute;
            top: 5px;
            right: 5px;
            background: #17a2b8;
            color: white;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: bold;
            z-index: 10;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
          `;
          shiftLabel.textContent = businessHours.shift.shift_type_display;
          firstSlot.appendChild(shiftLabel);
        }
      }
    }
    
    console.log(`✅ Grid colors updated successfully for ${dateStr}`);
    
  } catch (error) {
    console.error('❌ Error updating grid colors:', error);
  }
}

// インターバル表示用スタイル追加
function addIntervalStyles() {
  if (document.getElementById('interval-styles')) return;
  
  const style = document.createElement('style');
  style.id = 'interval-styles';
  style.textContent = `
    /* インターバル表示スタイル */
    .individual-interval .fc-event-title {
      font-weight: bold !important;
      font-style: italic !important;
    }
    
    .individual-interval {
      border-style: dashed !important;
      border-width: 2px !important;
      animation: pulse-individual 2s infinite;
    }
    
    @keyframes pulse-individual {
      0%, 100% { opacity: 0.8; }
      50% { opacity: 0.6; }
    }
    
    .system-interval {
      border-style: dashed !important;
      border-width: 1px !important;
    }
    
    /* 時間軸の線を確実に表示 - 強化版（最高優先度） */
    .fc-timegrid-slot {
      border-top: 1px solid #e9ecef !important; /* 基本の細い線 */
    }
    
    /* 30分刻みの境界線を強調（全ての時間で適用） */
    .fc-timegrid-slot[data-time$=":30:00"] {
      border-top: 2px solid #dee2e6 !important; /* 30分ごとの線 */
    }
    
    /* 1時間刻みの境界線をさらに強調（全ての時間で適用） */
    .fc-timegrid-slot[data-time$=":00:00"] {
      border-top: 3px solid #adb5bd !important; /* 1時間ごとの太い線 */
    }
    
    /* シフト設定の背景色を保持しながらグリッドラインを強制適用 */
    .fc-timegrid-slot[style*="background-color"] {
      border-top: 1px solid #e9ecef !important;
    }
    
    .fc-timegrid-slot[style*="background-color"][data-time$=":30:00"] {
      border-top: 2px solid #dee2e6 !important;
    }
    
    .fc-timegrid-slot[style*="background-color"][data-time$=":00:00"] {
      border-top: 3px solid #adb5bd !important;
    }
    
    /* 営業時間外でもグリッドラインを表示 */
    .fc-timegrid-slot[data-time^="08:"] {
      border-top: 1px solid #e9ecef !important;
    }
    
    .fc-timegrid-slot[data-time^="08:"][data-time$=":30:00"] {
      border-top: 2px solid #dee2e6 !important;
    }
    
    .fc-timegrid-slot[data-time^="08:"][data-time$=":00:00"] {
      border-top: 3px solid #adb5bd !important;
    }
    
    .fc-timegrid-slot[data-time^="09:"] {
      border-top: 1px solid #e9ecef !important;
    }
    
    .fc-timegrid-slot[data-time^="09:"][data-time$=":30:00"] {
      border-top: 2px solid #dee2e6 !important;
    }
    
    .fc-timegrid-slot[data-time^="09:"][data-time$=":00:00"] {
      border-top: 3px solid #adb5bd !important;
    }
    
    .fc-timegrid-slot[data-time^="21:"] {
      border-top: 1px solid #e9ecef !important;
    }
    
    .fc-timegrid-slot[data-time^="21:"][data-time$=":30:00"] {
      border-top: 2px solid #dee2e6 !important;
    }
    
    .fc-timegrid-slot[data-time^="21:"][data-time$=":00:00"] {
      border-top: 3px solid #adb5bd !important;
    }
    
    .fc-timegrid-slot[data-time^="22:"] {
      border-top: 1px solid #e9ecef !important;
    }
    
    .fc-timegrid-slot[data-time^="22:"][data-time$=":30:00"] {
      border-top: 2px solid #dee2e6 !important;
    }
    
    .fc-timegrid-slot[data-time^="22:"][data-time$=":00:00"] {
      border-top: 3px solid #adb5bd !important;
    }
    
    /* 今日のハイライトを確実に表示 */
    .fc-timegrid-now-indicator-line {
      border-color: #ff4444 !important;
      border-width: 2px !important;
      z-index: 5 !important;
    }
    
    .fc-timegrid-now-indicator-arrow {
      border-color: #ff4444 !important;
      border-width: 5px !important;
      z-index: 5 !important;
    }
    
    /* 利用可能時間スロットのスタイル */
    .available-slot {
      background-color: #d4edda !important;
      border: 1px solid #c3e6cb !important;
      border-radius: 4px !important;
      margin: 1px !important;
      padding: 2px !important;
    }
    
    /* カレンダーの基本スタイルを保持 */
    .fc-timegrid-slot-label {
      border-right: 1px solid #ddd !important;
    }
    
    .fc-timegrid-axis {
      border-right: 1px solid #ddd !important;
    }
  `;
  
  document.head.appendChild(style);
  console.log('✅ Interval styles added');
  
  // グリッドラインはCSSのみで常時表示
}

// グリッドライン関数を削除（CSSのみで常時表示）
window.applyGridLines = function() {
  // 何もしない（CSSのみで常時表示）
  console.log('🔧 Grid lines are handled by CSS only');
};

// グリッドラインの状態を確認するデバッグ関数
window.debugGridLines = function() {
  console.log('🔍 Debugging grid lines...');
  
  const allSlots = document.querySelectorAll('.fc-timegrid-slot');
  console.log(`🔍 Found ${allSlots.length} time slots`);
  
  let slotsWithBorders = 0;
  let slotsWithBackground = 0;
  
  allSlots.forEach((slot, index) => {
    const timeAttr = slot.getAttribute('data-time');
    const borderTop = slot.style.borderTop;
    const backgroundColor = slot.style.backgroundColor;
    
    if (borderTop && borderTop !== 'none') {
      slotsWithBorders++;
    }
    
    if (backgroundColor && backgroundColor !== '') {
      slotsWithBackground++;
    }
    
    if (index < 10) { // 最初の10個のスロットの詳細を表示
      console.log(`Slot ${index}: time=${timeAttr}, border=${borderTop}, bg=${backgroundColor}`);
    }
  });
  
  console.log(`📊 Summary: ${slotsWithBorders}/${allSlots.length} slots have borders, ${slotsWithBackground}/${allSlots.length} slots have background colors`);
  
  return {
    totalSlots: allSlots.length,
    slotsWithBorders,
    slotsWithBackground
  };
};

// 予約時間更新
function updateReservationTime(event, revertFunc) {
  const reservationData = {
    id: event.id,
    start_time: event.start.toISOString(),
    end_time: event.end.toISOString()
  };
  
  fetch(`/admin/reservations/${event.id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({ reservation: reservationData })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      console.log('✅ Reservation updated successfully');
      showMessage('予約時間を更新しました', 'success');
      window.pageCalendar.refetchEvents();
    } else {
      console.error('❌ Reservation update failed:', data.error);
      showMessage(data.error || '予約の更新に失敗しました', 'danger');
      if (revertFunc) revertFunc();
    }
  })
  .catch(error => {
    console.error('❌ Update request failed:', error);
    showMessage('更新中にエラーが発生しました', 'danger');
    if (revertFunc) revertFunc();
  });
}

// 🆕 シフト時間のハイライト機能（動的営業時間対応）
async function highlightShiftHours(date = new Date()) {
  console.log('🎨 Applying dynamic shift hour highlights...');
  
  try {
    const businessHours = await getBusinessHoursForDate(date);
    
    // 少し遅延させてDOMが確実に描画されてから実行
    setTimeout(() => {
      // 営業時間外の時間帯を薄く表示
      const timeSlots = document.querySelectorAll('.fc-timegrid-slot');
      
      timeSlots.forEach(slot => {
        const timeAttr = slot.getAttribute('data-time');
        if (!timeAttr) return;
        
        const hour = parseInt(timeAttr.split(':')[0]);
        
        // シフト設定に基づいて営業時間外を判定
        let isOutsideBusinessHours = false;
        
        if (businessHours.isClosed) {
          // 休業日の場合は全て営業時間外
          isOutsideBusinessHours = true;
        } else if (businessHours.start !== null && businessHours.end !== null) {
          // 営業時間が設定されている場合
          isOutsideBusinessHours = hour < businessHours.start || hour >= businessHours.end;
        } else {
          // デフォルト営業時間（10:00-21:00）を使用
          isOutsideBusinessHours = hour < 10 || hour >= 21;
        }
        
        if (isOutsideBusinessHours) {
          slot.style.backgroundColor = '#f8f9fa';
          slot.style.borderLeft = '3px solid #dee2e6';
          slot.style.opacity = '0.7';
          slot.style.pointerEvents = 'none';
          slot.title = '営業時間外 - 予約不可';
        } else {
          slot.style.backgroundColor = '';
          slot.style.borderLeft = '';
          slot.style.opacity = '1';
          slot.style.pointerEvents = 'auto';
          slot.title = '営業時間内 - 予約可能';
        }
      });
      
      // 営業時間の境界線を動的に設定
      if (businessHours.start !== null) {
        const startSlot = document.querySelector(`.fc-timegrid-slot[data-time="${businessHours.start.toString().padStart(2, '0')}:00:00"]`);
        if (startSlot) {
          startSlot.style.borderTop = '3px solid #28a745';
          startSlot.title = `営業開始時間 (${businessHours.start}:00)`;
        }
      }
      
      if (businessHours.end !== null) {
        const endSlot = document.querySelector(`.fc-timegrid-slot[data-time="${businessHours.end.toString().padStart(2, '0')}:00:00"]`);
        if (endSlot) {
          endSlot.style.borderTop = '3px solid #dc3545';
          endSlot.title = `営業終了時間 (${businessHours.end}:00)`;
        }
      }
      
      console.log('✅ Dynamic shift highlights applied successfully');
    }, 200);
    
  } catch (error) {
    console.error('❌ Error applying dynamic shift highlights:', error);
  }
}

// カレンダー初期化
export function initializeCalendar() {
  console.log('🔧 Starting calendar initialization...');
  
  const calendarEl = document.getElementById('calendar');
  if (!calendarEl) {
    console.error('❌ Calendar element not found');
    return;
  }

  console.log('🗓️ Initializing calendar with interval display...');
  
  // 既存のカレンダーインスタンスがあれば破棄
  if (window.pageCalendar) {
    console.log('🧹 Destroying existing calendar instance');
    try {
      window.pageCalendar.destroy();
    } catch (error) {
      console.warn('⚠️ Error destroying existing calendar:', error);
    }
    window.pageCalendar = null;
  }
  
  // DOM要素の参照もクリア
  const existingCalendarEl = document.getElementById('calendar');
  if (existingCalendarEl && existingCalendarEl._fullCalendarInstance) {
    console.log('🧹 Clearing DOM element calendar reference');
    delete existingCalendarEl._fullCalendarInstance;
  }
  
  // インターバル表示用スタイルを動的に追加
  addIntervalStyles();
  
  // FullCalendar利用可能性チェック
  console.log('🔍 Checking FullCalendar availability...');
  console.log('🔍 typeof FullCalendar:', typeof FullCalendar);
  console.log('🔍 window.FullCalendar:', window.FullCalendar);
  
  if (typeof FullCalendar === 'undefined' && typeof window.FullCalendar === 'undefined') {
    console.error('❌ FullCalendar not available, retrying...');
    // 少し待ってからリトライ
    setTimeout(() => {
      console.log('🔄 Retrying calendar initialization...');
      initializeCalendar();
    }, 500);
    return;
  }
  
  // window.FullCalendarが利用可能な場合はそれを使用
  const CalendarClass = typeof FullCalendar !== 'undefined' ? FullCalendar : window.FullCalendar;
  
  console.log('✅ FullCalendar is available, proceeding with initialization');
  
  try {
    // カレンダーインスタンスを作成
    const calendar = new CalendarClass.Calendar(calendarEl, {
      initialView: window.innerWidth < 768 ? 'timeGridDay' : 'timeGridWeek',
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay'
      },
      locale: 'ja',
      height: 'auto',
      editable: true,
      selectable: true,
      selectMirror: true,
      dayMaxEvents: true,
      weekends: !systemSettings.sundayClosed,
      
      // 営業時間の設定（22時まで表示）
      businessHours: {
        daysOfWeek: systemSettings.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
        startTime: '08:00:00',
        endTime: '22:00:00'
      },
      
      // スロット設定（22時台まで確実に表示）
      slotMinTime: '08:00:00',
      slotMaxTime: '22:00:00',
      slotDuration: `00:${systemSettings.slotIntervalMinutes.toString().padStart(2, '0')}:00`,
      slotLabelFormat: {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      },
      
      // 今日のハイライトを有効化
      nowIndicator: true,
      
      // イベントソース
      events: {
        url: '/admin/reservations.json',
        failure: function(error) {
          console.error('❌ Error loading events:', error);
          showMessage('カレンダーデータの読み込みに失敗しました', 'danger');
        },
        success: function(events) {
          console.log('✅ Events loaded successfully');
        }
      },
    
    // 日付クリック処理
    dateClick: async function(info) {
      console.log('📅 Date clicked:', info.dateStr);
      
      // シフト設定をチェック
      try {
        const businessHours = await getBusinessHoursForDate(info.date);
        
        // 休業日の場合は予約作成を制限
        if (businessHours.isClosed) {
          showMessage('この日は休業日のため予約できません', 'warning');
          return;
        }
        
        // 営業時間がない場合も予約作成を制限
        if (!businessHours.start || !businessHours.end) {
          showMessage('この日は営業時間が設定されていないため予約できません', 'warning');
          return;
        }
        
        // 営業時間内の場合のみ予約作成を許可
        if (window.openReservationModal) {
          window.openReservationModal(null, info.dateStr);
        }
        
      } catch (error) {
        console.error('❌ Error checking shift for date click:', error);
        // エラーの場合は予約作成を許可（フォールバック）
        if (window.openReservationModal) {
          window.openReservationModal(null, info.dateStr);
        }
      }
    },
    
    // イベントクリック処理
    eventClick: function(info) {
      const eventType = info.event.extendedProps.type;
      
      if (eventType === 'interval') {
        // インターバルイベントがクリックされた場合
        const reservationId = info.event.extendedProps.reservation_id;
        const intervalMinutes = info.event.extendedProps.interval_minutes;
        const isIndividual = info.event.extendedProps.is_individual;
        
        if (reservationId) {
          console.log(`🔗 Opening related reservation ${reservationId} from ${isIndividual ? 'individual' : 'system'} interval (${intervalMinutes}分)`);
          
          showMessage(
            `${isIndividual ? '個別設定' : 'システム設定'}のインターバル (${intervalMinutes}分) - 予約詳細を開きます`,
            isIndividual ? 'warning' : 'info'
          );
          
          if (window.openReservationModal) {
            window.openReservationModal(reservationId);
          }
        }
        return;
      }
      
      if (eventType === 'reservation' || !eventType) {
        console.log('📅 Opening reservation modal for ID:', info.event.id);
        if (window.openReservationModal) {
          window.openReservationModal(info.event.id);
        }
      }
    },
    
    // ドラッグ＆ドロップ処理
    eventDrop: function(info) {
      const eventType = info.event.extendedProps.type;
      
      if (eventType === 'interval') {
        info.revert();
        showMessage('インターバル時間は移動できません', 'warning');
        return;
      }
      
      if (eventType === 'reservation' || !eventType) {
        console.log('🔄 Moving reservation:', info.event.id);
        updateReservationTime(info.event, info.revert);
      }
    },
    
    // リサイズ処理
    eventResize: function(info) {
      const eventType = info.event.extendedProps.type;
      
      if (eventType === 'interval') {
        info.revert();
        showMessage('インターバル時間は変更できません', 'warning');
        return;
      }
      
      if (eventType === 'reservation' || !eventType) {
        console.log('🔄 Resizing reservation:', info.event.id);
        updateReservationTime(info.event, info.revert);
      }
    },
    
    // 🆕 カレンダー描画完了後の処理
    datesSet: function(info) {
      console.log('📅 Dates set callback triggered:', info.startStr, 'to', info.endStr);
      
      // メインカレンダーの日付が変更されたときにミニカレンダーも同期
      const currentDate = info.start;
      if (typeof monthCalendar !== 'undefined') {
        monthCalendar.gotoDate(currentDate);
        updateMonthYearDisplay();
      }
      
      // 表示されている日付のシフト情報と動的ハイライトを更新
      setTimeout(() => {
        updateGridBackgroundColors(currentDate);
        highlightShiftHours(currentDate);
      }, 100);
    },
    
    eventDidMount: function(info) {
      // イベント表示時の処理
      const eventType = info.event.extendedProps.type;
      if (eventType === 'interval') {
        info.el.style.cursor = 'pointer';
      }
    },
    
    // ビュー変更時の処理
    viewDidMount: function(info) {
      console.log('📅 View mounted:', info.view.type);
      
      // ビュー変更時にシフト情報と動的ハイライトを更新
      setTimeout(() => {
        const currentDate = info.view.currentStart;
        updateGridBackgroundColors(currentDate);
        highlightShiftHours(currentDate);
      }, 100);
    }
  });
  
  console.log('📅 Calling calendar.render()');
  calendar.render();
  
  // グローバル変数として設定（即座に実行）
  window.pageCalendar = calendar;
  console.log('✅ pageCalendar set as global variable');
  
  // DOM要素にも参照を保存（バックアップとして）
  calendarEl._fullCalendarInstance = calendar;
  
  // カレンダーインスタンスの検証
  const verifyInstance = getCalendarInstance();
  if (verifyInstance) {
    console.log('✅ Calendar instance verification successful');
  } else {
    console.error('❌ Calendar instance verification failed');
  }
  
  console.log('✅ Calendar initialization completed successfully');
  
  // 初期化完了後にグリッドラインと動的ハイライトを適用
  setTimeout(() => {
    applyGridLines();
    
    // 動的シフトハイライトを適用
    highlightShiftHours(new Date());
    
    // 22時台のスロットが存在するか確認
    setTimeout(() => {
      const slots22 = document.querySelectorAll('.fc-timegrid-slot[data-time^="22:"]');
      console.log(`🔍 22時台のスロット数: ${slots22.length}`);
      
      if (slots22.length === 0) {
        console.warn('⚠️ 22時台のスロットが生成されていません。カレンダー設定を確認してください。');
        console.log('🔍 現在のカレンダー設定:', {
          slotMinTime: calendar.getOption('slotMinTime'),
          slotMaxTime: calendar.getOption('slotMaxTime'),
          slotDuration: calendar.getOption('slotDuration')
        });
      } else {
        console.log('✅ 22時台のスロットが正常に生成されました');
      }
    }, 500);
  }, 300);
  
  // 初期化完了イベントを発火
  const event = new CustomEvent('calendarInitialized', { detail: { calendar } });
  document.dispatchEvent(event);
  
  // グリッド背景色の初期更新
  setTimeout(() => {
    updateGridBackgroundColors(new Date()).then(() => {
      console.log('✅ Initial grid colors applied');
    }).catch(error => {
      console.error('❌ Initial grid colors failed:', error);
    });
  }, 200);
  
  } catch (error) {
    console.error('❌ Calendar initialization failed:', error);
    // エラーが発生した場合、少し待ってからリトライ
    setTimeout(() => {
      console.log('🔄 Retrying after error...');
      initializeCalendar();
    }, 1000);
  }
}

// カレンダーインスタンスを安全に取得する関数
function getCalendarInstance() {
  console.log('🔍 Checking calendar initialization status...');
  console.log('🔍 window.pageCalendar:', window.pageCalendar);
  console.log('🔍 window.calendar:', window.calendar);
  
  // 方法1: window.pageCalendarから取得
  if (window.pageCalendar && typeof window.pageCalendar.refetchEvents === 'function') {
    console.log('✅ Found calendar via window.pageCalendar');
    return window.pageCalendar;
  }
  
  // 方法2: DOM要素から取得
  const calendarEl = document.getElementById('calendar');
  console.log('🔍 Calendar element:', calendarEl);
  
  if (calendarEl && calendarEl._fullCalendarInstance) {
    console.log('✅ Found calendar via DOM element');
    return calendarEl._fullCalendarInstance;
  }
  
  // 方法3: FullCalendarの内部APIから取得
  const CalendarAPI = typeof FullCalendar !== 'undefined' ? FullCalendar : window.FullCalendar;
  if (CalendarAPI && calendarEl) {
    try {
      const calendar = CalendarAPI.Calendar && CalendarAPI.Calendar.getCalendar ? 
        CalendarAPI.Calendar.getCalendar(calendarEl) : null;
      if (calendar) {
        console.log('✅ Found calendar via FullCalendar API');
        return calendar;
      }
    } catch (error) {
      console.log('⚠️ FullCalendar API not available:', error.message);
    }
  }
  
  console.log('❌ FullCalendarインスタンスが要素に見つかりません');
  return null;
}

// waitForCalendarAndInitialize を修正
export function waitForCalendarAndInitialize(callback, maxRetries = 5) {
  let retries = 0;
  
  function checkCalendar() {
    retries++;
    console.log(`⏳ Waiting for calendar to be available... (${retries}/${maxRetries})`);
    
    const calendar = getCalendarInstance();
    
    if (calendar) {
      console.log('✅ Calendar found, executing callback');
      callback(calendar);
      return;
    }
    
          if (retries >= maxRetries) {
      console.error('❌ Calendar wait timeout after', maxRetries, 'retries');
      console.error('❌ FullCalendarインスタンスが要素に見つかりません - 再初期化を試行します');
      console.log('🔄 Attempting to reinitialize calendar...');
      
      // カレンダー再初期化を試行
      reinitializeCalendar();
      
      // 再初期化後に再度チェック
      setTimeout(() => {
        const newCalendar = getCalendarInstance();
        if (newCalendar) {
          console.log('✅ Calendar reinitialized successfully');
          callback(newCalendar);
        } else {
          console.error('❌ Calendar reinitialization failed');
          console.error('❌ FullCalendarインスタンスが要素に見つかりません - 手動再初期化が必要です');
          
          // ユーザーに手動での対処法を提示
          const message = 'カレンダーの初期化に失敗しました。以下のいずれかを試してください:\n\n' +
                         '1. ページをリロード\n' +
                         '2. ブラウザコンソールで `window.reinitializeCalendar()` を実行\n' +
                         '3. 開発者ツールでエラーを確認';
          
          if (confirm(message + '\n\nページをリロードしますか？')) {
            location.reload();
          }
        }
      }, 1000);
      
      return;
    }
    
    // 短い間隔でリトライ
    setTimeout(checkCalendar, 200);
  }
  
  checkCalendar();
}

// カレンダー更新関数（改善版）
export function updateCalendarWithShifts() {
  console.log('🔄 カレンダーをシフトで更新中...');
  
  const calendar = getCalendarInstance();
  if (calendar) {
    console.log('✅ カレンダーが利用可能、イベントを再取得中...');
    calendar.refetchEvents();
    
    // 現在表示されている日付のシフト情報と動的ハイライトも更新
    const currentDate = calendar.view.currentStart;
    updateGridBackgroundColors(currentDate);
    highlightShiftHours(currentDate);
    
    console.log('✅ カレンダー更新完了');
  } else {
    console.log('⏳ カレンダーがまだ初期化されていないため、初期化を待機します...');
    waitForCalendarAndInitialize((calendar) => {
      console.log('✅ カレンダーが利用可能になりました、イベントを再取得中...');
      calendar.refetchEvents();
      
      // 現在表示されている日付のシフト情報と動的ハイライトも更新
      const currentDate = calendar.view.currentStart;
      updateGridBackgroundColors(currentDate);
      highlightShiftHours(currentDate);
      
      console.log('✅ カレンダー更新完了');
    }, 3);
  }
}

// シフト設定変更時のカレンダー更新関数
export function updateCalendarForShiftChange(date) {
  console.log('🔄 シフト変更によるカレンダー更新:', date);
  
  const calendar = getCalendarInstance();
  if (calendar) {
    // 指定された日付のシフト情報と動的ハイライトを更新
    updateGridBackgroundColors(new Date(date));
    highlightShiftHours(new Date(date));
    
    // イベントも再取得
    calendar.refetchEvents();
    
    console.log('✅ シフト変更によるカレンダー更新完了');
  }
}



// 🆕 動的に営業時間を更新する機能（シフト連携対応）
function updateBusinessHours(startHour, endHour) {
  if (window.pageCalendar) {
    window.pageCalendar.setOption('businessHours', {
      daysOfWeek: systemSettings.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
      startTime: `${startHour.toString().padStart(2, '0')}:00`,
      endTime: `${endHour.toString().padStart(2, '0')}:00`,
    });
    
    console.log(`🕐 Business hours updated: ${startHour}:00 - ${endHour}:00`);
    
    // 動的ハイライトを再適用
    setTimeout(() => {
      const currentDate = window.pageCalendar.view.currentStart;
      highlightShiftHours(currentDate);
    }, 100);
  }
}

// デバッグ用の関数
function testGridUpdate() {
  console.log('🧪 Testing grid update...');
  updateGridBackgroundColors(new Date()).then(() => {
    console.log('✅ Grid update test completed');
  }).catch(error => {
    console.error('❌ Grid update test failed:', error);
  });
}

function testShiftFetch() {
  console.log('🧪 Testing shift fetch...');
  getBusinessHoursForDate(new Date()).then(businessHours => {
    console.log('✅ Shift fetch test completed:', businessHours);
  }).catch(error => {
    console.error('❌ Shift fetch test failed:', error);
  });
}

function testShiftHighlight() {
  console.log('🧪 Testing shift highlight (functionality removed)...');
}

// カレンダー再初期化関数
function reinitializeCalendar() {
  console.log('🔄 Reinitializing calendar...');
  
  // 既存のインスタンスを破棄
  if (window.pageCalendar) {
    try {
      window.pageCalendar.destroy();
      window.pageCalendar = null;
    } catch (error) {
      console.warn('⚠️ Error destroying calendar during reinitialization:', error);
    }
  }
  
  // DOM要素の参照をクリア
  const calendarEl = document.getElementById('calendar');
  if (calendarEl && calendarEl._fullCalendarInstance) {
    delete calendarEl._fullCalendarInstance;
  }
  
  // 新しいインスタンスを作成
  setTimeout(() => {
    initializeCalendar();
  }, 100);
}

// グローバル関数として公開（即座に実行）
window.testGridUpdate = testGridUpdate;
window.testShiftFetch = testShiftFetch;
window.testShiftHighlight = testShiftHighlight;
window.updateBusinessHours = updateBusinessHours;
window.highlightShiftHours = highlightShiftHours;
window.updateGridBackgroundColors = updateGridBackgroundColors;
window.getBusinessHoursForDate = getBusinessHoursForDate;
window.reinitializeCalendar = reinitializeCalendar;
window.getCalendarInstance = getCalendarInstance;
window.updateCalendarForShiftChange = updateCalendarForShiftChange;

// デバッグ用の関数が利用可能になったことをログで確認
console.log('🔧 Debug functions registered at end of file:', {
  testGridUpdate: typeof window.testGridUpdate,
  testShiftFetch: typeof window.testShiftFetch,
  updateBusinessHours: typeof window.updateBusinessHours,
  highlightShiftHours: typeof window.highlightShiftHours,
  updateGridBackgroundColors: typeof window.updateGridBackgroundColors,
  getBusinessHoursForDate: typeof window.getBusinessHoursForDate
});

// DOMContentLoadedイベントでも関数を再登録
document.addEventListener('DOMContentLoaded', function() {
  console.log('🔧 DOMContentLoaded - registering debug functions...');
  window.testGridUpdate = testGridUpdate;
  window.testShiftFetch = testShiftFetch;
  window.updateBusinessHours = updateBusinessHours;
  window.highlightShiftHours = highlightShiftHours;
  window.updateGridBackgroundColors = updateGridBackgroundColors;
  window.getBusinessHoursForDate = getBusinessHoursForDate;
  
  console.log('🔧 Debug functions registered in DOMContentLoaded:', {
    testGridUpdate: typeof window.testGridUpdate,
    testShiftFetch: typeof window.testShiftFetch,
    updateBusinessHours: typeof window.updateBusinessHours,
    highlightShiftHours: typeof window.highlightShiftHours,
    updateGridBackgroundColors: typeof window.updateGridBackgroundColors,
    getBusinessHoursForDate: typeof window.getBusinessHoursForDate
  });
});