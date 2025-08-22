// app/javascript/calendar/calendar_core.js
import { showMessage } from './utils.js';

// システム設定（HTMLから取得）
const systemSettings = {
  businessHoursStart: parseInt(document.querySelector('meta[name="business-hours-start"]')?.content || '10'),
  businessHoursEnd: parseInt(document.querySelector('meta[name="business-hours-end"]')?.content || '20'),
  slotIntervalMinutes: parseInt(document.querySelector('meta[name="slot-interval"]')?.content || '10'),
  reservationIntervalMinutes: parseInt(document.querySelector('meta[name="reservation-interval"]')?.content || '15'),
  sundayClosed: document.querySelector('meta[name="sunday-closed"]')?.content === 'true'
};

// インターバル表示用スタイル追加
function addIntervalStyles() {
  if (document.getElementById('interval-styles')) return;
  
  const style = document.createElement('style');
  style.id = 'interval-styles';
  style.textContent = `
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
      revertFunc();
    }
  })
  .catch(error => {
    console.error('❌ Update request failed:', error);
    showMessage('更新中にエラーが発生しました', 'danger');
    revertFunc();
  });
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
    window.pageCalendar.destroy();
    window.pageCalendar = null;
  }
  
  // インターバル表示用スタイルを動的に追加
  addIntervalStyles();
  
  // FullCalendarが利用可能か確認
  console.log('🔍 Checking FullCalendar availability...');
  console.log('🔍 typeof FullCalendar:', typeof FullCalendar);
  console.log('🔍 window.FullCalendar:', window.FullCalendar);
  console.log('🔍 global FullCalendar:', typeof global !== 'undefined' ? global.FullCalendar : 'global not available');
  
  if (typeof FullCalendar === 'undefined') {
    console.error('❌ FullCalendar not available, checking alternatives...');
    
    // 代替手段を試す
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
    
    // 営業時間の設定
    businessHours: {
      daysOfWeek: systemSettings.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
      startTime: `${systemSettings.businessHoursStart.toString().padStart(2, '0')}:00`,
      endTime: `${systemSettings.businessHoursEnd.toString().padStart(2, '0')}:00`,
    },
    
    // スロット間隔の設定
    slotDuration: `00:${systemSettings.slotIntervalMinutes.toString().padStart(2, '0')}:00`,
    slotMinTime: `${systemSettings.businessHoursStart.toString().padStart(2, '0')}:00:00`,
    slotMaxTime: `${systemSettings.businessHoursEnd.toString().padStart(2, '0')}:00:00`,
    
    // イベントソース
    events: '/admin/reservations.json',
    
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
  
  // レンダリング完了を確認
  setTimeout(() => {
    if (calendarEl.querySelector('.fc-toolbar')) {
      console.log('✅ Calendar rendered successfully');
      console.log('✅ pageCalendar is now available globally');
      console.log('✅ window.pageCalendar:', window.pageCalendar);
    } else {
      console.error('❌ Calendar rendering failed');
    }
  }, 100);
  
  console.log('✅ Calendar core initialized');
}