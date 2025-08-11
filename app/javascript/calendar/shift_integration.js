// 既存カレンダーとの統合コード
// app/javascript/calendar/shift_integration.js



// 既存のカレンダー初期化関数を拡張
export function enhanceCalendarWithShiftHighlight() {
  // 既存のinitializeCalendar関数を拡張
  const originalInitialize = window.initializeCalendar;
  
  window.initializeCalendar = function() {
    console.log('🔧 Enhanced calendar initialization starting...');
    
    // 元の初期化を実行
    if (originalInitialize) {
      originalInitialize();
    }
    
    // シフトハイライト機能を追加
    const calendar = window.pageCalendar;
    if (calendar) {
      setupShiftHighlightIntegration(calendar);
    } else {
      console.warn('⚠️ Calendar not found, retrying...');
      setTimeout(() => {
        const retryCalendar = window.pageCalendar;
        if (retryCalendar) {
          setupShiftHighlightIntegration(retryCalendar);
        }
      }, 1000);
    }
  };
}

// シフトハイライト統合の設定
function setupShiftHighlightIntegration(calendar) {
  console.log('🎨 Setting up shift highlight integration...');
  
  // 動的ハイライト機能は削除（CSSのみでグリッドライン表示）
  const highlighter = null;
  
  // 既存のイベントハンドラーを拡張
  enhanceExistingEventHandlers(calendar, highlighter);
  
  // 設定変更の監視
  setupSettingsChangeListener(highlighter);
  
  // UIコントロールの追加
  addShiftControlsToCalendar(highlighter);
  
  console.log('✅ Shift highlight integration complete');
}

// 既存のイベントハンドラーを拡張
function enhanceExistingEventHandlers(calendar, highlighter) {
  // 予約の追加/削除/変更時にハイライトを更新
  const originalEventDrop = calendar.getOption('eventDrop');
  const originalEventResize = calendar.getOption('eventResize');
  const originalEventAdd = calendar.getOption('eventAdd');
  const originalEventRemove = calendar.getOption('eventRemove');
  
  // イベント移動時
  calendar.setOption('eventDrop', function(info) {
    console.log('📅 Event dropped, refreshing highlights...');
    
    // 元の処理を実行
    if (originalEventDrop) {
      originalEventDrop(info);
    }
    
    // ハイライトを更新
    setTimeout(() => {
      refreshAvailableTimeHighlights(highlighter);
    }, 500);
  });
  
  // イベントリサイズ時
  calendar.setOption('eventResize', function(info) {
    console.log('📏 Event resized, refreshing highlights...');
    
    if (originalEventResize) {
      originalEventResize(info);
    }
    
    setTimeout(() => {
      refreshAvailableTimeHighlights(highlighter);
    }, 500);
  });
  
  // イベント追加時
  calendar.setOption('eventAdd', function(info) {
    console.log('➕ Event added, refreshing highlights...');
    
    if (originalEventAdd) {
      originalEventAdd(info);
    }
    
    setTimeout(() => {
      refreshAvailableTimeHighlights(highlighter);
    }, 500);
  });
  
  // イベント削除時
  calendar.setOption('eventRemove', function(info) {
    console.log('➖ Event removed, refreshing highlights...');
    
    if (originalEventRemove) {
      originalEventRemove(info);
    }
    
    setTimeout(() => {
      refreshAvailableTimeHighlights(highlighter);
    }, 500);
  });
}

// 利用可能時間のハイライト更新
function refreshAvailableTimeHighlights(highlighter) {
  // 現在の予約状況を取得
  const events = window.pageCalendar.getEvents();
  const currentDate = window.pageCalendar.view.getCurrentData().currentDate;
  
  // 空き時間を計算してハイライト
  const availableSlots = calculateAvailableSlots(events, currentDate);
  updateAvailableSlotStyles(availableSlots);
}

// 空き時間スロットの計算
function calculateAvailableSlots(events, targetDate) {
  const businessStart = currentBusinessHours.start;
  const businessEnd = currentBusinessHours.end;
  const slotDuration = 10; // 10分間隔
  
  const availableSlots = [];
  
  // 営業時間内の全スロットを生成
  for (let hour = businessStart; hour < businessEnd; hour++) {
    for (let minute = 0; minute < 60; minute += slotDuration) {
      const slotStart = new Date(targetDate);
      slotStart.setHours(hour, minute, 0, 0);
      
      const slotEnd = new Date(slotStart);
      slotEnd.setMinutes(slotEnd.getMinutes() + slotDuration);
      
      // このスロットが空いているかチェック
      const isAvailable = !events.some(event => {
        const eventStart = new Date(event.start);
        const eventEnd = new Date(event.end);
        
        return (slotStart < eventEnd && slotEnd > eventStart);
      });
      
      if (isAvailable) {
        const slotIndex = ((hour - 10) * 6) + (minute / 10);
        availableSlots.push({
          hour,
          minute,
          slotIndex,
          time: `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`
        });
      }
    }
  }
  
  return availableSlots;
}

// 空きスロットのスタイル更新
function updateAvailableSlotStyles(availableSlots) {
  // 既存のavailableクラスを削除
  document.querySelectorAll('.fc-timegrid-slot.available-hour').forEach(slot => {
    slot.classList.remove('available-hour');
  });
  
  // 新しい空きスロットにクラスを追加
  availableSlots.forEach(slot => {
    const slotEl = document.querySelector(`.fc-timegrid-slots tr:nth-child(${slot.slotIndex + 1}) .fc-timegrid-slot`);
    if (slotEl) {
      slotEl.classList.add('available-hour');
      slotEl.setAttribute('data-available-time', slot.time);
    }
  });
  
  console.log(`🎯 Updated ${availableSlots.length} available time slots`);
}

// 設定変更の監視
function setupSettingsChangeListener(highlighter) {
  // MutationObserverで設定変更を監視
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === 'attributes' && 
          (mutation.attributeName === 'data-business-start' || 
           mutation.attributeName === 'data-business-end')) {
        
        const start = parseInt(document.body.getAttribute('data-business-start') || '10');
        const end = parseInt(document.body.getAttribute('data-business-end') || '21');
        
        console.log('⚙️ Settings changed, updating highlights...');
        highlighter.changeShift(start, end);
      }
    });
  });
  
  observer.observe(document.body, {
    attributes: true,
    attributeFilter: ['data-business-start', 'data-business-end']
  });
}

// カレンダーにシフトコントロールを追加
function addShiftControlsToCalendar(highlighter) {
  const calendarToolbar = document.querySelector('.fc-toolbar');
  if (!calendarToolbar) return;
  
  // シフト調整ボタンを作成
  const shiftButton = document.createElement('button');
  shiftButton.className = 'fc-button fc-button-primary';
  shiftButton.innerHTML = '⏰ シフト調整';
  shiftButton.type = 'button';
  
  // ボタンクリック時の処理
  shiftButton.addEventListener('click', () => {
    toggleShiftAdjustmentPanel(highlighter);
  });
  
  // ツールバーの右側に追加
  const rightSection = calendarToolbar.querySelector('.fc-toolbar-chunk:last-child');
  if (rightSection) {
    rightSection.appendChild(shiftButton);
  }
}

// シフト調整パネルの表示/非表示
function toggleShiftAdjustmentPanel(highlighter) {
  let panel = document.getElementById('shift-adjustment-panel');
  
  if (panel) {
    // パネルが存在する場合は削除
    panel.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => panel.remove(), 300);
    return;
  }
  
  // パネルを作成
  panel = document.createElement('div');
  panel.id = 'shift-adjustment-panel';
  panel.className = 'shift-adjustment-panel';
  panel.innerHTML = `
    <div class="panel-header">
      <h5>⏰ 営業時間調整</h5>
      <button class="btn-close" onclick="this.closest('.shift-adjustment-panel').remove()">×</button>
    </div>
    <div class="panel-body">
      <div class="current-hours">
        <strong>現在:</strong> ${currentBusinessHours.start}:00 - ${currentBusinessHours.end}:00
      </div>
      
      <div class="time-adjustment">
        <label>開始時間: <span id="start-time-display">${currentBusinessHours.start}</span>:00</label>
        <input type="range" id="start-time-slider" min="6" max="15" value="${currentBusinessHours.start}">
        
        <label>終了時間: <span id="end-time-display">${currentBusinessHours.end}</span>:00</label>
        <input type="range" id="end-time-slider" min="16" max="24" value="${currentBusinessHours.end}">
      </div>
      
      <div class="panel-actions">
        <button id="preview-changes" class="btn btn-outline-primary">プレビュー</button>
        <button id="apply-changes" class="btn btn-primary">適用</button>
        <button id="reset-changes" class="btn btn-secondary">リセット</button>
      </div>
    </div>
  `;
  
  // パネルのスタイル
  panel.style.cssText = `
    position: fixed;
    top: 100px;
    right: 20px;
    width: 300px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
    border: 1px solid #dee2e6;
    z-index: 1500;
    animation: slideIn 0.3s ease-out;
  `;
  
  document.body.appendChild(panel);
  
  // パネルのイベントリスナーを設定
  setupPanelEventListeners(panel, highlighter);
}

// パネルのイベントリスナー設定
function setupPanelEventListeners(panel, highlighter) {
  const startSlider = panel.querySelector('#start-time-slider');
  const endSlider = panel.querySelector('#end-time-slider');
  const startDisplay = panel.querySelector('#start-time-display');
  const endDisplay = panel.querySelector('#end-time-display');
  const previewBtn = panel.querySelector('#preview-changes');
  const applyBtn = panel.querySelector('#apply-changes');
  const resetBtn = panel.querySelector('#reset-changes');
  
  // スライダーの値表示更新
  startSlider.addEventListener('input', () => {
    const value = parseInt(startSlider.value);
    startDisplay.textContent = value;
    
    // 終了時間が開始時間より早い場合は調整
    if (parseInt(endSlider.value) <= value) {
      endSlider.value = value + 1;
      endDisplay.textContent = value + 1;
    }
  });
  
  endSlider.addEventListener('input', () => {
    const value = parseInt(endSlider.value);
    endDisplay.textContent = value;
    
    // 開始時間が終了時間より遅い場合は調整
    if (parseInt(startSlider.value) >= value) {
      startSlider.value = value - 1;
      startDisplay.textContent = value - 1;
    }
  });
  
  // プレビューボタン
  previewBtn.addEventListener('click', () => {
    const start = parseInt(startSlider.value);
    const end = parseInt(endSlider.value);
    
    console.log('👁️ Previewing shift change:', `${start}:00-${end}:00`);
    highlighter.changeShift(start, end);
    
    // プレビュー状態を表示
    showPreviewNotification(start, end);
  });
  
  // 適用ボタン
  applyBtn.addEventListener('click', async () => {
    const start = parseInt(startSlider.value);
    const end = parseInt(endSlider.value);
    
    console.log('💾 Applying shift change:', `${start}:00-${end}:00`);
    
    try {
      // サーバーに保存
      await saveBusinessHoursToServer(start, end);
      
      // ハイライトを更新
      highlighter.changeShift(start, end);
      
      // 成功通知
      showSuccessNotification(start, end);
      
      // パネルを閉じる
      panel.remove();
      
    } catch (error) {
      console.error('❌ Failed to apply changes:', error);
      showErrorNotification();
    }
  });
  
  // リセットボタン
  resetBtn.addEventListener('click', () => {
    // デフォルト値に戻す
    const defaultStart = 10;
    const defaultEnd = 21;
    
    startSlider.value = defaultStart;
    endSlider.value = defaultEnd;
    startDisplay.textContent = defaultStart;
    endDisplay.textContent = defaultEnd;
    
    // プレビュー
    highlighter.changeShift(defaultStart, defaultEnd);
    
    console.log('🔄 Reset to default hours');
  });
}

// プレビュー通知の表示
function showPreviewNotification(start, end) {
  const notification = document.createElement('div');
  notification.className = 'preview-notification';
  notification.innerHTML = `
    <div class="notification-content">
      <div class="notification-icon">👁️</div>
      <div class="notification-text">
        <strong>プレビュー中</strong><br>
        営業時間: ${start}:00 - ${end}:00
      </div>
    </div>
  `;
  
  notification.style.cssText = `
    position: fixed;
    top: 150px;
    right: 20px;
    background: rgba(255, 193, 7, 0.95);
    color: #212529;
    padding: 15px;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    z-index: 1600;
    animation: slideIn 0.3s ease-out;
    border: 2px solid #ffc107;
  `;
  
  document.body.appendChild(notification);
  
  // 3秒後に自動削除
  setTimeout(() => {
    notification.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => notification.remove(), 300);
  }, 3000);
}

// 成功通知の表示
function showSuccessNotification(start, end) {
  const notification = document.createElement('div');
  notification.className = 'success-notification';
  notification.innerHTML = `
    <div class="notification-content">
      <div class="notification-icon">✅</div>
      <div class="notification-text">
        <strong>更新完了</strong><br>
        営業時間: ${start}:00 - ${end}:00
      </div>
    </div>
  `;
  
  notification.style.cssText = `
    position: fixed;
    top: 150px;
    right: 20px;
    background: rgba(40, 167, 69, 0.95);
    color: white;
    padding: 15px;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    z-index: 1600;
    animation: slideIn 0.3s ease-out;
    border: 2px solid #28a745;
  `;
  
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => notification.remove(), 300);
  }, 4000);
}

// エラー通知の表示
function showErrorNotification() {
  const notification = document.createElement('div');
  notification.className = 'error-notification';
  notification.innerHTML = `
    <div class="notification-content">
      <div class="notification-icon">❌</div>
      <div class="notification-text">
        <strong>エラー</strong><br>
        設定の保存に失敗しました
      </div>
    </div>
  `;
  
  notification.style.cssText = `
    position: fixed;
    top: 150px;
    right: 20px;
    background: rgba(220, 53, 69, 0.95);
    color: white;
    padding: 15px;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    z-index: 1600;
    animation: slideIn 0.3s ease-out;
    border: 2px solid #dc3545;
  `;
  
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => notification.remove(), 300);
  }, 5000);
}

// 設定変更の監視
function setupSettingsChangeListener(highlighter) {
  // WebSocketまたはPollingで設定変更を監視（オプション）
  if (window.ActionCable) {
    const subscription = window.ActionCable.createConsumer().subscriptions.create(
      { channel: "SettingsChannel" },
      {
        received: function(data) {
          if (data.type === 'business_hours_changed') {
            console.log('📡 Business hours changed via WebSocket:', data);
            highlighter.changeShift(data.start_hour, data.end_hour);
            
            showRemoteChangeNotification(data.start_hour, data.end_hour);
          }
        }
      }
    );
  }
  
  // ページ間での設定変更を監視（localStorage使用）
  window.addEventListener('storage', (e) => {
    if (e.key === 'businessHoursChanged') {
      const data = JSON.parse(e.newValue);
      console.log('💾 Business hours changed in another tab:', data);
      
      highlighter.changeShift(data.start, data.end);
      showRemoteChangeNotification(data.start, data.end);
    }
  });
}

// リモート変更通知
function showRemoteChangeNotification(start, end) {
  const notification = document.createElement('div');
  notification.className = 'remote-change-notification';
  notification.innerHTML = `
    <div class="notification-content">
      <div class="notification-icon">🔄</div>
      <div class="notification-text">
        <strong>設定が更新されました</strong><br>
        新しい営業時間: ${start}:00 - ${end}:00
      </div>
    </div>
  `;
  
  notification.style.cssText = `
    position: fixed;
    top: 150px;
    left: 20px;
    background: rgba(23, 162, 184, 0.95);
    color: white;
    padding: 15px;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    z-index: 1600;
    animation: slideInLeft 0.3s ease-out;
    border: 2px solid #17a2b8;
  `;
  
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.animation = 'slideOutLeft 0.3s ease-in';
    setTimeout(() => notification.remove(), 300);
  }, 4000);
}

// サーバーへの保存（非同期）
async function saveBusinessHoursToServer(startHour, endHour) {
  const response = await fetch('/admin/settings/update_business_hours', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({
      application_setting: {
        business_hours_start: startHour,
        business_hours_end: endHour
      }
    })
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  const data = await response.json();
  
  if (!data.success) {
    throw new Error(data.error || 'Unknown error');
  }
  
  // ローカルストレージに変更を記録（他のタブに通知）
  localStorage.setItem('businessHoursChanged', JSON.stringify({
    start: startHour,
    end: endHour,
    timestamp: Date.now()
  }));
  
  return data;
}

// クイックアクション関数群（動的機能は削除）
export const ShiftQuickActions = {
  // 営業時間を1時間早める
  extendMorning: () => {
    console.log('🌅 Extended morning hours (functionality removed)');
  },
  
  // 営業時間を1時間延長
  extendEvening: () => {
    console.log('🌙 Extended evening hours (functionality removed)');
  },
  
  // 営業時間を1時間短縮（朝）
  reduceMorning: () => {
    console.log('⏰ Reduced morning hours (functionality removed)');
  },
  
  // 営業時間を1時間短縮（夜）
  reduceEvening: () => {
    console.log('🕰️ Reduced evening hours (functionality removed)');
  },
  
  // 標準営業時間に戻す
  resetToDefault: () => {
    console.log('🔄 Reset to default business hours (functionality removed)');
  }
};

// キーボードショートカット設定
function setupKeyboardShortcuts() {
  document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + Shift + キー
    if ((e.ctrlKey || e.metaKey) && e.shiftKey) {
      switch(e.key) {
        case 'ArrowUp':
          e.preventDefault();
          ShiftQuickActions.extendEvening();
          break;
        case 'ArrowDown':
          e.preventDefault();
          ShiftQuickActions.reduceEvening();
          break;
        case 'ArrowLeft':
          e.preventDefault();
          ShiftQuickActions.extendMorning();
          break;
        case 'ArrowRight':
          e.preventDefault();
          ShiftQuickActions.reduceMorning();
          break;
        case 'r':
          e.preventDefault();
          ShiftQuickActions.resetToDefault();
          break;
      }
    }
  });
  
  console.log('⌨️ Keyboard shortcuts enabled:');
  console.log('  Ctrl+Shift+↑: 営業時間延長（夜）');
  console.log('  Ctrl+Shift+↓: 営業時間短縮（夜）');
  console.log('  Ctrl+Shift+←: 営業時間延長（朝）');
  console.log('  Ctrl+Shift+→: 営業時間短縮（朝）');
  console.log('  Ctrl+Shift+R: デフォルトに戻す');
}

// 追加のアニメーションスタイルを動的に挿入
function injectAdditionalStyles() {
  const additionalStyles = document.createElement('style');
  additionalStyles.id = 'shift-integration-styles';
  additionalStyles.textContent = `
    /* パネルアニメーション */
    @keyframes slideIn {
      from {
        opacity: 0;
        transform: translateX(100%);
      }
      to {
        opacity: 1;
        transform: translateX(0);
      }
    }
    
    @keyframes slideOut {
      from {
        opacity: 1;
        transform: translateX(0);
      }
      to {
        opacity: 0;
        transform: translateX(100%);
      }
    }
    
    @keyframes slideInLeft {
      from {
        opacity: 0;
        transform: translateX(-100%);
      }
      to {
        opacity: 1;
        transform: translateX(0);
      }
    }
    
    @keyframes slideOutLeft {
      from {
        opacity: 1;
        transform: translateX(0);
      }
      to {
        opacity: 0;
        transform: translateX(-100%);
      }
    }
    
    /* パネルスタイル */
    .shift-adjustment-panel .panel-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 15px 20px;
      border-bottom: 1px solid #dee2e6;
      background: #f8f9fa;
      border-radius: 12px 12px 0 0;
    }
    
    .shift-adjustment-panel .panel-header h5 {
      margin: 0;
      color: #495057;
    }
    
    .shift-adjustment-panel .btn-close {
      background: none;
      border: none;
      font-size: 1.2rem;
      color: #6c757d;
      cursor: pointer;
      padding: 0;
      width: 24px;
      height: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      transition: all 0.2s ease;
    }
    
    .shift-adjustment-panel .btn-close:hover {
      background: rgba(220, 53, 69, 0.1);
      color: #dc3545;
    }
    
    .shift-adjustment-panel .panel-body {
      padding: 20px;
    }
    
    .shift-adjustment-panel .current-hours {
      background: #e3f2fd;
      padding: 10px;
      border-radius: 6px;
      margin-bottom: 15px;
      text-align: center;
      border-left: 4px solid #2196f3;
    }
    
    .shift-adjustment-panel .time-adjustment {
      margin-bottom: 20px;
    }
    
    .shift-adjustment-panel .time-adjustment label {
      display: block;
      margin-bottom: 5px;
      font-weight: 500;
      color: #495057;
    }
    
    .shift-adjustment-panel .time-adjustment input[type="range"] {
      width: 100%;
      margin-bottom: 15px;
    }
    
    .shift-adjustment-panel .panel-actions {
      display: flex;
      gap: 8px;
      justify-content: space-between;
    }
    
    .shift-adjustment-panel .btn {
      flex: 1;
      padding: 8px 12px;
      border: none;
      border-radius: 6px;
      font-size: 0.9rem;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    
    .shift-adjustment-panel .btn-primary {
      background: #007bff;
      color: white;
    }
    
    .shift-adjustment-panel .btn-primary:hover {
      background: #0056b3;
      transform: translateY(-1px);
    }
    
    .shift-adjustment-panel .btn-outline-primary {
      background: transparent;
      color: #007bff;
      border: 1px solid #007bff;
    }
    
    .shift-adjustment-panel .btn-outline-primary:hover {
      background: #007bff;
      color: white;
    }
    
    .shift-adjustment-panel .btn-secondary {
      background: #6c757d;
      color: white;
    }
    
    .shift-adjustment-panel .btn-secondary:hover {
      background: #545b62;
    }
    
    /* 通知コンテンツのスタイル */
    .notification-content {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    
    .notification-icon {
      font-size: 1.2rem;
    }
    
    .notification-text {
      flex: 1;
    }
  `;
  
  document.head.appendChild(additionalStyles);
}

// メイン初期化関数
export function initializeShiftIntegration() {
  console.log('🚀 Initializing shift integration...');
  
  // スタイルを挿入
  injectAdditionalStyles();
  
  // カレンダー拡張
  enhanceCalendarWithShiftHighlight();
  
  // キーボードショートカット設定
  setupKeyboardShortcuts();
  
  // クイックアクションをグローバルに公開
  window.ShiftQuickActions = ShiftQuickActions;
  
  // 開発用のテスト機能
  if (window.location.hostname === 'localhost' || window.location.hostname.includes('dev')) {
    window.testShiftHighlight = () => {
      console.log('🧪 Running shift highlight tests...');
      
      setTimeout(() => ShiftQuickActions.extendMorning(), 1000);
      setTimeout(() => ShiftQuickActions.extendEvening(), 2000);
      setTimeout(() => ShiftQuickActions.reduceMorning(), 3000);
      setTimeout(() => ShiftQuickActions.reduceEvening(), 4000);
      setTimeout(() => ShiftQuickActions.resetToDefault(), 5000);
    };
  }
  
  console.log('✅ Shift integration initialized successfully');
}

// 既存のRailsアプリケーションとの統合
document.addEventListener('DOMContentLoaded', () => {
  // DOM読み込み完了後に初期化
  initializeShiftIntegration();
  
  // Turboとの互換性を確保
  document.addEventListener('turbo:load', () => {
    console.log('🔄 Turbo navigation detected, reinitializing...');
    
    // 既存のスタイルとイベントリスナーをクリーンアップ
    const existingStyles = document.getElementById('shift-integration-styles');
    if (existingStyles) {
      existingStyles.remove();
    }
    
    const existingPanel = document.getElementById('shift-adjustment-panel');
    if (existingPanel) {
      existingPanel.remove();
    }
    
    // 再初期化
    setTimeout(() => {
      initializeShiftIntegration();
    }, 100);
  });
});

// エクスポート
export {
  enhanceCalendarWithShiftHighlight,
  ShiftQuickActions,
  initializeShiftIntegration
}; 