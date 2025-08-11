<script>
// 必要な関数を最初に定義
function getCurrentReservationId() {
  return document.getElementById('currentReservationId')?.value || '';
}

function hideSearchResults() {
  const searchResults = document.getElementById('customerSearchResults');
  if (searchResults) {
    searchResults.style.display = 'none';
  }
}

// メッセージ表示関数
function showMessage(message, type = 'info') {
  const alertDiv = document.createElement('div');
  alertDiv.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
  alertDiv.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
  alertDiv.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  `;
  
  // 既存のアラートを削除
  const existingAlerts = document.querySelectorAll('.alert.position-fixed');
  existingAlerts.forEach(alert => alert.remove());
  
  // ページに追加
  document.body.appendChild(alertDiv);
  
  // 3秒後に自動で消す
  setTimeout(() => {
    if (alertDiv.parentNode) {
      alertDiv.remove();
    }
  }, 3000);
}

// showNewCustomerForm関数を修正
window.showNewCustomerForm = function(initialName = '') {
  const newCustomerForm = document.getElementById('newCustomerForm');
  const selectedCustomerInfo = document.getElementById('selectedCustomerInfo');
  
  if (newCustomerForm) {
    newCustomerForm.style.display = 'block';
  }
  if (selectedCustomerInfo) {
    selectedCustomerInfo.style.display = 'none';
  }
  
  const selectedUserId = document.getElementById('selectedUserId');
  if (selectedUserId) {
    selectedUserId.value = '';
  }
  
  // 検索した名前を初期値として設定
  if (initialName) {
    const newCustomerName = document.getElementById('newCustomerName');
    if (newCustomerName) {
      newCustomerName.value = initialName;
    }
  }
  
  hideSearchResults();
  
  // フォーカスを名前フィールドに
  const newCustomerNameField = document.getElementById('newCustomerName');
  if (newCustomerNameField) {
    newCustomerNameField.focus();
  }
};

// DOMContentLoadedイベントリスナー
document.addEventListener('DOMContentLoaded', function() {
  console.log('🚀 DOM Content Loaded');
  
  // カレンダー要素の確認
  const calendarEl = document.getElementById('calendar');
  const monthCalendarEl = document.getElementById('monthCalendarContent');
  
  if (!calendarEl || !monthCalendarEl) {
    console.error('❌ Calendar elements not found');
    return;
  }
  
  console.log('📅 Calendar elements found');
  
  // 年と月の表示を更新する関数
  function updateMonthYearDisplay() {
    if (typeof monthCalendar === 'undefined') return;
    
    const currentDate = monthCalendar.getDate();
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth() + 1;
    const monthNames = ['1月', '2月', '3月', '4月', '5月', '6月', 
                       '7月', '8月', '9月', '10月', '11月', '12月'];
    
    const monthYearElement = document.getElementById('currentMonthYear');
    if (monthYearElement) {
      monthYearElement.textContent = `${year}年 ${monthNames[month - 1]}`;
    }
  }

  // 年と月の選択モーダルを開く関数
  function openMonthYearModal() {
    if (typeof monthCalendar === 'undefined') return;
    
    const currentDate = monthCalendar.getDate();
    const yearSelect = document.getElementById('yearSelect');
    const monthSelect = document.getElementById('monthSelect');
    
    if (!yearSelect || !monthSelect) return;
    
    // 年のオプションを生成（現在の年の前後5年）
    const currentYear = currentDate.getFullYear();
    yearSelect.innerHTML = '';
    for (let year = currentYear - 5; year <= currentYear + 5; year++) {
      const option = document.createElement('option');
      option.value = year;
      option.textContent = `${year}年`;
      if (year === currentYear) {
        option.selected = true;
      }
      yearSelect.appendChild(option);
    }
    
    // 月を設定
    monthSelect.value = currentDate.getMonth() + 1;
    
    // モーダルを開く
    const modalElement = document.getElementById('monthYearModal');
    if (modalElement && typeof bootstrap !== 'undefined') {
      const modal = new bootstrap.Modal(modalElement, {
        backdrop: 'static',
        keyboard: true,
        focus: true
      });
      
      modal.show();
    }
  }

  // ミニカレンダーの初期化
  let monthCalendar;
  try {
    monthCalendar = new FullCalendar.Calendar(monthCalendarEl, {
      initialView: 'dayGridMonth',
      locale: 'ja',
      height: 'auto',
      headerToolbar: false,
      dayHeaderFormat: { weekday: 'short' },
      fixedWeekCount: false,
      showNonCurrentDates: true,
      dayMaxEvents: false,
      eventDisplay: 'none',
      dayCellContent: function(arg) {
        return arg.dayNumberText.replace(/[^\d]/g, '');
      },
      dayCellDidMount: function(info) {
        info.el.style.cursor = 'pointer';
        info.el.addEventListener('click', function() {
          if (typeof calendar !== 'undefined') {
            calendar.gotoDate(info.date);
          }
        });
      }
    });
    
    monthCalendar.render();
    updateMonthYearDisplay();
    console.log('✅ Mini calendar initialized');
  } catch (error) {
    console.error('❌ Mini calendar initialization failed:', error);
  }

  // ナビゲーションボタンのイベントリスナー
  const prevMonthBtn = document.getElementById('prevMonthBtn');
  const nextMonthBtn = document.getElementById('nextMonthBtn');
  const currentMonthYear = document.getElementById('currentMonthYear');
  
  if (prevMonthBtn && monthCalendar) {
    prevMonthBtn.addEventListener('click', function() {
      monthCalendar.prev();
      updateMonthYearDisplay();
    });
  }
  
  if (nextMonthBtn && monthCalendar) {
    nextMonthBtn.addEventListener('click', function() {
      monthCalendar.next();
      updateMonthYearDisplay();
    });
  }
  
  if (currentMonthYear) {
    currentMonthYear.addEventListener('click', function() {
      openMonthYearModal();
    });
  }

  // 適用ボタンのイベントリスナー
  const applyMonthYearBtn = document.getElementById('applyMonthYear');
  if (applyMonthYearBtn && monthCalendar) {
    applyMonthYearBtn.addEventListener('click', function() {
      const yearSelect = document.getElementById('yearSelect');
      const monthSelect = document.getElementById('monthSelect');
      
      if (yearSelect && monthSelect) {
        const selectedYear = parseInt(yearSelect.value);
        const selectedMonth = parseInt(monthSelect.value);
        
        // カレンダーを指定した年と月に移動
        monthCalendar.gotoDate(new Date(selectedYear, selectedMonth - 1, 1));
        updateMonthYearDisplay();
        
        // モーダルを閉じる
        const modalElement = document.getElementById('monthYearModal');
        const modal = bootstrap.Modal.getInstance(modalElement);
        if (modal) {
          modal.hide();
        }
      }
    });
  }

  // メインカレンダーの初期化
  let calendar;
  try {
    calendar = new FullCalendar.Calendar(calendarEl, {
      initialView: 'timeGridWeek',
      locale: 'ja',
      height: 'auto',
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay'
      },
      dayHeaderFormat: { weekday: 'short', day: 'numeric', month: 'short' },
      buttonText: {
        today: '今日',
        month: '月',
        week: '週',  
        day: '日'
      },
      slotMinTime: '08:00:00',
      slotMaxTime: '22:00:00',
      slotDuration: '00:10:00',
      slotLabelInterval: '00:30:00',
      snapDuration: '00:10:00',
      slotMinWidth: 60,
      allDaySlot: false,
      selectable: true,
      editable: true,
      nowIndicator: true,
      eventDisplay: 'block',
      eventMinHeight: 15,
      eventMinWidth: 0,
      slotEventOverlap: false,
      slotLabelFormat: { hour: '2-digit', minute: '2-digit', hour12: false },
      
      eventTimeFormat: {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        timeZone: 'Asia/Tokyo'
      },
      
      // イベント処理
      eventDrop: function(info) {
        console.log('🔄 Event dropped:', info.event);
        updateReservationTime(info.event);
      },
      
      eventResize: function(info) {
        console.log('📏 Event resized:', info.event);
        updateReservationTime(info.event);
      },
      
      eventClick: function(info) {
        if (typeof openReservationModal === 'function') {
          openReservationModal(info.event);
        }
      },
      
      datesSet: function(info) {
        // メインカレンダーの日付が変更されたときにミニカレンダーも同期
        if (monthCalendar) {
          const currentDate = info.start;
          monthCalendar.gotoDate(currentDate);
          updateMonthYearDisplay();
        }
      },
      
      select: function(info) {
        console.log('🔍 Calendar select:', info);
        
        const startTime = info.start;
        const endTime = info.end;
        
        const startHour = startTime.getHours();
        const endHour = endTime.getHours();
        const endMinute = endTime.getMinutes();
        
        if (startHour < 8 || startHour >= 22) {
          console.log('❌ Selected time outside available hours:', startHour);
          showMessage('カレンダー表示時間外です。8:00から21:59の間で選択してください', 'warning');
          return;
        }
        
        if (endHour > 22 || (endHour === 22 && endMinute > 0)) {
          console.log('❌ Selection extends beyond available hours');
          showMessage(`この時間帯はカレンダー表示範囲外になります。終了時刻: ${endHour.toString().padStart(2, '0')}:${endMinute.toString().padStart(2, '0')}`, 'warning');
          return;
        }
        
        if (typeof openNewReservationModal === 'function') {
          openNewReservationModal(info.start, info.end);
        }
      },
      
      // イベントコンテンツの表示
      eventContent: function(arg) {
        const event = arg.event;
        const extendedProps = event.extendedProps;
        
        const eventStart = new Date(event.start);
        const eventEnd = new Date(event.end);
        const actualDurationMinutes = Math.round((eventEnd - eventStart) / (1000 * 60));
        
        const courseDuration = extendedProps.course_duration || 60;
        const intervalDuration = extendedProps.interval_duration || 0;
        
        // インターバルがある場合はタブ形式で表示
        if (extendedProps.has_interval && intervalDuration > 0) {
          const intervalType = extendedProps.is_individual_interval ? 'individual' : 'system';
          const courseRatio = courseDuration;
          const intervalRatio = intervalDuration;
          
          return {
            html: `
              <div class="event-tab-container" style="
                height: 100%; 
                display: flex; 
                flex-direction: column;
                width: 100%;
              ">
                <div class="event-tab course" style="
                  flex: ${courseRatio}; 
                  display: flex; 
                  align-items: center; 
                  justify-content: center;
                  padding: 2px 4px;
                  font-size: 0.8rem;
                  font-weight: 600;
                  overflow: hidden;
                  text-overflow: ellipsis;
                  white-space: nowrap;
                  border-bottom: 1px solid rgba(255, 255, 255, 0.3);
                  background: inherit;
                  color: inherit;
                ">
                  ${event.title}
                </div>
                <div class="event-tab interval ${intervalType}" style="
                  flex: ${intervalRatio}; 
                  display: flex; 
                  align-items: center; 
                  justify-content: center;
                  padding: 2px 4px;
                  font-size: 0.75rem;
                  font-weight: 500;
                  overflow: hidden;
                  text-overflow: ellipsis;
                  white-space: nowrap;
                  background-color: ${intervalType === 'individual' ? '#fd7e14' : '#6c757d'};
                  color: white;
                ">
                  整理${intervalDuration}分
                </div>
              </div>
            `
          };
        } else {
          return {
            html: `
              <div style="
                height: 100%; 
                display: flex; 
                align-items: center; 
                justify-content: center;
                padding: 4px;
                font-size: 0.85rem;
                font-weight: 600;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
              ">
                ${event.title}
              </div>
            `
          };
        }
      },
      
      eventDidMount: function(info) {
        const event = info.event;
        const element = info.el;
        const extendedProps = event.extendedProps;
        
        const eventStart = new Date(event.start);
        const eventEnd = new Date(event.end);
        const actualDurationMinutes = Math.round((eventEnd - eventStart) / (1000 * 60));
        
        element.setAttribute('data-duration', actualDurationMinutes);
        
        const expectedHeight = (actualDurationMinutes / 10) * 30;
        
        element.style.setProperty('height', `${expectedHeight}px`, 'important');
        element.style.setProperty('min-height', `${expectedHeight}px`, 'important');
        element.style.setProperty('max-height', `${expectedHeight}px`, 'important');
        
        const courseDuration = extendedProps.course_duration || 60;
        const intervalDuration = extendedProps.interval_duration || 0;
        const intervalType = extendedProps.is_individual_interval ? '個別' : 'システム';
        
        if (intervalDuration > 0) {
          element.setAttribute('data-interval-info', 
            `${courseDuration}分 + ${intervalType}${intervalDuration}分 = ${actualDurationMinutes}分`);
        }
      },
      
      events: function(info, successCallback, failureCallback) {
        fetch('/admin/reservations.json', {
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          }
        })
        .then(response => {
          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }
          return response.json();
        })
        .then(events => {
          console.log('✅ Events loaded:', events.length);
          successCallback(events);
        })
        .catch(error => {
          console.error('❌ Error loading events:', error);
          failureCallback(error);
        });
      }
    });

    calendar.render();
    
    // グローバル変数として設定
    window.pageCalendar = calendar;
    console.log('✅ Main calendar initialized');
    
  } catch (error) {
    console.error('❌ Main calendar initialization failed:', error);
  }

  // 顧客検索機能
  let searchTimeout;
  const customerSearch = document.getElementById('customerSearch');
  const searchResults = document.getElementById('customerSearchResults');
  const selectedCustomerInfo = document.getElementById('selectedCustomerInfo');
  const newCustomerForm = document.getElementById('newCustomerForm');

  if (customerSearch) {
    customerSearch.addEventListener('input', function() {
      const query = this.value.trim();
      
      clearTimeout(searchTimeout);
      
      if (query.length < 2) {
        hideSearchResults();
        return;
      }
      
      searchTimeout = setTimeout(() => {
        searchCustomers(query);
      }, 300);
    });
  }

  // 検索結果以外をクリックしたら結果を隠す
  document.addEventListener('click', function(e) {
    if (!e.target.closest('#customerSearch') && !e.target.closest('#customerSearchResults')) {
      hideSearchResults();
    }
  });

  function searchCustomers(query) {
    fetch(`/admin/users/search?query=${encodeURIComponent(query)}`, {
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      displaySearchResults(data.users, query);
    })
    .catch(error => {
      console.error('顧客検索エラー:', error);
      hideSearchResults();
    });
  }

  function displaySearchResults(users, query) {
    if (!searchResults) return;
    
    if (users.length === 0) {
      searchResults.innerHTML = `
        <div class="p-3 text-center">
          <div class="text-muted mb-2">
            <i class="fas fa-search me-1"></i>
            「${query}」に該当する顧客が見つかりませんでした
          </div>
          <button type="button" class="btn btn-sm btn-primary" onclick="showNewCustomerForm('${query}')">
            <i class="fas fa-user-plus me-1"></i>新規顧客として登録
          </button>
        </div>
      `;
    } else {
      let html = '';
      users.forEach(user => {
        html += `
          <div class="search-result-item p-3 border-bottom" 
               style="cursor: pointer; transition: background-color 0.2s;"
               onmouseover="this.style.backgroundColor='#f8f9fa'"
               onmouseout="this.style.backgroundColor='white'"
               data-user-id="${user.id}"
               data-user-name="${user.name || ''}"
               data-user-phone="${user.phone_number || ''}"
               data-user-email="${user.email || ''}">
            <div class="d-flex justify-content-between align-items-start">
              <div>
                <div class="fw-bold">${user.name || '名前未設定'}</div>
                <small class="text-muted">
                  ${user.phone_number || '電話番号未登録'}
                  ${user.email ? ` | ${user.email}` : ''}
                </small>
                ${user.last_visit ? `<br><small class="text-success">最終来店: ${user.last_visit}</small>` : ''}
              </div>
              <div class="text-end">
                <small class="badge bg-info">${user.active_tickets}枚</small>
              </div>
            </div>
          </div>
        `;
      });
      searchResults.innerHTML = html;
    }
    
    searchResults.style.display = 'block';
  }

  // その他の初期化処理...
  // (残りの処理は必要に応じて追加)
  
  console.log('✅ DOM initialization completed');
  
}); // DOMContentLoaded終了

// グローバル関数の定義
function updateReservationTime(event) {
  console.log('🔄 Updating reservation time:', event.id);
  
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
  
  fetch(`/admin/reservations/${event.id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    },
    body: JSON.stringify({
      reservation: {
        start_time: event.start.toISOString(),
        end_time: event.end.toISOString()
      }
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      showMessage('予約時間を更新しました', 'success');
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
    } else {
      throw new Error(data.error || '更新に失敗しました');
    }
  })
  .catch(error => {
    console.error('❌ Update failed:', error);
    showMessage('更新エラー: ' + error.message, 'danger');
  });
}

// デバッグモード切り替え
window.toggleDebugMode = function() {
  const calendar = document.getElementById('calendar');
  if (!calendar) return;
  
  const isDebugMode = calendar.classList.contains('debug-events');
  
  if (isDebugMode) {
    calendar.classList.remove('debug-events');
    showMessage('デバッグモードを無効にしました', 'info');
  } else {
    calendar.classList.add('debug-events');
    showMessage('デバッグモードを有効にしました', 'info');
  }
};

// エラーハンドリング
window.addEventListener('error', function(e) {
  console.error('❌ JavaScript Error:', e.error);
  console.error('❌ Error at:', e.filename, ':', e.lineno, ':', e.colno);
});

window.addEventListener('unhandledrejection', function(e) {
  console.error('❌ Unhandled Promise Rejection:', e.reason);
});

console.log('✅ All JavaScript loaded successfully');
</script>
