// app/javascript/calendar/reservation_form.js
import { showMessage } from './utils.js';

// フォームバリデーション
function validateReservationForm() {
  const userId = document.getElementById('reservationUserId').value;
  const date = document.getElementById('reservationDate').value;
  const time = document.getElementById('reservationTime').value;
  const status = document.getElementById('reservationStatus').value;
  const cancellationReason = document.getElementById('cancellationReason').value;
  
  const errors = [];
  
  if (!userId) {
    errors.push('ユーザーを選択してください');
  }
  
  if (!date) {
    errors.push('予約日を入力してください');
  }
  
  if (!time) {
    errors.push('開始時間を選択してください');
  }
  
  // 過去の日付チェック
  if (date) {
    const selectedDate = new Date(date);
    const currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0);
    
    if (selectedDate < currentDate) {
      errors.push('過去の日付は選択できません');
    }
  }
  
  // キャンセル理由チェック
  if (status === 'cancelled' && !cancellationReason.trim()) {
    errors.push('キャンセル理由を入力してください');
  }
  
  return errors;
}

// 予約時間の重複チェック
function checkTimeConflict(date, time, course, excludeId = null) {
  return new Promise((resolve, reject) => {
    const params = new URLSearchParams({
      date: date,
      time: time,
      course: course
    });
    
    if (excludeId) {
      params.append('exclude_id', excludeId);
    }
    
    fetch(`/admin/reservations/check_conflict?${params}`)
      .then(response => response.json())
      .then(data => {
        resolve(data.conflict);
      })
      .catch(error => {
        console.error('❌ Time conflict check failed:', error);
        reject(error);
      });
  });
}

// コース時間の計算
function calculateEndTime(startTime, course) {
  const [hours, minutes] = startTime.split(':').map(Number);
  const courseDuration = parseInt(course.replace('分', ''));
  
  const startDate = new Date();
  startDate.setHours(hours, minutes, 0, 0);
  
  const endDate = new Date(startDate.getTime() + courseDuration * 60000);
  
  return `${endDate.getHours().toString().padStart(2, '0')}:${endDate.getMinutes().toString().padStart(2, '0')}`;
}

// 営業時間内チェック
function checkBusinessHours(date, startTime, endTime) {
  const businessStart = parseInt(document.querySelector('meta[name="business-hours-start"]')?.content || '10');
  const businessEnd = parseInt(document.querySelector('meta[name="business-hours-end"]')?.content || '20');
  const sundayClosed = document.querySelector('meta[name="sunday-closed"]')?.content === 'true';
  
  const selectedDate = new Date(date);
  const dayOfWeek = selectedDate.getDay(); // 0 = 日曜日
  
  // 日曜日休業チェック
  if (sundayClosed && dayOfWeek === 0) {
    return { valid: false, message: '日曜日は休業日です' };
  }
  
  // 営業時間チェック
  const [startHour] = startTime.split(':').map(Number);
  const [endHour, endMinute] = endTime.split(':').map(Number);
  
  if (startHour < businessStart) {
    return { valid: false, message: `営業開始時間は${businessStart}:00です` };
  }
  
  if (endHour > businessEnd || (endHour === businessEnd && endMinute > 0)) {
    return { valid: false, message: `営業終了時間は${businessEnd}:00です` };
  }
  
  return { valid: true };
}

// フォーム送信前の最終チェック
async function performFinalValidation() {
  const date = document.getElementById('reservationDate').value;
  const time = document.getElementById('reservationTime').value;
  const course = document.getElementById('reservationCourse').value;
  const reservationId = document.getElementById('reservationId').value;
  
  // 基本バリデーション
  const basicErrors = validateReservationForm();
  if (basicErrors.length > 0) {
    showMessage(basicErrors.join('<br>'), 'warning');
    return false;
  }
  
  // 終了時間計算
  const endTime = calculateEndTime(time, course);
  
  // 営業時間チェック
  const businessHoursCheck = checkBusinessHours(date, time, endTime);
  if (!businessHoursCheck.valid) {
    showMessage(businessHoursCheck.message, 'warning');
    return false;
  }
  
  // 重複チェック
  try {
    const hasConflict = await checkTimeConflict(date, time, course, reservationId);
    if (hasConflict) {
      showMessage('選択した時間に他の予約が入っています', 'warning');
      return false;
    }
  } catch (error) {
    console.error('❌ Conflict check failed:', error);
    showMessage('予約時間の確認中にエラーが発生しました', 'danger');
    return false;
  }
  
  return true;
}

// リアルタイムバリデーション設定
function setupRealtimeValidation() {
  const dateField = document.getElementById('reservationDate');
  const timeField = document.getElementById('reservationTime');
  const courseField = document.getElementById('reservationCourse');
  
  // 日付変更時
  dateField?.addEventListener('change', function() {
    if (this.value) {
      const selectedDate = new Date(this.value);
      const currentDate = new Date();
      currentDate.setHours(0, 0, 0, 0);
      
      if (selectedDate < currentDate) {
        showMessage('過去の日付は選択できません', 'warning');
        this.value = '';
      }
    }
  });
  
  // 時間/コース変更時の終了時間表示
  function updateEndTimeDisplay() {
    const time = timeField?.value;
    const course = courseField?.value;
    
    if (time && course) {
      const endTime = calculateEndTime(time, course);
      
      // 終了時間を表示（UIに要素があれば）
      const endTimeDisplay = document.getElementById('endTimeDisplay');
      if (endTimeDisplay) {
        endTimeDisplay.textContent = `終了予定: ${endTime}`;
      }
      
      // 営業時間チェック
      const date = dateField?.value;
      if (date) {
        const businessHoursCheck = checkBusinessHours(date, time, endTime);
        if (!businessHoursCheck.valid) {
          showMessage(businessHoursCheck.message, 'warning');
        }
      }
    }
  }
  
  timeField?.addEventListener('change', updateEndTimeDisplay);
  courseField?.addEventListener('change', updateEndTimeDisplay);
}

// ユーザー選択時の情報表示
function setupUserSelection() {
  const userSelect = document.getElementById('reservationUserId');
  
  userSelect?.addEventListener('change', function() {
    const userId = this.value;
    if (!userId) return;
    
    // ユーザー情報を表示
    const selectedUser = window.currentUsers?.find(user => user.id == userId);
    if (selectedUser) {
      const userInfo = document.getElementById('selectedUserInfo');
      if (userInfo) {
        userInfo.innerHTML = `
          <div class="alert alert-info">
            <strong>${selectedUser.name}</strong><br>
            電話: ${selectedUser.phone_number || '未登録'}<br>
            メール: ${selectedUser.email || '未登録'}
          </div>
        `;
      }
      
      // 過去の予約履歴を取得（オプション）
      loadUserReservationHistory(userId);
    }
  });
}

// ユーザーの予約履歴読み込み
function loadUserReservationHistory(userId) {
  fetch(`/admin/users/${userId}/reservations.json`)
    .then(response => response.json())
    .then(data => {
      if (data.success && data.reservations.length > 0) {
        const historyContainer = document.getElementById('userReservationHistory');
        if (historyContainer) {
          const recentReservations = data.reservations.slice(0, 3);
          historyContainer.innerHTML = `
            <div class="mt-2">
              <small class="text-muted">最近の予約履歴:</small>
              ${recentReservations.map(res => `
                <div class="small text-muted">
                  ${res.date} ${res.time} - ${res.course} (${res.status})
                </div>
              `).join('')}
            </div>
          `;
        }
      }
    })
    .catch(error => {
      console.error('❌ Failed to load user history:', error);
    });
}

// ステータス変更時の処理
function setupStatusHandling() {
  const statusSelect = document.getElementById('reservationStatus');
  const cancellationArea = document.getElementById('cancellationReasonArea');
  
  statusSelect?.addEventListener('change', function() {
    if (this.value === 'cancelled') {
      cancellationArea.style.display = 'block';
      document.getElementById('cancellationReason').required = true;
    } else {
      cancellationArea.style.display = 'none';
      document.getElementById('cancellationReason').required = false;
    }
    
    // ステータスに応じたメッセージ
    switch (this.value) {
      case 'cancelled':
        showMessage('キャンセル理由を入力してください', 'info');
        break;
      case 'no_show':
        showMessage('無断キャンセルとして記録されます', 'warning');
        break;
      case 'completed':
        showMessage('予約完了として記録されます', 'success');
        break;
    }
  });
}

// フォームリセット
function resetReservationForm() {
  const form = document.getElementById('reservationForm');
  if (form) {
    form.reset();
  }
  
  // 追加の初期化
  const cancellationArea = document.getElementById('cancellationReasonArea');
  if (cancellationArea) {
    cancellationArea.style.display = 'none';
  }
  
  const userInfo = document.getElementById('selectedUserInfo');
  if (userInfo) {
    userInfo.innerHTML = '';
  }
  
  const userHistory = document.getElementById('userReservationHistory');
  if (userHistory) {
    userHistory.innerHTML = '';
  }
}

// 自動入力補完
function setupAutoComplete() {
  const userSelect = document.getElementById('reservationUserId');
  
  // ユーザー検索機能（オプション）
  if (userSelect) {
    // Select2やChoices.jsなどのライブラリを使用する場合はここで初期化
    console.log('User select initialized for auto-complete');
  }
}

// フォームの保存状態管理
function setupFormStateManagement() {
  const form = document.getElementById('reservationForm');
  if (!form) return;
  
  let originalFormData = new FormData(form);
  
  // フォーム変更検知
  form.addEventListener('input', function() {
    const currentFormData = new FormData(form);
    let hasChanges = false;
    
    for (let [key, value] of currentFormData) {
      if (originalFormData.get(key) !== value) {
        hasChanges = true;
        break;
      }
    }
    
    // 変更があった場合の処理
    if (hasChanges) {
      const saveBtn = document.getElementById('saveReservationBtn');
      if (saveBtn && !saveBtn.classList.contains('btn-warning')) {
        saveBtn.classList.remove('btn-primary');
        saveBtn.classList.add('btn-warning');
        saveBtn.innerHTML = '<i class="fas fa-exclamation-triangle me-1"></i>変更を保存';
      }
    }
  });
  
  // フォーム保存後の状態リセット
  window.addEventListener('reservationSaved', function() {
    originalFormData = new FormData(form);
    const saveBtn = document.getElementById('saveReservationBtn');
    if (saveBtn) {
      saveBtn.classList.remove('btn-warning');
      saveBtn.classList.add('btn-primary');
      saveBtn.innerHTML = '<i class="fas fa-save me-1"></i>保存';
    }
  });
}

// キーボードショートカット
function setupKeyboardShortcuts() {
  document.addEventListener('keydown', function(e) {
    // モーダルが開いている時のみ
    const modal = document.getElementById('reservationModal');
    if (!modal || !modal.classList.contains('show')) return;
    
    // Ctrl + S で保存
    if (e.ctrlKey && e.key === 's') {
      e.preventDefault();
      const saveBtn = document.getElementById('saveReservationBtn');
      if (saveBtn && !saveBtn.disabled) {
        saveBtn.click();
      }
    }
    
    // Escキーでモーダルを閉じる
    if (e.key === 'Escape') {
      const closeBtn = modal.querySelector('[data-bs-dismiss="modal"]');
      if (closeBtn) {
        closeBtn.click();
      }
    }
  });
}

// 予約フォーム初期化
export function setupReservationForm() {
  // バリデーション設定
  setupRealtimeValidation();
  
  // ユーザー選択処理
  setupUserSelection();
  
  // ステータス処理
  setupStatusHandling();
  
  // 自動補完
  setupAutoComplete();
  
  // フォーム状態管理
  setupFormStateManagement();
  
  // キーボードショートカット
  setupKeyboardShortcuts();
  
  // グローバル関数として公開
  window.validateReservationForm = validateReservationForm;
  window.performFinalValidation = performFinalValidation;
  window.resetReservationForm = resetReservationForm;
  window.checkTimeConflict = checkTimeConflict;
  
  console.log('✅ Reservation form initialized');
}

// 公開関数
export { 
  validateReservationForm, 
  performFinalValidation, 
  resetReservationForm,
  checkTimeConflict 
};