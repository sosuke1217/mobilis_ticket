// app/javascript/calendar/index.js
import { initializeCalendar } from 'calendar_core';
import { setupReservationModal, openReservationModal } from 'modal';
import { setupIntervalControls } from 'interval_settings';
import { setupReservationForm } from 'reservation_form';
import { setupGlobalUtils } from 'utils';

console.log('📅 Calendar module loading...');

// グローバル変数
window.pageCalendar = null;
window.currentUsers = [];
window.currentReservationId = null;

// グローバル関数として公開
window.openReservationModal = openReservationModal;

// 初期化関数
function initializeComplete() {
  console.log('🚀 Complete initialization starting...');
  
  try {
    // 各モジュールを順番に初期化
    setupGlobalUtils();
    setupReservationModal();
    setupIntervalControls();
    setupReservationForm();
    
    console.log('🔧 Calling initializeCalendar...');
    initializeCalendar();
    
    // 初期化完了後の確認
    setTimeout(() => {
      console.log('🔍 Post-initialization check:');
      console.log('🔍 window.pageCalendar exists:', typeof window.pageCalendar !== 'undefined');
      console.log('🔍 window.pageCalendar value:', window.pageCalendar);
      console.log('🔍 window.openReservationModal exists:', typeof window.openReservationModal !== 'undefined');
      
      if (window.pageCalendar) {
        console.log('✅ Calendar successfully initialized and available globally');
      } else {
        console.error('❌ Calendar initialization failed - pageCalendar not available');
      }
    }, 500);
    
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