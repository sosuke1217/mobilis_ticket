// app/javascript/calendar/interval_settings.js
import { showMessage } from './utils.js';

let currentIndividualInterval = null;
const systemDefaultInterval = parseInt(document.querySelector('meta[name="reservation-interval"]')?.content || '15');

// 個別インターバル設定UI作成
function createIntervalSettingsUI() {
  const section = document.getElementById('individualIntervalSection');
  if (!section) return;
  
  section.innerHTML = `
    <div class="card">
      <div class="card-header">
        <h6 class="mb-0">
          <i class="fas fa-clock me-2"></i>インターバル設定
          <span id="interval-status-badge" class="badge bg-secondary ms-2">システム設定 (${systemDefaultInterval}分)</span>
        </h6>
      </div>
      <div class="card-body">
        <!-- システム設定表示 -->
        <div id="systemIntervalArea">
          <div class="alert alert-info mb-3">
            <i class="fas fa-info-circle me-2"></i>
            現在はシステム設定（${systemDefaultInterval}分）が適用されています
          </div>
        </div>
        
        <!-- 個別設定切り替え -->
        <div class="form-check form-switch mb-3">
          <input class="form-check-input" type="checkbox" id="individualIntervalToggle">
          <label class="form-check-label" for="individualIntervalToggle">
            この予約のみ個別のインターバル時間を設定
          </label>
        </div>
        
        <!-- 個別設定エリア -->
        <div id="individualIntervalArea" style="display: none;">
          <div class="row">
            <div class="col-md-8">
              <label for="individual-interval-slider" class="form-label">
                インターバル時間: <span id="interval-display">${systemDefaultInterval}</span>分
              </label>
              <input type="range" class="form-range" id="individual-interval-slider" 
                     min="0" max="60" step="5" value="${systemDefaultInterval}">
              <div class="d-flex justify-content-between text-muted small">
                <span>0分</span>
                <span>30分</span>
                <span>60分</span>
              </div>
            </div>
            <div class="col-md-4">
              <label for="individual-interval-input" class="form-label">直接入力</label>
              <input type="number" class="form-control" id="individual-interval-input" 
                     min="0" max="120" step="5" value="${systemDefaultInterval}">
            </div>
          </div>
          
          <!-- プリセットボタン -->
          <div class="mt-3">
            <label class="form-label">プリセット:</label>
            <div class="btn-group" role="group">
              <button type="button" class="btn btn-outline-secondary individual-preset-btn" data-value="0">0分</button>
              <button type="button" class="btn btn-outline-secondary individual-preset-btn" data-value="5">5分</button>
              <button type="button" class="btn btn-outline-secondary individual-preset-btn" data-value="10">10分</button>
              <button type="button" class="btn btn-outline-secondary individual-preset-btn" data-value="15">15分</button>
              <button type="button" class="btn btn-outline-secondary individual-preset-btn" data-value="20">20分</button>
              <button type="button" class="btn btn-outline-secondary individual-preset-btn" data-value="30">30分</button>
            </div>
          </div>
          
          <!-- プレビュー -->
          <div id="individual-interval-preview" class="mt-3">
            <div class="alert alert-warning">
              <i class="fas fa-eye me-2"></i>
              個別設定: <strong id="preview-minutes">${systemDefaultInterval}</strong>分のインターバルが予約終了後に追加されます
            </div>
          </div>
          
          <!-- アクションボタン -->
          <div class="mt-3">
            <button type="button" id="applyIntervalBtn" class="btn btn-success btn-sm">
              <i class="fas fa-check me-1"></i>適用
            </button>
            <button type="button" id="resetIntervalBtn" class="btn btn-outline-secondary btn-sm">
              <i class="fas fa-undo me-1"></i>リセット
            </button>
          </div>
        </div>
      </div>
    </div>
  `;
}

// イベントリスナー設定
function setupIntervalEventListeners() {
  const toggle = document.getElementById('individualIntervalToggle');
  const individualArea = document.getElementById('individualIntervalArea');
  const systemArea = document.getElementById('systemIntervalArea');
  const slider = document.getElementById('individual-interval-slider');
  const input = document.getElementById('individual-interval-input');
  const display = document.getElementById('interval-display');
  const previewMinutes = document.getElementById('preview-minutes');
  const statusBadge = document.getElementById('interval-status-badge');
  const applyBtn = document.getElementById('applyIntervalBtn');
  const resetBtn = document.getElementById('resetIntervalBtn');
  
  if (!toggle || !individualArea || !systemArea) return;
  
  // トグル切り替え
  toggle.addEventListener('change', function() {
    if (this.checked) {
      individualArea.style.display = 'block';
      systemArea.style.display = 'none';
      statusBadge.textContent = `個別設定 (${slider.value}分)`;
      statusBadge.className = 'badge bg-warning ms-2';
    } else {
      individualArea.style.display = 'none';
      systemArea.style.display = 'block';
      statusBadge.textContent = `システム設定 (${systemDefaultInterval}分)`;
      statusBadge.className = 'badge bg-secondary ms-2';
    }
  });
  
  // スライダー変更
  slider?.addEventListener('input', function() {
    const value = this.value;
    input.value = value;
    display.textContent = value;
    previewMinutes.textContent = value;
    updateStatusBadge(value);
  });
  
  // 入力フィールド変更
  input?.addEventListener('input', function() {
    let value = Math.max(0, Math.min(120, parseInt(this.value) || 0));
    value = Math.round(value / 5) * 5; // 5分単位に丸める
    
    this.value = value;
    slider.value = Math.min(60, value);
    display.textContent = value;
    previewMinutes.textContent = value;
    updateStatusBadge(value);
  });
  
  // プリセットボタン
  document.querySelectorAll('.individual-preset-btn').forEach(btn => {
    btn.addEventListener('click', function() {
      const value = parseInt(this.dataset.value);
      slider.value = value;
      input.value = value;
      display.textContent = value;
      previewMinutes.textContent = value;
      updateStatusBadge(value);
      
      // アクティブ状態の切り替え
      document.querySelectorAll('.individual-preset-btn').forEach(b => b.classList.remove('active'));
      this.classList.add('active');
    });
  });
  
  // 適用ボタン
  applyBtn?.addEventListener('click', applyIndividualInterval);
  
  // リセットボタン
  resetBtn?.addEventListener('click', resetIndividualInterval);
}

// ステータスバッジ更新
function updateStatusBadge(minutes) {
  const statusBadge = document.getElementById('interval-status-badge');
  if (!statusBadge) return;
  
  statusBadge.textContent = `個別設定 (${minutes}分)`;
  statusBadge.className = `badge ms-2 ${getIntervalBadgeClass(minutes)}`;
}

// インターバル値に応じたバッジクラス
function getIntervalBadgeClass(interval) {
  if (interval === 0) return 'bg-secondary';
  if (interval <= 10) return 'bg-info';
  if (interval <= 20) return 'bg-success';
  if (interval <= 30) return 'bg-warning';
  return 'bg-danger';
}

// 個別インターバル適用
function applyIndividualInterval() {
  const reservationId = document.getElementById('reservationId').value;
  if (!reservationId) {
    showMessage('予約を保存してから個別インターバルを設定してください', 'warning');
    return;
  }
  
  const intervalMinutes = parseInt(document.getElementById('individual-interval-input').value);
  const isEnabled = document.getElementById('individualIntervalToggle').checked;
  
  if (!isEnabled) {
    showMessage('個別設定を有効にしてください', 'warning');
    return;
  }
  
  const applyBtn = document.getElementById('applyIntervalBtn');
  applyBtn.disabled = true;
  applyBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>適用中...';
  
  fetch(`/admin/reservations/${reservationId}/individual_interval`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({
      individual_interval_minutes: intervalMinutes,
      interval_description: `個別設定: ${intervalMinutes}分`
    })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      currentIndividualInterval = intervalMinutes;
      showMessage(`個別インターバル (${intervalMinutes}分) を適用しました`, 'success');
      
      // カレンダーを更新
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
    } else {
      showMessage(data.error || '個別インターバルの適用に失敗しました', 'danger');
    }
  })
  .catch(error => {
    console.error('❌ Individual interval application failed:', error);
    showMessage('適用中にエラーが発生しました', 'danger');
  })
  .finally(() => {
    applyBtn.disabled = false;
    applyBtn.innerHTML = '<i class="fas fa-check me-1"></i>適用';
  });
}

// 個別インターバル リセット
function resetIndividualInterval() {
  const reservationId = document.getElementById('reservationId').value;
  if (!reservationId) {
    showMessage('予約を保存してからリセットしてください', 'warning');
    return;
  }
  
  if (!confirm('個別インターバル設定をリセットしてシステム設定に戻しますか？')) {
    return;
  }
  
  const resetBtn = document.getElementById('resetIntervalBtn');
  resetBtn.disabled = true;
  resetBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>リセット中...';
  
  fetch(`/admin/reservations/${reservationId}/individual_interval`, {
    method: 'DELETE',
    headers: {
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    }
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      currentIndividualInterval = null;
      
      // UI をリセット
      const toggle = document.getElementById('individualIntervalToggle');
      toggle.checked = false;
      toggle.dispatchEvent(new Event('change'));
      
      showMessage(data.message, 'success');
      
      // カレンダーを更新
      if (window.pageCalendar) {
        window.pageCalendar.refetchEvents();
      }
    } else {
      showMessage(data.error || 'リセットに失敗しました', 'danger');
    }
  })
  .catch(error => {
    console.error('❌ Individual interval reset failed:', error);
    showMessage('リセット中にエラーが発生しました', 'danger');
  })
  .finally(() => {
    resetBtn.disabled = false;
    resetBtn.innerHTML = '<i class="fas fa-undo me-1"></i>リセット';
  });
}

// 個別インターバルデータ読み込み
export function loadIndividualIntervalData(reservationId) {
  fetch(`/admin/reservations/${reservationId}/individual_interval.json`)
    .then(response => response.json())
    .then(data => {
      if (data.success && data.individual_interval) {
        const interval = data.individual_interval;
        currentIndividualInterval = interval.interval_minutes;
        
        // UIに設定値を反映
        const toggle = document.getElementById('individualIntervalToggle');
        const slider = document.getElementById('individual-interval-slider');
        const input = document.getElementById('individual-interval-input');
        
        if (toggle && slider && input) {
          toggle.checked = true;
          slider.value = Math.min(60, interval.interval_minutes);
          input.value = interval.interval_minutes;
          
          // change イベントを発火してUIを更新
          toggle.dispatchEvent(new Event('change'));
          slider.dispatchEvent(new Event('input'));
        }
        
        console.log('✅ Individual interval data loaded:', interval.interval_minutes);
      }
    })
    .catch(error => {
      console.error('❌ Failed to load individual interval data:', error);
    });
}

// インターバル設定初期化
export function setupIntervalControls() {
  // UIを作成
  createIntervalSettingsUI();
  
  // イベントリスナーを設定
  setupIntervalEventListeners();
  
  // グローバル関数として公開
  window.loadIndividualIntervalData = loadIndividualIntervalData;
  window.applyIndividualInterval = applyIndividualInterval;
  window.resetIndividualInterval = resetIndividualInterval;
  
  console.log('✅ Interval settings initialized');
}