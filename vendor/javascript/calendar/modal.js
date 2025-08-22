// app/javascript/calendar/modal_controller.js
import { showMessage } from './utils.js';

let currentReservationId = null;
let currentModal = null;

// 予約モーダルを開く
export function openReservationModal(reservationId, dateStr) {
  console.log('📝 Opening reservation modal:', { reservationId, dateStr });
  
  const modal = document.getElementById('reservationModal');
  if (!modal) {
    console.error('❌ Reservation modal not found');
    return;
  }
  
  currentReservationId = reservationId;
  
  // モーダルの内容をリセット/設定
  resetModalFields(reservationId, dateStr);
  
  // 既存予約の場合はデータを読み込み
  if (reservationId) {
    loadReservationData(reservationId);
  }
  
  // モーダル表示
  currentModal = new bootstrap.Modal(modal);
  
  // モーダルが閉じられた時の処理を追加
  modal.addEventListener('hidden.bs.modal', function() {
    console.log('🔒 Modal hidden, cleaning up...');
    cleanupModal();
  });
  
  currentModal.show();
}

// モーダルのクリーンアップ
function cleanupModal() {
  console.log('🧹 Cleaning up modal...');
  
  // backdropを手動で削除
  const backdrops = document.querySelectorAll('.modal-backdrop');
  backdrops.forEach(backdrop => {
    backdrop.remove();
  });
  
  // bodyのmodal-openクラスを削除
  document.body.classList.remove('modal-open');
  document.body.style.overflow = '';
  document.body.style.paddingRight = '';
  
  // 現在のモーダルインスタンスをクリア
  currentModal = null;
  
  console.log('✅ Modal cleanup completed');
}

// モーダルフィールドのリセット
function resetModalFields(reservationId, dateStr) {
  const fields = {
    reservationId: reservationId || '',
    reservationUserId: '',
    reservationCourse: '60分',
    reservationDate: dateStr ? dateStr.split('T')[0] : '',
    reservationTime: dateStr ? dateStr.split('T')[1]?.substring(0, 5) || '10:00' : '10:00',
    reservationStatus: 'confirmed',
    reservationNote: '',
    cancellationReason: ''
  };
  
  Object.entries(fields).forEach(([fieldId, value]) => {
    const element = document.getElementById(fieldId);
    if (element) {
      element.value = value;
    }
  });
  
  // ボタンの表示/非表示
  const deleteBtn = document.getElementById('deleteReservationBtn');
  const cancelBtn = document.getElementById('cancelReservationBtn');
  const cancellationArea = document.getElementById('cancellationReasonArea');
  
  if (reservationId) {
    deleteBtn?.classList.remove('d-none');
    cancelBtn?.classList.remove('d-none');
  } else {
    deleteBtn?.classList.add('d-none');
    cancelBtn?.classList.add('d-none');
  }
  
  cancellationArea?.style && (cancellationArea.style.display = 'none');
}

// 予約データ読み込み
function loadReservationData(reservationId) {
  fetch(`/admin/reservations/${reservationId}.json`)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        const reservation = data.reservation;
        
        // フィールドに値を設定
        document.getElementById('reservationUserId').value = reservation.user_id || '';
        document.getElementById('reservationCourse').value = reservation.course || '60分';
        document.getElementById('reservationDate').value = reservation.date || '';
        document.getElementById('reservationTime').value = reservation.time || '10:00';
        document.getElementById('reservationStatus').value = reservation.status || 'confirmed';
        document.getElementById('reservationNote').value = reservation.note || '';
        
        // 個別インターバル設定があれば読み込み
        if (window.loadIndividualIntervalData) {
          window.loadIndividualIntervalData(reservationId);
        }
        
        console.log('✅ Reservation data loaded');
      } else {
        console.error('❌ Failed to load reservation data:', data.error);
        showMessage('予約データの読み込みに失敗しました', 'danger');
      }
    })
    .catch(error => {
      console.error('❌ Error loading reservation data:', error);
      showMessage('予約データの読み込み中にエラーが発生しました', 'danger');
    });
}

// 予約保存
function saveReservation() {
  const formData = {
    user_id: document.getElementById('reservationUserId').value,
    course: document.getElementById('reservationCourse').value,
    date: document.getElementById('reservationDate').value,
    time: document.getElementById('reservationTime').value,
    status: document.getElementById('reservationStatus').value,
    note: document.getElementById('reservationNote').value
  };
  
  console.log('💾 Saving reservation:', formData);
  
  if (!formData.user_id || !formData.date || !formData.time) {
    showMessage('必須項目を入力してください', 'warning');
    return;
  }
  
  const startDateTime = new Date(`${formData.date}T${formData.time}:00`);
  const courseDuration = parseInt(formData.course.replace('分', ''));
  const endDateTime = new Date(startDateTime.getTime() + courseDuration * 60000);
  
  const apiData = {
    user_id: parseInt(formData.user_id),
    course: formData.course,
    start_time: startDateTime.toISOString(),
    end_time: endDateTime.toISOString(),
    status: formData.status,
    note: formData.note
  };
  
  console.log('💾 API data:', apiData);
  
  const saveBtn = document.querySelector('#reservationModal .btn-primary');
  const originalText = saveBtn.innerHTML;
  saveBtn.disabled = true;
  saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>保存中...';
  
  const isEdit = currentReservationId !== null;
  const url = isEdit 
    ? `${window.location.protocol}//${window.location.host}/admin/reservations/${currentReservationId}`
    : `${window.location.protocol}//${window.location.host}/admin/reservations`;
  const method = isEdit ? 'PATCH' : 'POST';
  
  console.log(`📡 ${method} request to:`, url);
  
  fetch(url, {
    method: method,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
      'X-Requested-With': 'XMLHttpRequest'
    },
    body: JSON.stringify({ reservation: apiData }),
    credentials: 'same-origin'
  })
  .then(response => {
    console.log('📡 Response status:', response.status);
    return response.json();
  })
  .then(data => {
    console.log('💾 Save response:', data);
    
    if (data.success) {
      const message = isEdit ? '予約を更新しました' : '予約を作成しました';
      showMessage(message, 'success');
      
      // モーダルを閉じる
      if (currentModal) {
        currentModal.hide();
      }
      
      // カレンダーを更新
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
      
    } else {
      console.error('❌ Save failed:', data.error || data.errors);
      const errorMsg = data.error || (data.errors ? data.errors.join(', ') : '保存に失敗しました');
      showMessage(errorMsg, 'danger');
    }
  })
  .catch(error => {
    console.error('❌ Save request failed:', error);
    showMessage('保存中にエラーが発生しました: ' + error.message, 'danger');
  })
  .finally(() => {
    saveBtn.disabled = false;
    saveBtn.innerHTML = originalText;
  });
}

// 予約削除
function deleteReservation() {
  if (!currentReservationId) {
    console.warn('⚠️ No reservation ID for deletion');
    showMessage('削除する予約が選択されていません', 'warning');
    return;
  }
  
  console.log('🔍 Current reservation ID:', currentReservationId);
  
  const confirmMessage = '本当にこの予約を削除しますか？\n削除した予約は復元できません。';
  if (!confirm(confirmMessage)) {
    console.log('🚫 Deletion cancelled by user');
    return;
  }
  
  console.log('🗑️ Deleting reservation:', currentReservationId);
  
  const deleteBtn = document.getElementById('deleteReservationBtn');
  const originalText = deleteBtn.innerHTML;
  deleteBtn.disabled = true;
  deleteBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>削除中...';
  
  const saveBtn = document.querySelector('#reservationModal .btn-primary');
  saveBtn.disabled = true;
  
  fetch(`/admin/reservations/${currentReservationId}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
      'X-Requested-With': 'XMLHttpRequest'
    },
    credentials: 'same-origin'
  })
  .then(response => {
    console.log('📡 Delete response status:', response.status);
    return response.json();
  })
  .then(data => {
    console.log('🗑️ Delete response:', data);
    
    if (data.success) {
      showMessage('予約を削除しました', 'success');
      
      // モーダルを閉じる
      if (currentModal) {
        currentModal.hide();
      }
      
      // カレンダーを更新
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
      
      currentReservationId = null;
    } else {
      console.error('❌ Delete failed:', data.error);
      showMessage(data.error || '削除に失敗しました', 'danger');
    }
  })
  .catch(error => {
    console.error('❌ Delete request failed:', error);
    showMessage('削除中にエラーが発生しました: ' + error.message, 'danger');
  })
  .finally(() => {
    deleteBtn.disabled = false;
    deleteBtn.innerHTML = originalText;
    saveBtn.disabled = false;
  });
}

// イベントリスナー設定
function setupEventListeners() {
  const timeSelect = document.getElementById('reservationTime');
  const courseSelect = document.getElementById('reservationCourse');
  
  timeSelect?.addEventListener('change', updateEndTime);
  courseSelect?.addEventListener('change', updateEndTime);
  
  const deleteBtn = document.getElementById('deleteReservationBtn');
  deleteBtn?.addEventListener('click', deleteReservation);
  
  // 保存ボタンのイベントリスナー
  const saveBtn = document.querySelector('#reservationModal .btn-primary');
  saveBtn?.addEventListener('click', saveReservation);
  
  console.log('✅ Event listeners setup');
}

// 終了時間の更新
function updateEndTime() {
  const time = document.getElementById('reservationTime').value;
  const course = document.getElementById('reservationCourse').value;
  const endTimeDisplay = document.getElementById('endTimeDisplay');
  
  if (time && course) {
    const [hours, minutes] = time.split(':').map(Number);
    const courseDuration = parseInt(course.replace('分', ''));
    
    const startDate = new Date();
    startDate.setHours(hours, minutes, 0, 0);
    
    const endDate = new Date(startDate.getTime() + courseDuration * 60000);
    const endTimeStr = `${endDate.getHours().toString().padStart(2, '0')}:${endDate.getMinutes().toString().padStart(2, '0')}`;
    
    endTimeDisplay.value = endTimeStr;
  }
}

// モーダル初期化
export function setupReservationModal() {
  console.log('🔧 Setting up reservation modal...');
  setupEventListeners();
  
  // グローバル関数として公開
  window.saveReservation = saveReservation;
  window.deleteReservation = deleteReservation;
  
  console.log('✅ Reservation modal setup completed');
}