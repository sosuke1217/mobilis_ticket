// app/javascript/calendar/index.js
import { initializeCalendar } from './calendar_core.js';
import { setupReservationModal } from './modal_controller.js';
import { setupIntervalControls } from './interval_settings.js';
import { setupReservationForm } from './reservation_form.js';
import { setupGlobalUtils } from './utils.js';

console.log('📅 Calendar module loading...');

// グローバル変数
window.pageCalendar = null;
window.currentUsers = [];
window.currentReservationId = null;

// 初期化関数
function initializeComplete() {
  console.log('🚀 Complete initialization starting...');
  
  try {
    // 各モジュールを順番に初期化
    setupGlobalUtils();
    setupReservationModal();
    setupIntervalControls();
    setupReservationForm();
    initializeCalendar();
    
    console.log('✅ All modules initialized successfully');
  } catch (error) {
    console.error('❌ Initialization failed:', error);
  }
}

// イベントリスナー設定
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeComplete);
} else {
  initializeComplete();
}

// Turbo対応
document.addEventListener('turbo:load', initializeComplete);

document.addEventListener('turbo:before-cache', function() {
  if (window.pageCalendar) {
    console.log('🧹 Cleaning up calendar before cache');
    window.pageCalendar.destroy();
    window.pageCalendar = null;
  }
});

export { initializeComplete };