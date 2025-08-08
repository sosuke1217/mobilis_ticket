// 動的シフト時間枠ハイライト機能
// app/javascript/calendar/dynamic_shift_highlight.js

// 現在の営業時間状態を保持
let currentBusinessHours = {
  start: 10, // デフォルト10時
  end: 21,   // デフォルト21時
  sundayClosed: true
};

// 時間枠のハイライト状態を管理
class ShiftHighlighter {
  constructor(calendar) {
    this.calendar = calendar;
    this.highlightStyles = null;
    this.init();
  }

  init() {
    // 動的スタイルシートを作成
    this.createDynamicStyles();
    
    // 初期状態でハイライトを適用
    this.updateTimeSlotHighlight(currentBusinessHours.start, currentBusinessHours.end);
  }

  // 動的スタイルシートの作成
  createDynamicStyles() {
    if (document.getElementById('dynamic-shift-highlight')) {
      document.getElementById('dynamic-shift-highlight').remove();
    }

    this.highlightStyles = document.createElement('style');
    this.highlightStyles.id = 'dynamic-shift-highlight';
    document.head.appendChild(this.highlightStyles);
  }

  // 時間枠のハイライト更新
  updateTimeSlotHighlight(startHour, endHour) {
    console.log(`🕒 Updating highlight: ${startHour}:00-${endHour}:00`);
    
    // 営業時間を更新
    currentBusinessHours = { start: startHour, end: endHour };
    
    // CSSルールを生成
    const css = this.generateHighlightCSS(startHour, endHour);
    this.highlightStyles.textContent = css;
    
    // 時間枠にクラスを適用
    this.applyTimeSlotClasses(startHour, endHour);
    
    // FullCalendarのbusinessHoursを動的更新
    this.updateCalendarBusinessHours(startHour, endHour);
    
    // 視覚的フィードバック
    this.showChangeAnimation();
  }
  
  // 時間枠にクラスを適用
  applyTimeSlotClasses(startHour, endHour) {
    const timeSlots = document.querySelectorAll('.fc-timegrid-slot');
    
    timeSlots.forEach((slot, index) => {
      const hour = Math.floor(index / 6) + 10; // 10分間隔で計算
      
      // 既存のクラスをクリア
      slot.classList.remove('business-hour', 'non-business-hour', 'business-start', 'business-end', 
                           'morning-hour', 'late-morning-hour', 'afternoon-hour', 'evening-hour', 'night-hour');
      
      // データ属性を設定
      slot.setAttribute('data-slot-index', index);
      slot.setAttribute('data-time-hour', hour);
      
      // 営業時間内かどうかチェック
      if (hour >= startHour && hour < endHour) {
        slot.classList.add('business-hour');
        
        // 営業開始/終了の境界をマーク
        if (hour === startHour) {
          slot.classList.add('business-start');
        }
        if (hour === endHour - 1) {
          slot.classList.add('business-end');
        }
        
        // 時間帯別のクラスを追加
        if (hour >= 6 && hour < 10) {
          slot.classList.add('morning-hour');
          slot.setAttribute('data-time-period', 'morning');
        } else if (hour >= 10 && hour < 12) {
          slot.classList.add('late-morning-hour');
          slot.setAttribute('data-time-period', 'late-morning');
        } else if (hour >= 12 && hour < 17) {
          slot.classList.add('afternoon-hour');
          slot.setAttribute('data-time-period', 'afternoon');
        } else if (hour >= 17 && hour < 21) {
          slot.classList.add('evening-hour');
          slot.setAttribute('data-time-period', 'evening');
        } else {
          slot.classList.add('night-hour');
          slot.setAttribute('data-time-period', 'night');
        }
      } else {
        slot.classList.add('non-business-hour');
      }
    });
  }

  // ハイライト用CSSを生成
  generateHighlightCSS(startHour, endHour) {
    const businessHourSlots = this.calculateBusinessHourSlots(startHour, endHour);
    
    return `
      /* 全ての時間枠を暗くリセット */
      .fc-timegrid-slot {
        background-color: rgba(0, 0, 0, 0.02) !important;
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
        position: relative !important;
      }
      
      /* 営業時間内の時間枠を明るくハイライト */
      ${businessHourSlots.map(slot => `
        .fc-timegrid-slots tr:nth-child(${slot}) .fc-timegrid-slot {
          background-color: rgba(40, 167, 69, 0.08) !important;
          border-left: 2px solid rgba(40, 167, 69, 0.3) !important;
        }
      `).join('\n')}
      
      /* 営業時間外の背景 */
      .fc-timegrid-slot.non-business-hour {
        background-color: rgba(0, 0, 0, 0.08) !important;
        border-left: 1px solid rgba(0, 0, 0, 0.1) !important;
      }
      
      /* 営業開始/終了の境界線強調 */
      .fc-timegrid-slot.business-start {
        border-top: 3px solid #28a745 !important;
        background: linear-gradient(to bottom, 
          rgba(40, 167, 69, 0.2) 0%, 
          rgba(40, 167, 69, 0.12) 100%) !important;
      }
      
      .fc-timegrid-slot.business-end {
        border-bottom: 3px solid #28a745 !important;
        background: linear-gradient(to bottom, 
          rgba(40, 167, 69, 0.12) 0%, 
          rgba(40, 167, 69, 0.2) 100%) !important;
              }
        
        /* 時間帯別のカラーリング */
        .fc-timegrid-slot[data-time-period="morning"] {
          background: linear-gradient(to bottom, 
            rgba(255, 183, 77, 0.08) 0%, 
            rgba(255, 193, 7, 0.05) 100%) !important;
        }
        
        .fc-timegrid-slot[data-time-period="late-morning"] {
          background: linear-gradient(to bottom, 
            rgba(40, 167, 69, 0.10) 0%, 
            rgba(40, 167, 69, 0.08) 100%) !important;
        }
        
        .fc-timegrid-slot[data-time-period="afternoon"] {
          background: linear-gradient(to bottom, 
            rgba(40, 167, 69, 0.12) 0%, 
            rgba(32, 201, 151, 0.08) 100%) !important;
        }
        
        .fc-timegrid-slot[data-time-period="evening"] {
          background: linear-gradient(to bottom, 
            rgba(23, 162, 184, 0.10) 0%, 
            rgba(40, 167, 69, 0.08) 100%) !important;
        }
        
        .fc-timegrid-slot[data-time-period="night"] {
          background: linear-gradient(to bottom, 
            rgba(108, 117, 125, 0.08) 0%, 
            rgba(0, 0, 0, 0.05) 100%) !important;
        }
        
        /* アニメーション効果 */
        .shift-highlight-animation {
          animation: shiftChangeGlow 1.2s ease-in-out !important;
        }
        
        @keyframes shiftChangeGlow {
          0% { 
            box-shadow: 0 0 0 rgba(40, 167, 69, 0);
            filter: brightness(1);
          }
          50% { 
            box-shadow: 0 0 30px rgba(40, 167, 69, 0.3);
            filter: brightness(1.05);
          }
          100% { 
            box-shadow: 0 0 0 rgba(40, 167, 69, 0);
            filter: brightness(1);
          }
        }
        
        /* 時間枠拡張時のアニメーション */
        .time-slot-expanded {
          animation: expandGlow 0.8s ease-out;
        }
        
        @keyframes expandGlow {
          0% { 
            background-color: rgba(40, 167, 69, 0.08) !important;
            transform: scale(1);
          }
        50% { 
          background-color: rgba(40, 167, 69, 0.3) !important;
          transform: scale(1.02);
        }
        100% { 
          background-color: rgba(40, 167, 69, 0.1) !important;
          transform: scale(1);
        }
      }
      
      /* 時間枠短縮時のアニメーション */
      .time-slot-reduced {
        animation: reduceGlow 0.8s ease-out;
      }
      
      @keyframes reduceGlow {
        0% { 
          background-color: rgba(40, 167, 69, 0.1) !important;
          transform: scale(1);
        }
        50% { 
          background-color: rgba(220, 53, 69, 0.2) !important;
          transform: scale(0.98);
        }
        100% { 
          background-color: rgba(0, 0, 0, 0.05) !important;
          transform: scale(1);
        }
      }
    `;
  }

  // 営業時間に対応するスロット番号を計算
  calculateBusinessHourSlots(startHour, endHour) {
    const slots = [];
    
    // FullCalendarは10分間隔なので、1時間=6スロット
    // 10:00が0番目のスロットとして計算
    const baseHour = 10; // カレンダーの開始時間
    const slotsPerHour = 6; // 10分間隔なので1時間に6スロット
    
    for (let hour = startHour; hour < endHour; hour++) {
      const hourOffset = hour - baseHour;
      const startSlot = hourOffset * slotsPerHour;
      
      // その時間の全スロット（0, 10, 20, 30, 40, 50分）を追加
      for (let i = 0; i < slotsPerHour; i++) {
        const slotIndex = startSlot + i;
        if (slotIndex >= 0) { // 負の値は除外
          slots.push(slotIndex);
        }
      }
    }
    
    return slots;
  }

  // FullCalendarのbusinessHoursを動的更新
  updateCalendarBusinessHours(startHour, endHour) {
    if (!this.calendar) return;
    
    const businessHours = {
      startTime: `${startHour.toString().padStart(2, '0')}:00`,
      endTime: `${endHour.toString().padStart(2, '0')}:00`,
      daysOfWeek: currentBusinessHours.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6]
    };
    
    console.log('📅 Updating calendar business hours:', businessHours);
    
    // setOptionを使用してbusinessHoursを更新
    this.calendar.setOption('businessHours', businessHours);
    
    // カレンダーを再描画
    this.calendar.render();
  }

  // 変更アニメーションを表示
  showChangeAnimation() {
    const calendarEl = document.getElementById('calendar');
    if (calendarEl) {
      calendarEl.classList.add('shift-highlight-animation');
      setTimeout(() => {
        calendarEl.classList.remove('shift-highlight-animation');
      }, 1000);
    }
  }

  // 時間枠拡張時のアニメーション
  animateExpansion(addedSlots) {
    addedSlots.forEach((slotIndex, i) => {
      setTimeout(() => {
        const slotEl = document.querySelector(`.fc-timegrid-slots tr:nth-child(${slotIndex}) .fc-timegrid-slot`);
        if (slotEl) {
          slotEl.classList.add('time-slot-expanded', 'time-slot-ripple');
          slotEl.style.setProperty('--slot-index', i);
          
          // パーティクル効果を追加
          this.addSparkleEffect(slotEl);
          
          setTimeout(() => {
            slotEl.classList.remove('time-slot-expanded', 'time-slot-ripple');
          }, 800);
        }
      }, i * 100); // 順次アニメーション
    });
  }

  // 時間枠短縮時のアニメーション
  animateReduction(removedSlots) {
    removedSlots.forEach((slotIndex, i) => {
      setTimeout(() => {
        const slotEl = document.querySelector(`.fc-timegrid-slots tr:nth-child(${slotIndex}) .fc-timegrid-slot`);
        if (slotEl) {
          slotEl.classList.add('time-slot-reduced', 'time-slot-reduce-indicator');
          slotEl.style.setProperty('--slot-index', i);
          
          setTimeout(() => {
            slotEl.classList.remove('time-slot-reduced', 'time-slot-reduce-indicator');
          }, 800);
        }
      }, i * 100);
    });
  }
  
  // パーティクル効果を追加
  addSparkleEffect(slotEl) {
    const sparkle = document.createElement('div');
    sparkle.className = 'time-slot-sparkle';
    sparkle.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      font-size: 1rem;
      pointer-events: none;
      z-index: 10;
    `;
    sparkle.textContent = '✨';
    
    slotEl.appendChild(sparkle);
    
    setTimeout(() => {
      sparkle.remove();
    }, 1000);
  }

  // シフト変更の処理
  changeShift(newStartHour, newEndHour, animationType = 'change') {
    const oldSlots = this.calculateBusinessHourSlots(currentBusinessHours.start, currentBusinessHours.end);
    const newSlots = this.calculateBusinessHourSlots(newStartHour, newEndHour);
    
    // 変更内容を分析
    const addedSlots = newSlots.filter(slot => !oldSlots.includes(slot));
    const removedSlots = oldSlots.filter(slot => !newSlots.includes(slot));
    
    console.log('📊 Shift change analysis:', {
      old: `${currentBusinessHours.start}:00-${currentBusinessHours.end}:00`,
      new: `${newStartHour}:00-${newEndHour}:00`,
      addedSlots,
      removedSlots
    });
    
    // アニメーションを実行
    if (addedSlots.length > 0) {
      this.animateExpansion(addedSlots);
    }
    if (removedSlots.length > 0) {
      this.animateReduction(removedSlots);
    }
    
    // 少し遅れてハイライト更新
    setTimeout(() => {
      this.updateTimeSlotHighlight(newStartHour, newEndHour);
    }, 300);
  }
  
  // グリッド背景色を更新する関数
  updateGridBackgroundColors() {
    console.log('🔄 グリッド背景色を更新中...');
    
    // 現在の営業時間でハイライトを更新
    this.updateTimeSlotHighlight(currentBusinessHours.start, currentBusinessHours.end);
    
    // シフトデータを取得して特定日の営業時間を更新
    fetch('/admin/shifts.json')
      .then(response => response.json())
      .then(shifts => {
        console.log('🔄 シフトデータで背景色を更新:', shifts);
        
        // 各シフトの日付で背景色を更新
        shifts.forEach(shift => {
          if (shift.start_time && shift.end_time) {
            const startHour = parseInt(shift.start_time.split(':')[0]);
            const endHour = parseInt(shift.end_time.split(':')[0]);
            
            // 特定日の営業時間を更新
            this.updateSpecificDateHighlight(shift.date, startHour, endHour);
          }
        });
      })
      .catch(error => {
        console.error('❌ シフトデータ取得エラー:', error);
      });
  }
  
  // 特定日の営業時間を更新
  updateSpecificDateHighlight(date, startHour, endHour) {
    const dateStr = date;
    const dateCells = document.querySelectorAll(`[data-date="${dateStr}"]`);
    
    dateCells.forEach(cell => {
      // 既存のシフト関連クラスをクリア
      cell.classList.remove('has-shift', 'shift-extended', 'shift-regular', 'shift-reduced');
      
      // シフトタイプに応じてクラスを追加
      if (endHour - startHour > 8) {
        cell.classList.add('has-shift', 'shift-extended');
      } else if (endHour - startHour < 6) {
        cell.classList.add('has-shift', 'shift-reduced');
      } else {
        cell.classList.add('has-shift', 'shift-regular');
      }
    });
  }
}

// グローバルハイライターインスタンス
let shiftHighlighter = null;

// カレンダー初期化時に呼び出し
export function initializeShiftHighlighter(calendar) {
  console.log('🎨 Initializing shift highlighter...');
  shiftHighlighter = new ShiftHighlighter(calendar);
  
  // グローバルに公開
  window.shiftHighlighter = shiftHighlighter;
  
  return shiftHighlighter;
}

// 外部からシフト変更を呼び出すための関数
export function changeBusinessHours(startHour, endHour) {
  if (shiftHighlighter) {
    shiftHighlighter.changeShift(startHour, endHour);
  } else {
    console.warn('⚠️ Shift highlighter not initialized');
  }
}

// 営業時間設定フォームとの連携
export function setupBusinessHoursFormIntegration() {
  const startInput = document.getElementById('application_setting_business_hours_start');
  const endInput = document.getElementById('application_setting_business_hours_end');
  
  if (startInput && endInput) {
    function handleBusinessHoursChange() {
      const startHour = parseInt(startInput.value);
      const endHour = parseInt(endInput.value);
      
      if (startHour >= 0 && endHour > startHour && endHour <= 24) {
        changeBusinessHours(startHour, endHour);
      }
    }
    
    startInput.addEventListener('change', handleBusinessHoursChange);
    endInput.addEventListener('change', handleBusinessHoursChange);
    
    console.log('✅ Business hours form integration set up');
  }
}

// 個別のシフト調整UI（カレンダー上での直接操作）
export function createShiftAdjustmentUI() {
  const shiftControls = document.createElement('div');
  shiftControls.className = 'shift-controls position-fixed';
  shiftControls.style.cssText = `
    top: 20px;
    right: 20px;
    background: white;
    padding: 15px;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    z-index: 1000;
    border: 1px solid #dee2e6;
    min-width: 200px;
  `;
  
  shiftControls.innerHTML = `
    <h6>⏰ 営業時間調整</h6>
    <div class="mb-2">
      <label class="form-label text-sm">開始時間</label>
      <input type="range" id="shift-start" min="6" max="12" value="${currentBusinessHours.start}" 
             class="form-range">
      <div class="d-flex justify-content-between text-sm">
        <span>6時</span>
        <span id="start-display">${currentBusinessHours.start}時</span>
        <span>12時</span>
      </div>
    </div>
    <div class="mb-3">
      <label class="form-label text-sm">終了時間</label>
      <input type="range" id="shift-end" min="18" max="24" value="${currentBusinessHours.end}" 
             class="form-range">
      <div class="d-flex justify-content-between text-sm">
        <span>18時</span>
        <span id="end-display">${currentBusinessHours.end}時</span>
        <span>24時</span>
      </div>
    </div>
    <button id="apply-shift" class="btn btn-primary btn-sm w-100">適用</button>
  `;
  
  document.body.appendChild(shiftControls);
  
  // イベントリスナーを設定
  this.setupShiftControlEvents(shiftControls);
  
  return shiftControls;
}

// シフトコントロールのイベント設定
function setupShiftControlEvents(controlsEl) {
  const startSlider = controlsEl.querySelector('#shift-start');
  const endSlider = controlsEl.querySelector('#shift-end');
  const startDisplay = controlsEl.querySelector('#start-display');
  const endDisplay = controlsEl.querySelector('#end-display');
  const applyBtn = controlsEl.querySelector('#apply-shift');
  
  // スライダーの値表示更新
  startSlider.addEventListener('input', () => {
    startDisplay.textContent = `${startSlider.value}時`;
  });
  
  endSlider.addEventListener('input', () => {
    endDisplay.textContent = `${endSlider.value}時`;
  });
  
  // リアルタイムプレビュー（オプション）
  let previewTimeout;
  function previewChange() {
    clearTimeout(previewTimeout);
    previewTimeout = setTimeout(() => {
      const start = parseInt(startSlider.value);
      const end = parseInt(endSlider.value);
      
      if (start < end) {
        shiftHighlighter?.changeShift(start, end);
      }
    }, 500); // 0.5秒後にプレビュー
  }
  
  startSlider.addEventListener('input', previewChange);
  endSlider.addEventListener('input', previewChange);
  
  // 適用ボタン
  applyBtn.addEventListener('click', () => {
    const start = parseInt(startSlider.value);
    const end = parseInt(endSlider.value);
    
    if (start >= end) {
      alert('終了時間は開始時間より後に設定してください');
      return;
    }
    
    // サーバーに保存（オプション）
    saveBusinessHoursToServer(start, end);
    
    // 成功メッセージ
    showTemporaryMessage('✅ 営業時間を更新しました', 'success');
  });
}

// サーバーへの営業時間保存
async function saveBusinessHoursToServer(startHour, endHour) {
  try {
    const response = await fetch('/admin/settings/update_business_hours', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        business_hours_start: startHour,
        business_hours_end: endHour
      })
    });
    
    const data = await response.json();
    
    if (data.success) {
      console.log('✅ Business hours saved to server');
    } else {
      console.error('❌ Failed to save business hours:', data.error);
    }
  } catch (error) {
    console.error('❌ Network error:', error);
  }
}

// 一時的なメッセージ表示
function showTemporaryMessage(message, type = 'info') {
  const messageEl = document.createElement('div');
  messageEl.className = `alert alert-${type} position-fixed`;
  messageEl.style.cssText = `
    top: 80px;
    right: 20px;
    z-index: 1050;
    min-width: 250px;
    animation: slideIn 0.3s ease-out;
  `;
  messageEl.textContent = message;
  
  // スライドインアニメーション
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideIn {
      from { transform: translateX(100%); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }
  `;
  document.head.appendChild(style);
  
  document.body.appendChild(messageEl);
  
  // 3秒後に自動削除
  setTimeout(() => {
    messageEl.style.animation = 'slideOut 0.3s ease-in';
    setTimeout(() => {
      messageEl.remove();
      style.remove();
    }, 300);
  }, 3000);
  
  // スライドアウトアニメーション
  document.head.insertAdjacentHTML('beforeend', `
    <style>
      @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
      }
    </style>
  `);
}

// 既存のカレンダーと統合するための初期化関数
export function initializeDynamicShiftHighlight(calendar) {
  console.log('🚀 Setting up dynamic shift highlight...');
  
  // ハイライターを初期化
  const highlighter = initializeShiftHighlighter(calendar);
  
  // シフト調整UIを作成（オプション）
  // createShiftAdjustmentUI();
  
  // 設定フォームとの連携
  setupBusinessHoursFormIntegration();
  
  // グローバル関数として公開
  window.changeBusinessHours = changeBusinessHours;
  window.shiftHighlighter = highlighter;
  
  console.log('✅ Dynamic shift highlight initialized');
  
  return highlighter;
}

// 使用例とテスト関数
export function testShiftChanges() {
  console.log('🧪 Testing shift changes...');
  
  setTimeout(() => {
    console.log('📈 Testing extension: 10:00-21:00 → 9:00-22:00');
    changeBusinessHours(9, 22);
  }, 2000);
  
  setTimeout(() => {
    console.log('📉 Testing reduction: 9:00-22:00 → 11:00-20:00');
    changeBusinessHours(11, 20);
  }, 5000);
  
  setTimeout(() => {
    console.log('🔄 Returning to default: 11:00-20:00 → 10:00-21:00');
    changeBusinessHours(10, 21);
  }, 8000);
}

// カレンダーコアとの統合
document.addEventListener('DOMContentLoaded', () => {
  // カレンダーが初期化されるまで待機
  const waitForCalendar = () => {
    if (window.pageCalendar) {
      initializeDynamicShiftHighlight(window.pageCalendar);
    } else {
      setTimeout(waitForCalendar, 100);
    }
  };
  
  waitForCalendar();
}); 