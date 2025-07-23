// app/javascript/application.js - ES Module対応版

console.log("🚀 Application.js loaded at:", new Date().toISOString());

// グローバル変数として宣言（ES moduleからでも公開）
window.calendarInstance = null;

// グローバル関数として宣言
window.initializeCalendar = function() {
  console.log("🔥 initializeCalendar called at:", new Date().toISOString());
  console.log("Document ready state:", document.readyState);
  console.log("FullCalendar available:", typeof FullCalendar);
  
  const calendarEl = document.getElementById("calendar");
  console.log("Calendar element found:", !!calendarEl);
  
  if (!calendarEl) {
    console.log("⚠️ Calendar element not found");
    return;
  }
  
  // 既存のインスタンスを破棄
  if (window.calendarInstance) {
    console.log("🗑️ Destroying existing calendar");
    try {
      window.calendarInstance.destroy();
    } catch (error) {
      console.warn("Error destroying calendar:", error);
    }
    window.calendarInstance = null;
  }
  
  // FullCalendarが利用可能か確認
  if (typeof FullCalendar === 'undefined') {
    console.error("❌ FullCalendar not available, retrying in 500ms");
    setTimeout(window.initializeCalendar, 500);
    return;
  }
  
  console.log("📅 Creating calendar instance");
  
  try {
    // まず要素をクリア
    calendarEl.innerHTML = '<div style="padding: 20px; text-align: center; background: #f0f0f0; border: 1px solid #ccc;">カレンダーを読み込み中...</div>';
    
    window.calendarInstance = new FullCalendar.Calendar(calendarEl, {
      initialView: window.innerWidth < 768 ? "timeGridDay" : "timeGridWeek",
      locale: 'ja',
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'timeGridWeek,timeGridDay'
      },
      slotMinTime: "10:00:00",
      slotMaxTime: "20:30:00",
      slotDuration: "00:10:00",
      scrollTime: "10:00:00",
      height: "auto",
      events: "/admin/reservations.json",
      
      dateClick: function(info) {
        console.log('📅 Date clicked:', info.dateStr);
        // モーダルを開く関数を呼び出し
        if (window.openReservationModal) {
          window.openReservationModal(null, info.dateStr);
        } else {
          alert('日付クリック: ' + info.dateStr);
        }
      },
      
      eventClick: function(info) {
        console.log('📅 Event clicked:', info.event.title);
        // モーダルを開く関数を呼び出し
        if (window.openReservationModal) {
          window.openReservationModal(info.event);
        } else {
          alert('イベントクリック: ' + info.event.title);
        }
      },
      
      eventDidMount: function(info) {
        console.log('📅 Event mounted:', info.event.title);
      }
    });
    
    console.log("📅 Calling calendar.render()");
    window.calendarInstance.render();
    
    // レンダリング完了を確認
    setTimeout(() => {
      if (calendarEl.querySelector('.fc-toolbar')) {
        console.log("✅ Calendar rendered successfully - toolbar found");
      } else {
        console.error("❌ Calendar rendering failed - no toolbar found");
        console.log("Calendar element content:", calendarEl.innerHTML.substring(0, 200));
      }
    }, 100);
    
  } catch (error) {
    console.error("❌ Calendar creation failed:", error);
    calendarEl.innerHTML = '<div style="padding: 20px; color: red; background: #ffe6e6; border: 1px solid #ff0000;">カレンダーの読み込みに失敗しました: ' + error.message + '</div>';
  }
};

window.cleanupCalendar = function() {
  console.log("🧹 Cleanup called");
  if (window.calendarInstance) {
    try {
      window.calendarInstance.destroy();
      console.log("🗑️ Calendar destroyed");
    } catch (error) {
      console.warn("Error during cleanup:", error);
    }
    window.calendarInstance = null;
  }
};

// カレンダーのイベントを再取得する関数
window.refetchCalendarEvents = function() {
  if (window.calendarInstance) {
    console.log('Refetching calendar events...');
    window.calendarInstance.refetchEvents();
  }
};

// モーダル関連の関数をグローバルに公開
window.openReservationModal = function(event = null, dateStr = null) {
  const modal = document.getElementById('reservationModal');
  const form = document.getElementById('reservationForm');
  
  if (!modal || !form) {
    console.error('Modal or form not found');
    return;
  }

  // フォームをリセット
  form.reset();
  
  if (event) {
    // 既存イベントの編集
    const idField = document.getElementById('reservationId');
    const userField = document.getElementById('reservationUserId');
    const nameField = document.getElementById('reservationName');
    const courseField = document.getElementById('reservationCourse');
    const timeField = document.getElementById('reservationStartTime');
    const deleteBtn = document.getElementById('deleteReservationBtn');
    
    if (idField) idField.value = event.id;
    if (userField) userField.value = event.extendedProps.user_id || "";
    if (nameField) nameField.value = event.title;
    if (courseField) courseField.value = event.extendedProps.description || "60分";
    if (timeField) timeField.value = event.start.toISOString();
    if (deleteBtn) deleteBtn.classList.remove('d-none');
  } else {
    // 新規予約
    const idField = document.getElementById('reservationId');
    const userField = document.getElementById('reservationUserId');
    const nameField = document.getElementById('reservationName');
    const courseField = document.getElementById('reservationCourse');
    const timeField = document.getElementById('reservationStartTime');
    const deleteBtn = document.getElementById('deleteReservationBtn');
    
    if (idField) idField.value = "";
    if (userField) userField.value = "";
    if (nameField) nameField.value = "";
    if (courseField) courseField.value = "60分";
    if (timeField) timeField.value = dateStr || "";
    if (deleteBtn) deleteBtn.classList.add('d-none');
  }
  
  // モーダルを表示
  try {
    if (typeof bootstrap !== 'undefined') {
      new bootstrap.Modal(modal).show();
    } else {
      console.error('Bootstrap is not loaded');
      modal.style.display = 'block';
      modal.classList.add('show');
    }
  } catch (error) {
    console.error('Error showing modal:', error);
  }
};

// 複数のイベントで初期化を試行
console.log("📝 Setting up event listeners");

document.addEventListener("DOMContentLoaded", function() {
  console.log("🏁 DOMContentLoaded fired");
  setTimeout(window.initializeCalendar, 100);
});

document.addEventListener("turbo:load", function() {
  console.log("🏁 turbo:load fired");
  setTimeout(window.initializeCalendar, 100);
});

window.addEventListener("load", function() {
  console.log("🏁 window load fired");
  setTimeout(window.initializeCalendar, 100);
});

document.addEventListener("turbo:before-cache", window.cleanupCalendar);

// フォールバック: 一定時間後に強制実行
setTimeout(function() {
  console.log("⏰ Fallback initialization attempt");
  if (!window.calendarInstance && document.getElementById("calendar")) {
    window.initializeCalendar();
  }
}, 2000);

console.log("📝 Application.js setup complete at:", new Date().toISOString());