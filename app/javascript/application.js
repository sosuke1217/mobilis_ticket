import "./calendar"

// app/javascript/application.js - ES Module対応版

console.log("🚀 Application.js loaded at:", new Date().toISOString());

// グローバル変数として宣言（ES moduleからでも公開）
window.calendarInstance = null;


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


document.addEventListener("turbo:before-cache", window.cleanupCalendar);


console.log("📝 Application.js setup complete at:", new Date().toISOString());