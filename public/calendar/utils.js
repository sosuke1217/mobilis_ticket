// app/javascript/calendar/utils.js

// メッセージ表示
export function showMessage(message, type = 'info', duration = 3000) {
  const messageContainer = document.getElementById('message-container') || createMessageContainer();
  
  const alertDiv = document.createElement('div');
  alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
  alertDiv.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
  `;
  
  messageContainer.appendChild(alertDiv);
  
  setTimeout(() => {
    if (alertDiv.parentNode) {
      alertDiv.parentNode.removeChild(alertDiv);
    }
  }, duration);
}

// メッセージコンテナ作成
function createMessageContainer() {
  const container = document.createElement('div');
  container.id = 'message-container';
  container.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 9999; max-width: 400px;';
  document.body.appendChild(container);
  return container;
}

// 時間オプション生成
export function generateTimeOptions() {
  const timeSelect = document.getElementById('reservationTime');
  if (!timeSelect) return;
  
  timeSelect.innerHTML = '';
  
  // 営業時間内の時間オプションを生成（10分間隔）
  for (let hour = 10; hour <= 20; hour++) {
    for (let minute = 0; minute < 60; minute += 10) {
      if (hour === 20 && minute > 0) break; // 20:00まで
      
      const timeStr = `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
      const option = document.createElement('option');
      option.value = timeStr;
      option.textContent = timeStr;
      timeSelect.appendChild(option);
    }
  }
}

// ユーザー一覧読み込み
export function loadUsers() {
  fetch('/admin/users.json')
    .then(response => response.json())
    .then(users => {
      window.currentUsers = users;
      updateUserSelect(users);
      console.log('✅ Users loaded:', users.length);
    })
    .catch(error => {
      console.error('❌ Failed to load users:', error);
      showMessage('ユーザー一覧の読み込みに失敗しました', 'danger');
    });
}

// ユーザーセレクト更新
function updateUserSelect(users) {
  const userSelect = document.getElementById('reservationUserId');
  if (!userSelect) return;
  
  userSelect.innerHTML = '<option value="">ユーザーを選択してください</option>';
  
  users.forEach(user => {
    const option = document.createElement('option');
    option.value = user.id;
    option.textContent = `${user.name} (${user.phone_number || 'Tel未登録'})`;
    userSelect.appendChild(option);
  });
}

// カレンダー更新
export function refreshCalendar() {
  if (window.pageCalendar) {
    console.log('🔄 Refreshing calendar...');
    window.pageCalendar.refetchEvents();
    showMessage('カレンダーを更新しました', 'success');
  }
}

// グローバル関数として公開
export function setupGlobalUtils() {
  window.showMessage = showMessage;
  window.refreshCalendar = refreshCalendar;
  window.generateTimeOptions = generateTimeOptions;
  window.loadUsers = loadUsers;
  
  // 初期化
  generateTimeOptions();
  loadUsers();
  
  console.log('✅ Utils module initialized');
}