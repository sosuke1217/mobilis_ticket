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

// 営業時間を動的に取得する関数
async function getBusinessHoursForDate(date) {
  console.log(`🔍 getBusinessHoursForDate called with date:`, date);
  
  try {
    console.log(`🔍 Fetching shift data for date: ${date.toISOString().split('T')[0]}`);
    
    // CSRFトークンを取得
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    console.log(`🔑 CSRF Token: ${csrfToken ? 'Found' : 'Not found'}`);
    
    const response = await fetch(`/admin/shifts/for_date?date=${date.toISOString().split('T')[0]}`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': csrfToken
      }
    });
    
    console.log(`📡 Response status: ${response.status}`);
    
    if (response.status === 401) {
      console.warn('⚠️ Authentication required, using default hours');
      throw new Error('Authentication required');
    }
    
    if (response.ok) {
      const data = await response.json();
      console.log(`📋 Received shift data:`, data);
      
      if (data.success && data.shift && data.requires_time) {
        const startHour = parseInt(data.shift.start_time.split(':')[0]);
        const endHour = parseInt(data.shift.end_time.split(':')[0]);
        console.log(`✅ Using shift hours: ${startHour}:00-${endHour}:00 (${data.shift.shift_type_display})`);
        return { start: startHour, end: endHour, shift: data.shift };
      } else {
        console.log(`ℹ️ No shift data or shift doesn't require time, using default hours`);
      }
    } else {
      console.warn(`⚠️ Failed to fetch shift data: ${response.status} ${response.statusText}`);
    }
  } catch (error) {
    console.error('❌ Error fetching shift data:', error);
  }
  
  // デフォルトの営業時間を返す
  const defaultHours = { 
    start: systemSettings.businessHoursStart, 
    end: systemSettings.businessHoursEnd, 
    shift: null 
  };
  console.log(`🔄 Using default hours: ${defaultHours.start}:00-${defaultHours.end}:00`);
  return defaultHours;
}

// グリッドの背景色を動的に更新する関数
async function updateGridBackgroundColors(date) {
  console.log(`🎨 updateGridBackgroundColors called with date:`, date);
  
  try {
    const businessHours = await getBusinessHoursForDate(date);
    const dateStr = date.toISOString().split('T')[0];
    
    console.log(`🎨 Updating grid colors for ${dateStr}: ${businessHours.start}:00-${businessHours.end}:00`);
    
    // 全てのスロットをリセット
    const allSlots = document.querySelectorAll('.fc-timegrid-slot');
    console.log(`🔄 Resetting ${allSlots.length} time slots`);
    
    allSlots.forEach(slot => {
      slot.style.backgroundColor = '';
      slot.style.opacity = '';
      slot.style.borderTop = '';
    });
    
    // 営業時間外のスロットを濃いグレーに設定
    for (let hour = 8; hour < businessHours.start; hour++) {
      const slots = document.querySelectorAll(`.fc-timegrid-slot[data-time^="${hour.toString().padStart(2, '0')}:"]`);
      console.log(`🌑 Setting ${slots.length} slots for hour ${hour} to dark gray`);
      slots.forEach(slot => {
        slot.style.backgroundColor = '#6c757d';
        slot.style.opacity = '0.3';
      });
    }
    
    // 営業時間後のスロットを濃いグレーに設定
    for (let hour = businessHours.end; hour <= 22; hour++) {
      const slots = document.querySelectorAll(`.fc-timegrid-slot[data-time^="${hour.toString().padStart(2, '0')}:"]`);
      console.log(`🌑 Setting ${slots.length} slots for hour ${hour} to dark gray`);
      slots.forEach(slot => {
        slot.style.backgroundColor = '#6c757d';
        slot.style.opacity = '0.3';
      });
    }
    
    // 営業時間内のスロットを明るく設定
    for (let hour = businessHours.start; hour < businessHours.end; hour++) {
      const slots = document.querySelectorAll(`.fc-timegrid-slot[data-time^="${hour.toString().padStart(2, '0')}:"]`);
      console.log(`☀️ Setting ${slots.length} slots for hour ${hour} to light background`);
      slots.forEach(slot => {
        slot.style.backgroundColor = '#f8f9fa';
        slot.style.opacity = '1';
      });
    }
    
    // 営業開始・終了の境界線を更新
    const startSlot = document.querySelector(`.fc-timegrid-slot[data-time="${businessHours.start.toString().padStart(2, '0')}:00:00"]`);
    const endSlot = document.querySelector(`.fc-timegrid-slot[data-time="${businessHours.end.toString().padStart(2, '0')}:00:00"]`);
    
    if (startSlot) {
      startSlot.style.borderTop = '3px solid #28a745';
      console.log(`✅ Set start boundary at ${businessHours.start}:00`);
    }
    if (endSlot) {
      endSlot.style.borderTop = '3px solid #dc3545';
      console.log(`✅ Set end boundary at ${businessHours.end}:00`);
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
    
    /* 営業時間外の背景色（8:00-9:59, 21:00-21:59） */
    .fc-timegrid-slot[data-time^="08:"],
    .fc-timegrid-slot[data-time^="09:"],
    .fc-timegrid-slot[data-time^="21:"] {
      background-color: #f8f9fa !important;
      opacity: 0.7 !important;
      border-left: 3px solid #dee2e6 !important;
    }
    
    /* 営業時間外の時間軸ラベル */
    .fc-timegrid-axis[data-time^="08:"],
    .fc-timegrid-axis[data-time^="09:"],
    .fc-timegrid-axis[data-time^="21:"] {
      background-color: #f8f9fa !important;
      color: #6c757d !important;
      font-style: italic !important;
      font-weight: normal !important;
    }
    
    /* 通常営業時間の時間軸ラベルを強調 */
    .fc-timegrid-axis[data-time^="10:"],
    .fc-timegrid-axis[data-time^="11:"],
    .fc-timegrid-axis[data-time^="12:"],
    .fc-timegrid-axis[data-time^="13:"],
    .fc-timegrid-axis[data-time^="14:"],
    .fc-timegrid-axis[data-time^="15:"],
    .fc-timegrid-axis[data-time^="16:"],
    .fc-timegrid-axis[data-time^="17:"],
    .fc-timegrid-axis[data-time^="18:"],
    .fc-timegrid-axis[data-time^="19:"],
    .fc-timegrid-axis[data-time^="20:"] {
      background-color: #fff !important;
      color: #212529 !important;
      font-weight: 600 !important;
    }
    
    /* 営業開始時間（10:00）の境界線とラベル */
    .fc-timegrid-slot[data-time="10:00:00"] {
      border-top: 3px solid #28a745 !important;
      position: relative;
    }
    
    .fc-timegrid-slot[data-time="10:00:00"]::before {
      content: "通常営業開始";
      position: absolute;
      left: 5px;
      top: -15px;
      background: #28a745;
      color: white;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: bold;
      z-index: 10;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    }
    
    /* 営業終了時間（21:00）の境界線とラベル */
    .fc-timegrid-slot[data-time="21:00:00"] {
      border-top: 3px solid #dc3545 !important;
      position: relative;
    }
    
    .fc-timegrid-slot[data-time="21:00:00"]::before {
      content: "通常営業終了";
      position: absolute;
      left: 5px;
      top: -15px;
      background: #dc3545;
      color: white;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: bold;
      z-index: 10;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    }
    
    /* シフト延長時間のハイライト（今後の機能用） */
    .shift-extended-hours {
      background-color: #e8f5e8 !important;
      border-left: 3px solid #28a745 !important;
    }
    
    /* ホバー効果 */
    .fc-timegrid-slot:hover {
      background-color: #e3f2fd !important;
      cursor: pointer;
      transition: background-color 0.2s ease;
    }
    
    /* 営業時間外のホバー効果 */
    .fc-timegrid-slot[data-time^="08:"]:hover,
    .fc-timegrid-slot[data-time^="09:"]:hover,
    .fc-timegrid-slot[data-time^="21:"]:hover {
      background-color: #fff3cd !important;
    }
  `;
  
  document.head.appendChild(style);
}

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

// 🆕 シフト時間のハイライト機能（より確実な実装）
function highlightShiftHours() {
  console.log('🎨 Applying shift hour highlights...');
  
  // 少し遅延させてDOMが確実に描画されてから実行
  setTimeout(() => {
    // 営業時間外の時間帯を薄く表示
    const timeSlots = document.querySelectorAll('.fc-timegrid-slot');
    
    timeSlots.forEach(slot => {
      const timeAttr = slot.getAttribute('data-time');
      if (!timeAttr) return;
      
      const hour = parseInt(timeAttr.split(':')[0]);
      
      // 8:00-9:59 と 21:00-21:59 を営業時間外として薄く表示
      if ((hour >= 8 && hour < 10) || (hour >= 21 && hour < 22)) {
        slot.style.backgroundColor = '#f8f9fa';
        slot.style.borderLeft = '3px solid #dee2e6';
        slot.style.opacity = '0.7';
        
        // ツールチップを追加
        if (hour >= 8 && hour < 10) {
          slot.title = '営業時間外（シフトで延長可能）';
        } else {
          slot.title = '営業時間外（シフトで延長可能）';
        }
      }
    });
    
    // 通常営業時間の境界線を強調
    const tenAmSlot = document.querySelector('.fc-timegrid-slot[data-time="10:00:00"]');
    const ninePmSlot = document.querySelector('.fc-timegrid-slot[data-time="21:00:00"]');
    
    if (tenAmSlot) {
      tenAmSlot.style.borderTop = '3px solid #28a745';
      tenAmSlot.title = '通常営業開始時間';
    }
    
    if (ninePmSlot) {
      ninePmSlot.style.borderTop = '3px solid #dc3545';
      ninePmSlot.title = '通常営業終了時間';
    }
  }, 200);
}

// カレンダー初期化
export function initializeCalendar() {
  console.log('🔧 Starting calendar initialization...');
  
  // デバッグ用の関数を即座にグローバルに公開
  window.testGridUpdate = testGridUpdate;
  window.testShiftFetch = testShiftFetch;
  window.updateBusinessHours = updateBusinessHours;
  window.highlightShiftHours = highlightShiftHours;
  window.updateGridBackgroundColors = updateGridBackgroundColors;
  window.getBusinessHoursForDate = getBusinessHoursForDate;
  
  console.log('🔧 Debug functions registered in initializeCalendar:', {
    testGridUpdate: typeof window.testGridUpdate,
    testShiftFetch: typeof window.testShiftFetch,
    updateBusinessHours: typeof window.updateBusinessHours,
    highlightShiftHours: typeof window.highlightShiftHours,
    updateGridBackgroundColors: typeof window.updateGridBackgroundColors,
    getBusinessHoursForDate: typeof window.getBusinessHoursForDate
  });
  
  // グローバル関数の存在確認
  if (typeof window.testGridUpdate !== 'function') {
    console.error('❌ testGridUpdate function not properly registered');
  }
  if (typeof window.testShiftFetch !== 'function') {
    console.error('❌ testShiftFetch function not properly registered');
  }
  if (typeof window.updateGridBackgroundColors !== 'function') {
    console.error('❌ updateGridBackgroundColors function not properly registered');
  }
  if (typeof window.getBusinessHoursForDate !== 'function') {
    console.error('❌ getBusinessHoursForDate function not properly registered');
  }
  
  const calendarEl = document.getElementById('calendar');
  if (!calendarEl) {
    console.error('❌ Calendar element not found');
    return;
  }

  console.log('🗓️ Initializing calendar with extended time display (8:00-22:00)...');
  
  // 既存のカレンダーインスタンスがあれば破棄
  if (window.pageCalendar) {
    console.log('🧹 Destroying existing calendar instance');
    window.pageCalendar.destroy();
    window.pageCalendar = null;
  }
  
  // インターバル表示用スタイルを動的に追加
  addIntervalStyles();
  
  // FullCalendarが利用可能か確認
  if (typeof FullCalendar === 'undefined') {
    console.error('❌ FullCalendar not available, checking alternatives...');
    if (window.FullCalendar) {
      console.log('✅ Found FullCalendar on window object');
      window.FullCalendar = window.FullCalendar;
    } else if (typeof global !== 'undefined' && global.FullCalendar) {
      console.log('✅ Found FullCalendar on global object');
      window.FullCalendar = global.FullCalendar;
    } else {
      console.error('❌ FullCalendar not found anywhere, retrying in 1 second');
      setTimeout(() => initializeCalendar(), 1000);
      return;
    }
  }
  
  console.log('✅ FullCalendar is available, proceeding with initialization');
  
  // カレンダーインスタンスを作成
  const calendar = new FullCalendar.Calendar(calendarEl, {
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
    
    // 🔧 修正: 固定で8:00-22:00を表示
    slotMinTime: '08:00:00',
    slotMaxTime: '22:00:00',
    slotDuration: '00:10:00', // 10分間隔
    slotLabelInterval: '00:30:00', // ラベルは30分間隔
    snapDuration: '00:10:00', // スナップも10分間隔
    
    // 🔧 修正: 営業時間を通常営業時間に設定（視覚的区別用）
    businessHours: {
      daysOfWeek: systemSettings.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
      startTime: `${systemSettings.businessHoursStart.toString().padStart(2, '0')}:00`,
      endTime: `${systemSettings.businessHoursEnd.toString().padStart(2, '0')}:00`,
    },
    
    // イベントソース
    events: {
      url: '/admin/reservations.json',
      failure: function(error) {
        console.error('❌ Error loading events:', error);
        showMessage('カレンダーデータの読み込みに失敗しました', 'danger');
      }
    },
    
    // 日付クリック処理
    dateClick: function(info) {
      console.log('📅 Date clicked:', info.dateStr);
      if (window.openReservationModal) {
        window.openReservationModal(null, info.dateStr);
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
    
    // 🆕 カレンダー描画完了後にシフト時間をハイライト
    datesSet: function(info) {
      console.log('📅 Dates set callback triggered:', info.startStr, 'to', info.endStr);
      
      // メインカレンダーの日付が変更されたときにミニカレンダーも同期
      const currentDate = info.start;
      monthCalendar.gotoDate(currentDate);
      updateMonthYearDisplay();
      
      // グリッドの背景色を更新
      console.log('🎨 Updating grid colors for datesSet callback...');
      updateGridBackgroundColors(currentDate).then(() => {
        console.log('✅ Grid colors updated in datesSet callback');
      }).catch(error => {
        console.error('❌ Grid colors update failed in datesSet callback:', error);
      });
    },
    
    eventDidMount: function(info) {
      // イベント表示時の処理
      const eventType = info.event.extendedProps.type;
      if (eventType === 'interval') {
        info.el.style.cursor = 'pointer';
      }
    }
  });
  
  console.log('📅 Calling calendar.render()');
  calendar.render();
  
  // グローバル変数として設定
  window.pageCalendar = calendar;
  console.log('✅ pageCalendar set as global variable:', window.pageCalendar);
  
  // 初期化完了後にdatesSetコールバックを手動で呼び出し
  setTimeout(() => {
    console.log('🔄 Manually triggering datesSet callback for initialization...');
    if (calendar && calendar.getDate) {
      const currentDate = calendar.getDate();
      console.log('📅 Current calendar date:', currentDate);
      
      // datesSetコールバックを手動で呼び出し
      const datesSetCallback = calendar.getOption('datesSet');
      if (datesSetCallback) {
        datesSetCallback({
          start: currentDate,
          end: new Date(currentDate.getTime() + 7 * 24 * 60 * 60 * 1000),
          startStr: currentDate.toISOString().split('T')[0],
          endStr: new Date(currentDate.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          view: calendar.view
        });
      }
    }
  }, 1000);
  
  // レンダリング完了を確認
  setTimeout(() => {
    if (calendarEl.querySelector('.fc-toolbar')) {
      console.log('✅ Calendar rendered successfully');
      highlightShiftHours(); // 初回ハイライト適用
      
      // グリッド背景色を更新（少し遅延させて確実に実行）
      setTimeout(() => {
        console.log('🎨 Starting initial grid background color update...');
        updateGridBackgroundColors(new Date()).then(() => {
          console.log('✅ Initial grid background color update completed');
        }).catch(error => {
          console.error('❌ Initial grid background color update failed:', error);
        });
      }, 500); // 遅延時間を500msに短縮
    } else {
      console.error('❌ Calendar rendering failed');
    }
  }, 300);
  
  // 追加の初期化処理（確実に実行されるように）
  setTimeout(() => {
    console.log('🎨 Starting additional grid background color update...');
    updateGridBackgroundColors(new Date()).then(() => {
      console.log('✅ Additional grid background color update completed');
    }).catch(error => {
      console.error('❌ Additional grid background color update failed:', error);
    });
  }, 2000); // 2秒後に追加実行
  
  console.log('✅ Calendar core initialized');
}

// 🆕 シフト時間のハイライト機能（改良版）
function highlightShiftHours() {
  console.log('🎨 Applying shift hour highlights...');
  
  // DOMが確実に描画されてから実行
  setTimeout(() => {
    // 営業時間外の時間帯を薄く表示
    const timeSlots = document.querySelectorAll('.fc-timegrid-slot');
    const timeAxes = document.querySelectorAll('.fc-timegrid-axis');
    
    console.log(`🔍 Found ${timeSlots.length} time slots and ${timeAxes.length} time axes`);
    
    // タイムスロットの処理
    timeSlots.forEach(slot => {
      const timeAttr = slot.getAttribute('data-time');
      if (!timeAttr) return;
      
      const hour = parseInt(timeAttr.split(':')[0]);
      
      // 8:00-9:59 と 21:00-21:59 を営業時間外として処理
      if ((hour >= 8 && hour < 10) || (hour >= 21 && hour < 22)) {
        slot.style.backgroundColor = '#f8f9fa';
        slot.style.borderLeft = '3px solid #dee2e6';
        slot.style.opacity = '0.7';
        
        // ツールチップを追加
        if (hour >= 8 && hour < 10) {
          slot.title = '営業時間外（シフトで延長可能）';
        } else {
          slot.title = '営業時間外（シフトで延長可能）';
        }
      }
    });
    
    // 時間軸の処理
    timeAxes.forEach(axis => {
      const timeAttr = axis.getAttribute('data-time');
      if (!timeAttr) return;
      
      const hour = parseInt(timeAttr.split(':')[0]);
      
      // 営業時間外の時間軸を薄く表示
      if ((hour >= 8 && hour < 10) || (hour >= 21 && hour < 22)) {
        axis.style.backgroundColor = '#f8f9fa';
        axis.style.color = '#6c757d';
        axis.style.fontStyle = 'italic';
      }
      // 通常営業時間を強調
      else if (hour >= 10 && hour < 21) {
        axis.style.backgroundColor = '#fff';
        axis.style.color = '#212529';
        axis.style.fontWeight = '600';
      }
    });
    
    // 境界線の追加
    const tenAmSlot = document.querySelector('.fc-timegrid-slot[data-time="10:00:00"]');
    const ninePmSlot = document.querySelector('.fc-timegrid-slot[data-time="21:00:00"]');
    
    if (tenAmSlot) {
      tenAmSlot.style.borderTop = '3px solid #28a745';
      tenAmSlot.title = '通常営業開始時間';
    }
    
    if (ninePmSlot) {
      ninePmSlot.style.borderTop = '3px solid #dc3545';
      ninePmSlot.title = '通常営業終了時間';
    }
    
    console.log('✅ Shift highlights applied successfully');
  }, 300);
}

// 🆕 動的に営業時間を更新する機能（将来のシフト連携用）
function updateBusinessHours(startHour, endHour) {
  if (window.pageCalendar) {
    window.pageCalendar.setOption('businessHours', {
      daysOfWeek: systemSettings.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
      startTime: `${startHour.toString().padStart(2, '0')}:00`,
      endTime: `${endHour.toString().padStart(2, '0')}:00`,
    });
    
    console.log(`🕐 Business hours updated: ${startHour}:00 - ${endHour}:00`);
    
    // ハイライトを再適用
    setTimeout(() => {
      highlightShiftHours();
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

// グローバル関数として公開（即座に実行）
window.testGridUpdate = testGridUpdate;
window.testShiftFetch = testShiftFetch;
window.updateBusinessHours = updateBusinessHours;
window.highlightShiftHours = highlightShiftHours;
window.updateGridBackgroundColors = updateGridBackgroundColors;
window.getBusinessHoursForDate = getBusinessHoursForDate;

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