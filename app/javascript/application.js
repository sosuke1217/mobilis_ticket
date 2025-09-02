// app/javascript/application.js - 条件付き読み込み版
import "@hotwired/turbo-rails"
import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"
import "controllers"

console.log("🚀 Application.js loaded successfully");

// カレンダーが必要なページでのみ読み込み
function loadCalendarIfNeeded() {
  // カレンダー要素が存在するページでのみ読み込み
  if (document.querySelector('#calendar') || document.querySelector('.calendar-container')) {
    console.log("📅 Calendar element found, loading calendar module");
    import("fullcalendar").then(() => {
      console.log("✅ Calendar module loaded successfully");
    }).catch(error => {
      console.error("❌ Failed to load calendar module:", error);
    });
  }
  // カレンダー要素がない場合は静かにスキップ（ログを削除）
}

// ページ読み込み完了時に実行
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', loadCalendarIfNeeded);
} else {
  loadCalendarIfNeeded();
}

// Turbo対応
document.addEventListener('turbo:load', loadCalendarIfNeeded);