// app/javascript/calendar/modal_controller.js
import { showMessage } from './utils.js';

let currentReservationId = null;

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
  const bootstrapModal = new bootstrap.Modal(modal);
  bootstrapModal.show();
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
  
  // バリデーション
  if (!formData.user_id) {
    showMessage('ユーザーを選択してください', 'warning');
    return;
  }
  
  if (!formData.date || !formData.time) {
    showMessage('日付と時間を入力してください', 'warning');
    return;
  }
  
  const saveBtn = document.getElementById('saveReservationBtn');
  const originalText = saveBtn.innerHTML;
  saveBtn.disabled = true;
  saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>保存中...';
  
  const url = currentReservationId 
    ? `/admin/reservations/${currentReservationId}`
    : '/admin/reservations';
  
  const method = currentReservationId ? 'PATCH' : 'POST';
  
  fetch(url, {
    method: method,
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({ reservation: formData })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      showMessage(
        currentReservationId ? '予約を更新しました' : '予約を作成しました',
        'success'
      );
      
      // モーダルを閉じる
      const modal = bootstrap.Modal.getInstance(document.getElementById('reservationModal'));
      modal.hide();
      
      // カレンダーを更新
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
    } else {
      showMessage(data.error || '予約の保存に失敗しました', 'danger');
    }
  })
  .catch(error => {
    console.error('❌ Save failed:', error);
    showMessage('保存中にエラーが発生しました', 'danger');
  })
  .finally(() => {
    saveBtn.disabled = false;
    saveBtn.innerHTML = originalText;
  });
}

// 予約削除
function deleteReservation() {
  if (!currentReservationId) return;
  
  if (!confirm('この予約を削除しますか？')) return;
  
  fetch(`/admin/reservations/${currentReservationId}`, {
    method: 'DELETE',
    headers: {
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      showMessage('予約を削除しました', 'success');
      
      // モーダルを閉じる
      const modal = bootstrap.Modal.getInstance(document.getElementById('reservationModal'));
      modal.hide();
      
      // カレンダーを更新
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
    } else {
      showMessage(data.error || '予約の削除に失敗しました', 'danger');
    }
  })
  .catch(error => {
    console.error('❌ Delete failed:', error);
    showMessage('削除中にエラーが発生しました', 'danger');
  });
}

// イベントリスナー設定
function setupEventListeners() {
  // 保存ボタン
  const saveBtn = document.getElementById('saveReservationBtn');
  if (saveBtn) {
    saveBtn.addEventListener('click', saveReservation);
  }
  
  // 削除ボタン
  const deleteBtn = document.getElementById('deleteReservationBtn');
  if (deleteBtn) {
    deleteBtn.addEventListener('click', deleteReservation);
  }
  
  // ステータス変更時の処理
  const statusSelect = document.getElementById('reservationStatus');
  const cancellationArea = document.getElementById('cancellationReasonArea');
  
  if (statusSelect && cancellationArea) {
    statusSelect.addEventListener('change', function() {
      if (this.value === 'cancelled') {
        cancellationArea.style.display = 'block';
      } else {
        cancellationArea.style.display = 'none';
      }
    });
  }
}

// モーダルコントローラー初期化
export function setupReservationModal() {
  // グローバル関数として公開
  window.openReservationModal = openReservationModal;
  
  // イベントリスナー設定
  setupEventListeners();
  
  console.log('✅ Modal controller initialized');
}