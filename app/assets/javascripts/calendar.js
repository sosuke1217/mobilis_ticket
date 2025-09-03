        // Use the global reservations object set by the ERB in calendar.html.erb
        let reservations = window.reservations || {};
        let currentWeekStart = new Date(2025, 7, 10); // 2025年8月10日（日曜日）
        let weeklySchedules = {}; // 週別スケジュール（週のキーで保存）
        let defaultSchedule = {}; // デフォルトスケジュール
        let miniCalendarMonth = new Date(2025, 7, 1); // ミニカレンダーの表示月（8月）
        let clickedDate = null; // クリックされた日付
        let currentReservation = null; // 現在表示中の予約
        let searchTimeout = null; // 検索のデバウンス用
        let isEditingReservation = false; // 予約編集モードフラグ
        let reservationToEdit = null; // 編集対象の予約データ
        let cancelledReservations = []; // キャンセルされた予約のリスト
        let cancellationDisplayReady = false; // キャンセル表示の準備完了フラグ
        let domReady = false; // DOMの準備完了フラグ
        // ローカルストレージからキャンセル履歴を読み込み
        function loadCancelledReservations() {
            try {
                const stored = localStorage.getItem('cancelledReservations');
                if (stored) {
                    cancelledReservations = JSON.parse(stored);
        
                }
            } catch (error) {
                console.error('❌ Error loading cancelled reservations:', error);
                cancelledReservations = [];
            }
        }

        // ローカルストレージにキャンセル履歴を保存
        function saveCancelledReservations() {
            try {
                localStorage.setItem('cancelledReservations', JSON.stringify(cancelledReservations));
    
            } catch (error) {
                console.error('❌ Error saving cancelled reservations:', error);
            }
        }
        
        // 曜日の名前
        const dayNames = ['日', '月', '火', '水', '木', '金', '土'];
        const dayNamesLong = ['日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日'];
        
        // 月の名前
        const monthNames = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
        
        // 初期化
        function init() {
            // モーダル外クリックで閉じる機能を設定
            setupModalClickOutside();
            
            Promise.all([
                loadShiftSettingsFromBackend(),
                loadReservationsFromBackend()
            ]).then(() => {
                renderWeekView();
                renderDaySettings();
                renderMiniCalendar();
                showDragHint();
            });
        }

        // ドラッグヒントを表示
        function showDragHint() {
            // ヒント要素を作成
            const hint = document.createElement('div');
            hint.className = 'drag-hint';
            hint.textContent = '💡 予約をドラッグして時間を変更できます';
            document.body.appendChild(hint);
            
            // 3秒後に表示
            setTimeout(() => {
                hint.classList.add('show');
            }, 1000);
            
            // 5秒後に非表示
            setTimeout(() => {
                hint.classList.remove('show');
                setTimeout(() => {
                    if (hint.parentNode) {
                        hint.parentNode.removeChild(hint);
                    }
                }, 300);
            }, 5000);
        }
        
        // 予約変更を保存
        function saveReservationChanges(event) {
            event.preventDefault();
            
            console.log('🔄 saveReservationChanges called');
            
            if (!currentReservation) {
                showMessage('予約データが見つかりません。', 'error');
                return;
            }

            // フォームデータを取得
            const courseSelect = document.getElementById('edit-course');
            const statusSelect = document.getElementById('edit-status');
            const noteTextarea = document.getElementById('edit-note');
            
            console.log('📝 Form elements found:', {
                courseSelect: courseSelect ? 'found' : 'not found',
                statusSelect: statusSelect ? 'found' : 'not found',
                noteTextarea: noteTextarea ? 'found' : 'not found'
            });
            
            const newCourse = courseSelect ? courseSelect.value : `${currentReservation.duration}分`;
            const newDuration = extractDurationFromCourse(newCourse);
            const currentInterval = currentReservation.effective_interval_minutes ?? 10;
            
            // 営業時間内に収まるかチェック
            const businessHoursValidation = validateReservationTimeWithinBusinessHours(currentReservation, newDuration, currentInterval);
            if (!businessHoursValidation.valid) {
                showMessage(businessHoursValidation.message, 'error');
                return;
            }
            
            // 重複チェック
            const overlapValidation = validateReservationOverlap(currentReservation, newDuration, currentInterval);
            if (!overlapValidation.valid) {
                showMessage(overlapValidation.message, 'error');
                return;
            }
            
            const formData = {
                reservation: {
                    course: newCourse,
                    status: statusSelect ? statusSelect.value : currentReservation.status,
                    note: noteTextarea ? noteTextarea.value : currentReservation.note || ''
                }
            };
            
            // ユーザーが変更された場合のみuser_idを追加
            if (window.currentUserId && window.currentUserId !== currentReservation.userId) {
                formData.reservation.user_id = window.currentUserId;
            }
            
            console.log('📤 Sending form data:', formData);

            // バックエンドに更新リクエストを送信
            const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
            
            fetch(`/admin/reservations/${currentReservation.id}/update_booking`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrfToken
                },
                body: JSON.stringify(formData)
            })
            .then(response => {
                if (!response.ok) {
                    return response.json().then(errorData => {
                        throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.message || 'Unknown error'}`);
                    }).catch(() => {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    });
                }
                return response.json();
            })
            .then(data => {
                if (data.success) {
                    // ローカルデータを更新
                    const reservationData = data.reservation;
                    const updatedReservation = {
                        ...currentReservation,
                        customer: reservationData.name || reservationData.user?.name || '未設定',
                        phone: reservationData.user?.phone_number || '',
                        email: reservationData.user?.email || '',
                        duration: extractDurationFromCourse(reservationData.course),
                        status: reservationData.status,
                        note: reservationData.note || '',
                        updatedAt: reservationData.updated_at
                    };
                    
                    // グローバルreservationsオブジェクトを更新
                    const reservationDateKey = formatDateKey(new Date(currentReservation.start_time || currentReservation.time));
                    if (reservations[reservationDateKey]) {
                        const reservationIndex = reservations[reservationDateKey].findIndex(r => r.id === currentReservation.id);
                        if (reservationIndex !== -1) {
                            reservations[reservationDateKey][reservationIndex] = updatedReservation;
                        }
                    }
                    
                    // currentReservationを更新
                    currentReservation = updatedReservation;
                    
                    // カレンダーを再描画
                    generateTimeSlots();
                    
                    // モーダル内の変更日時を即座に更新
                    if (data.reservation && data.reservation.updated_at) {
                        updateModalUpdatedAt(data.reservation.updated_at);
                    }
                    
                    showMessage('予約が更新されました。', 'success');
                    
                    // モーダルを閉じる
                    closeReservationDetailModal();
                } else {
                    showMessage(`予約の更新に失敗しました: ${data.message}`, 'error');
                }
            })
            .catch(error => {
                console.error('Error updating reservation:', error);
                showMessage('予約の更新中にエラーが発生しました。', 'error');
            });
        }

        // モーダル内の変更日時を即座に更新
        function updateModalUpdatedAt(updatedAt) {
            const modal = document.getElementById('reservationDetailModal');
            if (!modal) return;
            
            const systemInfoSection = modal.querySelector('.system-info-section');
            if (!systemInfoSection) return;
            
            // 既存の変更日時要素を削除
            const detailItems = systemInfoSection.querySelectorAll('.detail-item');
            detailItems.forEach(item => {
                const label = item.querySelector('.detail-label');
                if (label && label.textContent === '変更日時') {
                    item.remove();
                }
            });
            
            // 作成日時要素を取得
            let createdAtItem = null;
            detailItems.forEach(item => {
                const label = item.querySelector('.detail-label');
                if (label && label.textContent === '作成日時') {
                    createdAtItem = item;
                }
            });
            
            if (!createdAtItem) return;
            
            // 新しい変更日時要素を作成
            const updatedAtItem = document.createElement('div');
            updatedAtItem.className = 'detail-item';
            updatedAtItem.innerHTML = `
                <span class="detail-label">変更日時</span>
                <span class="detail-value">${new Date(updatedAt).toLocaleString('ja-JP')}</span>
            `;
            
            // 作成日時の後に挿入
            createdAtItem.insertAdjacentElement('afterend', updatedAtItem);
        }

        // Note: updateIntervalOnChange function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling

        // Note: updateCalendarOnStatusChange function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling

        // Note: validateReservationTimeWithinBusinessHours function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling

        // Export or make available globally
        if (typeof window !== 'undefined') {
          // Note: updateIntervalOnChange and validateReservationTimeWithinBusinessHours 
          // are now defined in calendar.html.erb with enhanced functionality
        }

        // Note: validateReservationOverlap function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling


        // Note: updateCalendarOnCourseChange function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling



        // Note: openUserSelectionModal, handleUserSearch, and searchUsersForModal functions 
        // are now defined in calendar.html.erb with enhanced functionality


        // Note: saveUserSelection function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling



        // Note: loadShiftSettingsFromBackend function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling

        // Note: loadReservationsFromBackend function is now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling

        // デフォルトスケジュールを初期化
        function initializeDefaultSchedule() {
            defaultSchedule = {
                0: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 日曜日
                1: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 月曜日
                2: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 火曜日
                3: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 水曜日
                4: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 木曜日
                5: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 金曜日
                6: { enabled: true, times: [{ start: '10:00', end: '21:00' }] }, // 土曜日
            };
        }

        // 週表示を描画
        function renderWeekView() {
            updateWeekHeader();
            generateTimeSlots();
        }

        // 週のヘッダーを更新
        function updateWeekHeader() {
            const endDate = new Date(currentWeekStart);
            endDate.setDate(endDate.getDate() + 6);
            
            const startStr = formatDateShort(currentWeekStart);
            const endStr = formatDateShort(endDate);
            
            document.getElementById('currentWeek').textContent = 
                `${currentWeekStart.getFullYear()}年 ${startStr} - ${endStr}`;
            
            // 日付ヘッダーを更新
            const headers = document.querySelectorAll('.day-header');
            for (let i = 0; i < headers.length; i++) {
                const date = new Date(currentWeekStart);
                date.setDate(date.getDate() + i);
                
                const dayName = dayNames[date.getDay()];
                const dateStr = `${date.getMonth() + 1}/${date.getDate()}`;
                
                // CSSクラスをリセット
                headers[i].classList.remove('sunday', 'saturday');
                
                // 正しいCSSクラスを追加
                if (date.getDay() === 0) {
                    headers[i].classList.add('sunday');
                } else if (date.getDay() === 6) {
                    headers[i].classList.add('saturday');
                }
                
                headers[i].innerHTML = `${dayName}<br><span style="font-size: 12px;">${dateStr}</span>`;
            }
        }

        // タイムスロットを生成
        function generateTimeSlots() {
            console.log('🔍 generateTimeSlots called - defaultSchedule:', defaultSchedule);
            console.log('🔍 generateTimeSlots - current reservations data:', reservations);
            // Helper to find reservation by id across all date keys
            function findReservationById(resId) {
                for (const dateKey of Object.keys(reservations)) {
                    const found = reservations[dateKey].find(r => r.id === resId);
                    if (found) return found;
                }
                return undefined;
            }
            console.log('🔍 generateTimeSlots - reservation 97 data:', findReservationById(97));
            const scheduleBody = document.getElementById('scheduleBody');
            scheduleBody.innerHTML = '';
            
            // 8:00から21:00まで10分刻みで生成
            for (let hour = 8; hour <= 21; hour++) {
                for (let minute = 0; minute < 60; minute += 10) {
                    if (hour === 21 && minute > 0) break; // 21:00で終了
                    
                    const timeStr = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
                    
                    // 行コンテナを作成
                    const row = document.createElement('div');
                    row.className = 'schedule-row';
                    
                    // 行全体のスタイルを追加
                    if (minute === 0) {
                        row.classList.add('hour-row');
                    } else if (minute === 30) {
                        row.classList.add('half-hour-row');
                    }
                    
                    // 時刻ラベル
                    const timeSlot = document.createElement('div');
                    timeSlot.className = 'time-slot';
                    
                    // 時間マーカーのスタイルを追加（10分刻みに対応）
                    if (minute === 0) {
                        timeSlot.classList.add('hour-marker');
                    } else if (minute === 30) {
                        timeSlot.classList.add('half-hour-marker');
                    }
                    
                    timeSlot.textContent = timeStr;
                    row.appendChild(timeSlot);
                    
                    // 各曜日のセル
                    for (let day = 0; day < 7; day++) {
                        const cell = document.createElement('div');
                        cell.className = 'schedule-cell';
                        cell.dataset.day = day;
                        cell.dataset.time = timeStr;
                        
                        // ドロップゾーンとして設定
                        cell.addEventListener('dragover', handleDragOver);
                        cell.addEventListener('drop', handleDrop);
                        cell.addEventListener('dragenter', handleDragEnter);
                        cell.addEventListener('dragleave', handleDragLeave);
                        
                        const scheduleDate = new Date(currentWeekStart);
                        scheduleDate.setDate(scheduleDate.getDate() + day);
                        const dateKey = formatDateKey(scheduleDate);
                        
                                                // 営業時間チェック
                        if (isBusinessHour(day, timeStr)) {
                            // 予約チェック
                            const reservation = findReservation(dateKey, timeStr);
                            
                            // デバッグ用ログ（特定の時間のみ）
                            if (timeStr === '10:00' && day === 1) {
                                console.log(`🔍 Checking for reservation at ${dateKey} ${timeStr}:`, {
                                    dayReservations: reservations[dateKey] || [],
                                    foundReservation: reservation,
                                    isReservationStart: reservation ? isReservationStart(dateKey, timeStr) : false
                                });
                            }
                            
                            if (reservation) {
                                // 予約の開始スロットの場合のみブロックを表示
                                if (isReservationStart(dateKey, timeStr)) {
                                    console.log('🎯 Creating reservation block for:', {
                                        id: reservation.id,
                                        customer: reservation.customer,
                                        userId: reservation.userId,
                                        date: dateKey,
                                        time: timeStr,
                                        effective_interval_minutes: reservation.effective_interval_minutes,
                                        individual_interval_minutes: reservation.individual_interval_minutes,
                                        duration: reservation.duration
                                    });
                                    const block = createSpanningReservationBlock(reservation, dateKey, timeStr);
                                    cell.appendChild(block);
                                    // 予約詳細を表示するためのクリックイベント
                                    reservation.date = dateKey; // PATCH: always set date
                                    cell.addEventListener('click', (e) => {
                                        // ドラッグ中でない場合のみクリックイベントを実行
                                        if (!isDragging) {
                                            openReservationDetailModal(reservation);
                                        }
                                    });
                                    
                                    // ドラッグイベントを追加（メインブロックに追加）
                                    console.log('🎯 Setting up drag events for reservation:', reservation.id);
                                    block.addEventListener('dragstart', handleDragStart);
                                    block.addEventListener('dragend', handleDragEnd);
                                    
                                    // Also add drag over to the cell for visual feedback
                                    cell.addEventListener('dragover', handleDragOver);
                                    
                                    // デバッグ用ログ（特定の予約のみ）
                                    if (reservation.customer === '田中様') {
                                        console.log(`🔍 Created reservation block for ${dateKey} ${timeStr}:`, reservation);
                                    }
                                }
    } else {
                                cell.classList.add('available', 'bookable');
                                // 新規予約作成のためのクリックイベント
                                cell.addEventListener('click', () => {
                                    const slotDate = new Date(currentWeekStart);
                                    slotDate.setDate(slotDate.getDate() + day);
                                    openBookingModal(slotDate, timeStr);
                                });
                            }
                        } else {
                            cell.classList.add('unavailable', 'outside-business-hours');
                        }
                        
                        row.appendChild(cell);
                    }
                    
                    scheduleBody.appendChild(row);
                }
            }
            
            // スケジュール生成後にキャンセル表示を更新
            setTimeout(() => {
                updateCancellationDisplayImmediately();
            }, 10);
        }

        // Note: getCurrentWeekSchedule and isBusinessHour functions are now defined in calendar.html.erb
        // with enhanced functionality including date-aware scheduling
  
        // Note: findReservation, isReservationStart, and isReservationContinuation functions 
        // are now defined in calendar.html.erb with enhanced functionality

        // 予約ブロックを作成
        function createReservationBlock(reservation) {
            const block = document.createElement('div');
            block.className = `reservation-block ${reservation.status}`;
            block.draggable = true;
            block.dataset.reservationId = reservation.id;
            block.dataset.reservationData = JSON.stringify(reservation);
            
            const statusIcon = {
                'tentative': '⏳',
                'confirmed': '✓',
                'completed': '✅'
            };
            
            block.innerHTML = `
                ${statusIcon[reservation.status] || ''} ${reservation.customer}
                <div style="font-size: 9px; opacity: 0.9;">${reservation.duration}分</div>
            `;
            
            return block;
        }

        // スパニング予約ブロックを作成
        function createSpanningReservationBlock(reservation, dateKey, timeStr) {
            console.log('🎯 Creating spanning block for reservation:', reservation.id, {
                effective_interval_minutes: reservation.effective_interval_minutes,
                individual_interval_minutes: reservation.individual_interval_minutes,
                duration: reservation.duration
            });
            const block = document.createElement('div');
            block.className = `reservation-block spanning ${reservation.status}`;
            block.draggable = true; // メインブロックをドラッグ可能に変更
            block.dataset.reservationId = reservation.id;
            block.dataset.reservationData = JSON.stringify(reservation);
            block.dataset.originalDateKey = dateKey;
            block.dataset.originalTimeStr = timeStr;
            
            const statusIcon = {
                'tentative': '⏳',
                'confirmed': '✓',
                'completed': '✅'
            };
            
            // 予約の継続時間に基づいて高さを計算（正確な時間 + 準備時間）
            const durationInMinutes = reservation.duration;
            const preparationTime = reservation.effective_interval_minutes ?? 10; // 準備時間（分）
            const totalTime = durationInMinutes + preparationTime;
                         const rowHeight = 20; // 各時間スロットの高さ（10分間）
            const exactHeight = (totalTime / 10) * rowHeight; // 正確な高さを計算
            
            block.style.height = `${exactHeight}px`;
            block.style.top = '0';
            
            // 準備時間部分を視覚的に区別
            const bookingHeight = (durationInMinutes / 10) * rowHeight;
            const preparationHeight = (preparationTime / 10) * rowHeight;
            
            // 開始時間と終了時間を計算
            const [startHour, startMin] = timeStr.split(':').map(Number);
            const startTimeInMinutes = startHour * 60 + startMin;
            const endTimeInMinutes = startTimeInMinutes + reservation.duration;
            
            const startTime = `${String(Math.floor(startTimeInMinutes / 60)).padStart(2, '0')}:${String(startTimeInMinutes % 60).padStart(2, '0')}`;
            const endTime = `${String(Math.floor(endTimeInMinutes / 60)).padStart(2, '0')}:${String(endTimeInMinutes % 60).padStart(2, '0')}`;
            
            // 準備時間が0の場合は準備時間セクションを表示しない
            const preparationSection = preparationTime > 0 ? `
                <div style="height: ${preparationHeight}px; background: linear-gradient(135deg, rgba(255,255,255,0.2), rgba(255,255,255,0.1)); display: flex; align-items: center; justify-content: center; font-size: 9px; border-top: 1px solid rgba(255,255,255,0.3); backdrop-filter: blur(1px); position: absolute; left: 0; right: 0; bottom: 0; width: 100%;">
                    <div style="position: absolute; top: 0; left: 0; right: 0; height: 1px; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent);"></div>
                    <span style="background: rgba(255,255,255,0.25); padding: 3px 10px; border-radius: 15px; font-weight: 600; font-size: 8px; text-transform: uppercase; letter-spacing: 0.5px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">${preparationTime}分</span>
                </div>
            ` : '';
            
            block.innerHTML = `
                <div style="height: ${preparationTime > 0 ? bookingHeight : exactHeight}px; display: flex; flex-direction: column; justify-content: center; padding: 8px; position: relative;">

                    <div style="font-size: 12px; font-weight: 600; margin-bottom: 4px; text-shadow: 0 1px 2px rgba(0,0,0,0.3);">
                        ${statusIcon[reservation.status] || ''} ${reservation.customer}
      </div>
                    <div style="font-size: 10px; opacity: 0.9; background: rgba(255,255,255,0.2); padding: 2px 6px; border-radius: 10px; display: inline-block; backdrop-filter: blur(2px); margin-bottom: 4px;">
                        ${reservation.duration}分
    </div>
                    <div style="font-size: 9px; opacity: 0.8; background: rgba(0,0,0,0.2); padding: 2px 6px; border-radius: 8px; display: inline-block; backdrop-filter: blur(1px);">
                        ${startTime} - ${endTime}
        </div>
        </div>
                ${preparationSection}
    `;
            
            return block;
        }

        // 設定モーダルを開く
        function openSettingsModal() {
            document.getElementById('settingsModal').style.display = 'block';
            renderDaySettings();
        }

        // 設定モーダルを閉じる
        function closeSettingsModal() {
            document.getElementById('settingsModal').style.display = 'none';
        }

        // タブ切り替え
        function switchTab(tabName) {
            // タブボタンの状態更新
            document.querySelectorAll('.tab-button').forEach(btn => btn.classList.remove('active'));
            document.querySelector(`[onclick="switchTab('${tabName}')"]`).classList.add('active');
            
            // タブコンテンツの表示切り替え
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
            document.getElementById(`${tabName}-tab`).classList.add('active');
            
            if (tabName === 'recurring') {
                renderRecurringDaySettings();
            }
        }

        // 曜日別設定を描画
        function renderDaySettings() {
            // 週情報を更新
            updateWeekInfo();
            
            const container = document.getElementById('daySettings');
            container.innerHTML = '';
            
            for (let day = 0; day < 7; day++) {
                const dayDiv = createDaySettingDiv(day, false);
                container.appendChild(dayDiv);
            }
        }

        // 定期的な設定を描画
        function renderRecurringDaySettings() {
            const container = document.getElementById('recurringDaySettings');
            container.innerHTML = '';
            
            for (let day = 0; day < 7; day++) {
                const dayDiv = createDaySettingDiv(day, true);
                container.appendChild(dayDiv);
            }
        }

        // 週情報を更新
        function updateWeekInfo() {
            const weekStartStr = formatDateKey(currentWeekStart);
            const weekEnd = new Date(currentWeekStart);
            weekEnd.setDate(weekEnd.getDate() + 6);
            const weekEndStr = formatDateKey(weekEnd);
            
            const currentWeekDisplay = document.getElementById('current-week-display');
            const scheduleTypeInfo = document.getElementById('schedule-type-info');
            
            if (currentWeekDisplay) {
                currentWeekDisplay.textContent = `${weekStartStr} 〜 ${weekEndStr}`;
            }
            
            if (scheduleTypeInfo) {
                const hasCustomSchedule = weeklySchedules[weekStartStr] && 
                    JSON.stringify(weeklySchedules[weekStartStr]) !== JSON.stringify(defaultSchedule);
                
                if (hasCustomSchedule) {
                    scheduleTypeInfo.textContent = '✅ この週にはカスタムスケジュールが設定されています';
                    scheduleTypeInfo.style.color = '#28a745';
                } else {
                    scheduleTypeInfo.textContent = 'ℹ️ この週にはデフォルトスケジュールが適用されています';
                    scheduleTypeInfo.style.color = '#6c757d';
                }
            }
        }

        // 曜日設定DIVを作成
        function createDaySettingDiv(day, isRecurring) {
            // 安全チェック: スケジュールデータが読み込まれているか確認
            if (!defaultSchedule || !defaultSchedule[day]) {
                console.warn(`⚠️ Schedule data not loaded for day ${day}, using fallback`);
                return createFallbackDaySettingDiv(day, isRecurring);
            }
            
            const schedule = isRecurring ? defaultSchedule[day] : getCurrentWeekSchedule()[day];
            const dayDiv = document.createElement('div');
            dayDiv.className = 'day-setting';
            
            const headerClass = day === 0 ? 'sunday' : day === 6 ? 'saturday' : '';
            
            dayDiv.innerHTML = `
                <div class="day-setting-header ${headerClass}">
                    <span>${dayNamesLong[day]}</span>
                    <div class="day-toggle ${schedule.enabled ? 'active' : ''}" onclick="toggleDay(${day}, ${isRecurring})"></div>
        </div>
                <div class="time-slots-container" style="display: ${schedule.enabled ? 'block' : 'none'};">
                    <div id="timeSlots-${day}-${isRecurring}" class="time-slots">
                        ${renderTimeSlots(day, schedule.times, isRecurring)}
        </div>
                    <button class="add-time-btn" onclick="addTimeSlot(${day}, ${isRecurring})">
                        + 時間帯を追加
          </button>
        </div>
  `;
            
            return dayDiv;
        }

        // フォールバック用の曜日設定DIVを作成
        function createFallbackDaySettingDiv(day, isRecurring) {
            const dayDiv = document.createElement('div');
            dayDiv.className = 'day-setting';
            
            const headerClass = day === 0 ? 'sunday' : day === 6 ? 'saturday' : '';
            
            dayDiv.innerHTML = `
                <div class="day-setting-header ${headerClass}">
                    <span>${dayNamesLong[day]}</span>
                    <div class="day-toggle" onclick="toggleDay(${day}, ${isRecurring})"></div>
      </div>
                <div class="time-slots-container" style="display: none;">
                    <div id="timeSlots-${day}-${isRecurring}" class="time-slots">
                        <!-- データ読み込み中 -->
                    </div>
                    <button class="add-time-btn" onclick="addTimeSlot(${day}, ${isRecurring})">
                        + 時間帯を追加
                    </button>
    </div>
  `;
            
            return dayDiv;
        }

        // 時間スロットを描画
        function renderTimeSlots(day, times, isRecurring = false) {
            // timesがundefinedまたは配列でない場合は空文字を返す
            if (!times || !Array.isArray(times)) {
                console.warn(`⚠️ renderTimeSlots: times is not an array for day ${day}:`, times);
                return '';
            }
            
            return times.map((time, index) => `
                <div class="time-slot-input">
                    <input type="time" class="time-input" value="${time.start}" 
                           onchange="(async () => { await updateTimeSlot(${day}, ${index}, 'start', this.value, ${isRecurring}); })()">
                    <span>〜</span>
                    <input type="time" class="time-input" value="${time.end}"
                           onchange="(async () => { await updateTimeSlot(${day}, ${index}, 'end', this.value, ${isRecurring}); })()">
                    <button class="btn btn-danger btn-sm" onclick="removeTimeSlot(${day}, ${index}, ${isRecurring})">削除</button>
                </div>
            `).join('');
        }

        // 曜日の有効/無効を切り替え
        function toggleDay(day, isRecurring) {
            console.log(`Toggling day ${day} (${dayNamesLong[day]}) for recurring: ${isRecurring}`);
            
            if (isRecurring) {
                // 定期的なスケジュールの場合
                defaultSchedule[day].enabled = !defaultSchedule[day].enabled;
            } else {
                // 現在の週の場合、カスタムスケジュールを作成
                const weekKey = formatDateKey(currentWeekStart);
                if (!weeklySchedules[weekKey]) {
                    weeklySchedules[weekKey] = JSON.parse(JSON.stringify(defaultSchedule));
                    console.log(`🔍 Created custom schedule for week ${weekKey}`);
                }
                weeklySchedules[weekKey][day].enabled = !weeklySchedules[weekKey][day].enabled;
            }
            
            const toggle = document.querySelector(`[onclick="toggleDay(${day}, ${isRecurring})"]`);
            const timeSlotsContainer = toggle.parentElement.nextElementSibling;
            
            const schedule = isRecurring ? defaultSchedule[day] : getCurrentWeekSchedule()[day];
            
            if (schedule.enabled) {
                toggle.classList.add('active');
                timeSlotsContainer.style.display = 'block';
                
                // 時間スロットがない場合は追加
                if (schedule.times.length === 0) {
                    schedule.times.push({ start: '09:00', end: '18:00' });
                }
                
                // 現在のタブのコンテナのみ更新
                const slotsContainer = document.getElementById(`timeSlots-${day}-${isRecurring}`);
                if (slotsContainer) {
                    slotsContainer.innerHTML = renderTimeSlots(day, schedule.times, isRecurring);
                }
            } else {
                toggle.classList.remove('active');
                timeSlotsContainer.style.display = 'none';
            }
            
            console.log(`Day ${day} (${dayNamesLong[day]}) is now ${schedule.enabled ? 'enabled' : 'disabled'} for ${isRecurring ? 'recurring' : 'current week'}`);
        }

        // 時間スロットを追加
        function addTimeSlot(day, isRecurring) {
            if (isRecurring) {
                defaultSchedule[day].times.push({ start: '09:00', end: '18:00' });
            } else {
                // 現在の週の場合、カスタムスケジュールを作成
                const weekKey = formatDateKey(currentWeekStart);
                if (!weeklySchedules[weekKey]) {
                    weeklySchedules[weekKey] = JSON.parse(JSON.stringify(defaultSchedule));
                    console.log(`🔍 Created custom schedule for week ${weekKey}`);
                }
                weeklySchedules[weekKey][day].times.push({ start: '09:00', end: '18:00' });
            }
            
            // 現在のタブのコンテナのみ更新
            const slotsContainer = document.getElementById(`timeSlots-${day}-${isRecurring}`);
            if (slotsContainer) {
                const schedule = isRecurring ? defaultSchedule[day] : getCurrentWeekSchedule()[day];
                slotsContainer.innerHTML = renderTimeSlots(day, schedule.times, isRecurring);
            }
        }

        // 時間スロットを削除
        function removeTimeSlot(day, index, isRecurring = false) {
            if (isRecurring) {
                defaultSchedule[day].times.splice(index, 1);
            } else {
                // 現在の週の場合、カスタムスケジュールを作成
                const weekKey = formatDateKey(currentWeekStart);
                if (!weeklySchedules[weekKey]) {
                    weeklySchedules[weekKey] = JSON.parse(JSON.stringify(defaultSchedule));
                    console.log(`🔍 Created custom schedule for week ${weekKey}`);
                }
                weeklySchedules[weekKey][day].times.splice(index, 1);
            }
            
            // 現在のタブのコンテナのみ更新
            const slotsContainer = document.getElementById(`timeSlots-${day}-${isRecurring}`);
            if (slotsContainer) {
                const schedule = isRecurring ? defaultSchedule[day] : getCurrentWeekSchedule()[day];
                slotsContainer.innerHTML = renderTimeSlots(day, schedule.times, isRecurring);
            }
        }

        // 時間スロットを更新
        async function updateTimeSlot(day, index, field, value, isRecurring = false) {
            // 変更前の値を保存
            let oldValue;
            if (isRecurring) {
                oldValue = defaultSchedule[day].times[index][field];
            } else {
                const weekKey = formatDateKey(currentWeekStart);
                if (!weeklySchedules[weekKey]) {
                    weeklySchedules[weekKey] = JSON.parse(JSON.stringify(defaultSchedule));
                }
                oldValue = weeklySchedules[weekKey][day].times[index][field];
            }
            
            // 新しい値を設定
            if (isRecurring) {
                defaultSchedule[day].times[index][field] = value;
            } else {
                const weekKey = formatDateKey(currentWeekStart);
                if (!weeklySchedules[weekKey]) {
                    weeklySchedules[weekKey] = JSON.parse(JSON.stringify(defaultSchedule));
                    console.log(`🔍 Created custom schedule for week ${weekKey}`);
                }
                weeklySchedules[weekKey][day].times[index][field] = value;
            }
            
            // 営業時間の変更（短縮・拡張）の場合、影響をチェック
            if ((field === 'end' && parseInt(value) < parseInt(oldValue)) || 
                (field === 'start' && parseInt(value) > parseInt(oldValue)) ||
                (field === 'end' && parseInt(value) > parseInt(oldValue)) || 
                (field === 'start' && parseInt(value) < parseInt(oldValue))) {
                console.log(`🔍 Checking impact of changing business hours for day ${day} from ${oldValue} to ${value} (${field})`);
                
                // 影響を受ける予約をチェック
                const affectedReservations = checkShiftChangeImpact(day, oldValue, value, field);
                
                if (affectedReservations.length > 0) {
                    // 影響がある場合は確認ダイアログを表示
                    const confirmed = await showShiftChangeConfirmation(affectedReservations, day, oldValue, value, field);
                    if (!confirmed) {
                        // キャンセルされた場合は元の値に戻す
                        if (isRecurring) {
                            defaultSchedule[day].times[index][field] = oldValue;
                        } else {
                            const weekKey = formatDateKey(currentWeekStart);
                            weeklySchedules[weekKey][day].times[index][field] = oldValue;
                        }
                        return;
                    }
                }
            }
        }

        // 設定を保存
        function saveSettings() {
            // 現在アクティブなタブを確認
            const activeTab = document.querySelector('.tab-button.active');
            const isRecurring = activeTab && activeTab.textContent.includes('定期的なスケジュール');
            
            console.log('🔍 Active tab:', activeTab ? activeTab.textContent : 'none');
            console.log('🔍 isRecurring:', isRecurring);
            
            const scheduleData = isRecurring ? defaultSchedule : getCurrentWeekSchedule();
            const weekStartStr = formatDateKey(currentWeekStart);
            
            console.log('🔄 Saving shift settings:', {
                isRecurring,
                weekStartStr,
                scheduleData
            });
            
            // バックエンドに保存
            fetch('/admin/reservations/save_shift_settings', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
                },
                body: JSON.stringify({
                    schedule_data: scheduleData,
                    is_recurring: isRecurring,
                    week_start_date: weekStartStr
                })
            })
            .then(response => response.json())
  .then(data => {
    if (data.success) {
                    console.log('✅ Shift settings saved successfully');
                    
                    // 表示を更新
                    renderWeekView();
                    closeSettingsModal();
                    
                    // 保存完了メッセージ
                    const message = isRecurring 
                        ? '定期的なスケジュールが保存されました。この設定は全ての週に適用されます。'
                        : '設定が保存されました。この設定は現在の週のみに適用されます。';
                    showMessage(message, 'success');
    } else {
                    console.error('❌ Failed to save shift settings:', data.message);
                    showMessage(`シフト設定の保存に失敗しました: ${data.message}`, 'error');
    }
  })
  .catch(error => {
                console.error('❌ Error saving shift settings:', error);
                showMessage('シフト設定の保存中にエラーが発生しました', 'error');
            });
        }

        // 前週へ
        function previousWeek() {
            currentWeekStart.setDate(currentWeekStart.getDate() - 7);
            Promise.all([
                loadShiftSettingsFromBackend(),
                loadReservationsFromBackend()
            ]).then(() => {
                renderWeekView();
                updateCancellationDisplay(); // キャンセル履歴を更新
            });
        }

        // 次週へ
        function nextWeek() {
            currentWeekStart.setDate(currentWeekStart.getDate() + 7);
            Promise.all([
                loadShiftSettingsFromBackend(),
                loadReservationsFromBackend()
            ]).then(() => {
                renderWeekView();
                updateCancellationDisplay(); // キャンセル履歴を更新
            });
        }

        // 日付をフォーマット（短縮版）
        function formatDateShort(date) {
            return `${date.getMonth() + 1}月${date.getDate()}日`;
        }
        
        // シフト変更の影響をチェック
        function checkShiftChangeImpact(day, oldTime, newTime, field) {
            const affectedReservations = [];
            const dayNames = ['日', '月', '火', '水', '木', '金', '土'];
            
            console.log(`🔍 checkShiftChangeImpact called with: day=${day} (${dayNames[day]}), oldTime=${oldTime}, newTime=${newTime}, field=${field}`);
            console.log(`🔍 All reservations:`, reservations);
            
            // 全ての予約をチェック（週に関係なく）
            Object.keys(reservations).forEach(weekKey => {
                const weekReservations = reservations[weekKey] || [];
                
                weekReservations.forEach(reservation => {
                    // 週のキーから日付を取得
                    const reservationDate = new Date(weekKey);
                    const reservationDayOfWeek = reservationDate.getDay();
                    
                    console.log(`🔍 Checking reservation: ${reservation.id} on ${weekKey} (day ${reservationDayOfWeek}) vs target day ${day}`);
                    
                    // 同じ曜日の予約をチェック
                    if (reservationDayOfWeek === day) {
                        const [startHour, startMin] = reservation.time.split(':').map(Number);
                        const reservationStartInMin = startHour * 60 + startMin;
                        const reservationEndInMin = reservationStartInMin + reservation.duration;
                        console.log(`🔍 Reservation time: ${reservation.time} (start: ${reservationStartInMin} min, duration: ${reservation.duration} min, end: ${reservationEndInMin} min)`);
                        let isAffected = false;
                        if (field === 'end') {
                            if (parseInt(newTime) < parseInt(oldTime)) {
                                // 新しい終了時間（分単位）
                                let newEndInMin;
                                if (String(newTime).includes(':')) {
                                    const [h, m] = String(newTime).split(':').map(Number);
                                    newEndInMin = h * 60 + (isNaN(m) ? 0 : m);
                                } else {
                                    newEndInMin = parseInt(newTime) * 60;
                                }
                                // 終了時間が短縮される場合 - 予約が新しい終了時間を超える場合
                                isAffected = reservationEndInMin > newEndInMin;
                                console.log(`🔍 End time shrinking check: reservation ends at ${reservationEndInMin} min, new end time is ${newEndInMin} min = ${isAffected}`);
                            } else {
                                // 終了時間が拡張される場合
                                let oldEndInMin, newEndInMin;
                                if (String(oldTime).includes(':')) {
                                    const [h, m] = String(oldTime).split(':').map(Number);
                                    oldEndInMin = h * 60 + (isNaN(m) ? 0 : m);
                                } else {
                                    oldEndInMin = parseInt(oldTime) * 60;
                                }
                                if (String(newTime).includes(':')) {
                                    const [h, m] = String(newTime).split(':').map(Number);
                                    newEndInMin = h * 60 + (isNaN(m) ? 0 : m);
                                } else {
                                    newEndInMin = parseInt(newTime) * 60;
                                }
                                isAffected = reservationStartInMin >= oldEndInMin && reservationStartInMin < newEndInMin;
                                console.log(`🔍 End time expanding check: ${reservationStartInMin} >= ${oldEndInMin} AND ${reservationStartInMin} < ${newEndInMin} = ${isAffected}`);
                            }
                        } else if (field === 'start') {
                            if (parseInt(newTime) > parseInt(oldTime)) {
                                // 開始時間が遅くなる場合
                                let newStartInMin;
                                if (String(newTime).includes(':')) {
                                    const [h, m] = String(newTime).split(':').map(Number);
                                    newStartInMin = h * 60 + (isNaN(m) ? 0 : m);
                                } else {
                                    newStartInMin = parseInt(newTime) * 60;
                                }
                                isAffected = reservationStartInMin < newStartInMin;
                                console.log(`🔍 Start time delaying check: ${reservationStartInMin} < ${newStartInMin} = ${isAffected}`);
                            } else {
                                // 開始時間が早くなる場合
                                let oldStartInMin, newStartInMin;
                                if (String(oldTime).includes(':')) {
                                    const [h, m] = String(oldTime).split(':').map(Number);
                                    oldStartInMin = h * 60 + (isNaN(m) ? 0 : m);
                                } else {
                                    oldStartInMin = parseInt(oldTime) * 60;
                                }
                                if (String(newTime).includes(':')) {
                                    const [h, m] = String(newTime).split(':').map(Number);
                                    newStartInMin = h * 60 + (isNaN(m) ? 0 : m);
                                } else {
                                    newStartInMin = parseInt(newTime) * 60;
                                }
                                isAffected = reservationStartInMin >= newStartInMin && reservationStartInMin < oldStartInMin;
                                console.log(`🔍 Start time advancing check: ${reservationStartInMin} >= ${newStartInMin} AND ${reservationStartInMin} < ${oldStartInMin} = ${isAffected}`);
                            }
                        }
                        if (isAffected) {
                            affectedReservations.push({
                                id: reservation.id,
                                customer: reservation.customer,
                                start_time: reservation.time,
                                end_time: `${Math.floor(reservationEndInMin/60)}:${(reservationEndInMin%60).toString().padStart(2,'0')}`,
                                date: weekKey,
                                dayName: dayNames[day]
                            });
                            console.log(`🔍 Added affected reservation: ${reservation.id}`);
                        }
                    }
                });
            });
            
            console.log(`🔍 Found ${affectedReservations.length} affected reservations for day ${day} (${dayNames[day]}) - ${field} time change`);
            return affectedReservations;
        }
        
        // シフト変更の確認ダイアログを表示
        function showShiftChangeConfirmation(affectedReservations, day, oldTime, newTime, field) {
            return new Promise((resolve) => {
                const dayNames = ['日', '月', '火', '水', '木', '金', '土'];
                const fieldName = field === 'start' ? '開始時間' : '終了時間';
                
                // 既存のモーダルがあれば削除
                const existingModal = document.getElementById('shiftChangeModal');
                if (existingModal) {
                    existingModal.remove();
                }
                
                const modal = document.createElement('div');
                modal.id = 'shiftChangeModal';
                modal.className = 'modal fade';
                modal.setAttribute('tabindex', '-1');
                modal.setAttribute('aria-labelledby', 'shiftChangeModalLabel');
                modal.setAttribute('aria-hidden', 'true');
                modal.innerHTML = `
                    <div class="modal-dialog modal-lg">
                        <div class="modal-content">
                            <div class="modal-header bg-warning text-dark">
                                <h5 class="modal-title" id="shiftChangeModalLabel">⚠️ 営業時間変更の確認</h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>
                            <div class="modal-body">
                                <div class="alert alert-warning mb-1">
                                    <strong>営業時間の変更により影響を受ける予約があります:</strong><br>
                                    ${dayNames[day]}曜日 ${fieldName}: ${oldTime}:00 → ${newTime}:00
                                </div>
                                
                                <div class="table-responsive mb-1" style="max-height: 300px; overflow-y: hidden;">
                                    <table class="table table-sm mb-0">
                                        <thead>
                                            <tr>
                                                <th style="font-size: 1rem; padding: 0.3rem;">日時</th>
                                                <th style="font-size: 1rem; padding: 0.3rem;">お客様</th>
                                                <th style="font-size: 1rem; padding: 0.3rem;">時間</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            ${affectedReservations.map(reservation => `
                                                <tr>
                                                    <td style="font-size: 1rem; padding: 0.3rem;">${reservation.date}</td>
                                                    <td style="font-size: 1rem; padding: 0.3rem;">${reservation.customer}</td>
                                                    <td style="font-size: 1rem; padding: 0.3rem;">${reservation.start_time}-${reservation.end_time}</td>
                                                </tr>
                                            `).join('')}
                                        </tbody>
                                    </table>
                                </div>
                                
                                <div class="alert alert-danger mb-0">
                                    <strong>エラー:</strong> 営業時間を変更すると、これらの予約が営業時間外になってしまいます。変更はできません。
                                </div>
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-primary" id="cancelShiftChange">OK</button>
                            </div>
                        </div>
                    </div>
                `;
                
                document.body.appendChild(modal);
                
                // イベントリスナーを設定
                const cancelBtn = modal.querySelector('#cancelShiftChange');
                const closeBtn = modal.querySelector('.btn-close');
                
                cancelBtn.addEventListener('click', () => {
                    modal.remove();
                    resolve(false);
                });
                
                closeBtn.addEventListener('click', () => {
                    modal.remove();
                    resolve(false);
                });
                
                // モーダルの外側クリックで閉じる
                modal.addEventListener('click', (event) => {
                    if (event.target === modal) {
                        modal.remove();
                        resolve(false);
                    }
                });
                
                // モーダルを表示
                modal.style.display = 'block';
                modal.classList.add('show');
                modal.setAttribute('aria-modal', 'true');
                modal.setAttribute('role', 'dialog');
                
                // 背景を暗くする
                const backdrop = document.createElement('div');
                backdrop.className = 'modal-backdrop fade show';
                backdrop.id = 'shiftChangeBackdrop';
                document.body.appendChild(backdrop);
                
                        // ESCキーで閉じる
        const handleEscKey = (event) => {
            if (event.key === 'Escape') {
                modal.remove();
                backdrop.remove();
                document.removeEventListener('keydown', handleEscKey);
                resolve(false);
            }
        };
        document.addEventListener('keydown', handleEscKey);
        
        // モーダルとバックドロップを削除する関数
        const cleanup = () => {
            if (modal) modal.remove();
            if (backdrop) backdrop.remove();
            document.removeEventListener('keydown', handleEscKey);
        };
        
        // クリーンアップを設定
        cancelBtn.addEventListener('click', cleanup);
        closeBtn.addEventListener('click', cleanup);
        modal.addEventListener('click', (event) => {
            if (event.target === modal) {
                cleanup();
                resolve(false);
            }
        });
    });
        }

        // 日付キーをフォーマット
        function formatDateKey(date) {
            return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        }

        // メッセージ表示
function showMessage(message, type = 'info') {
            const messageDiv = document.createElement('div');
            messageDiv.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 2000;
                padding: 12px 20px;
                border-radius: 6px;
                color: white;
                font-weight: 500;
                animation: slideInRight 0.3s ease;
                background: ${type === 'success' ? '#28a745' : type === 'error' ? '#dc3545' : type === 'warning' ? '#ffc107' : '#007bff'};
                color: ${type === 'warning' ? '#212529' : 'white'};
            `;
            messageDiv.textContent = message;
            
            document.body.appendChild(messageDiv);
            
  setTimeout(() => {
                messageDiv.style.animation = 'slideOutRight 0.3s ease';
                setTimeout(() => document.body.removeChild(messageDiv), 300);
  }, 3000);
}

        // モーダルの外側クリックで閉じる
        window.onclick = function(event) {
            const modal = document.getElementById('settingsModal');
            if (modal && event.target === modal) {
                console.log('🔧 Calendar.js window.onclick - closing settings modal');
                closeSettingsModal();
            }
            
            // ミニカレンダーの外側クリックで閉じる
            const miniCalendar = document.getElementById('miniCalendar');
            const miniCalendarContainer = document.querySelector('.mini-calendar-container');
            if (miniCalendar && miniCalendarContainer && !miniCalendarContainer.contains(event.target)) {
                miniCalendar.classList.remove('show');
            }
        }

        // ミニカレンダー関連の関数
        function toggleMiniCalendar() {
            const miniCalendar = document.getElementById('miniCalendar');
            miniCalendar.classList.toggle('show');
        }

        function renderMiniCalendar() {
            const year = miniCalendarMonth.getFullYear();
            const month = miniCalendarMonth.getMonth();
            
            console.log('📅 Rendering mini calendar for:', year, '年', monthNames[month]);
            
            // タイトルを更新
            document.getElementById('miniCalendarTitle').textContent = 
                `${year}年 ${monthNames[month]}`;
            
            // 月の最初の日と最後の日を取得
            const firstDay = new Date(year, month, 1);
            const lastDay = new Date(year, month + 1, 0);
            
            // 最初の週の開始日を取得（日曜日から）
            const startDate = new Date(firstDay);
            startDate.setDate(startDate.getDate() - firstDay.getDay());
            
            // 最後の週の終了日を取得（土曜日まで）
            const endDate = new Date(lastDay);
            endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));
            
            const daysContainer = document.getElementById('miniCalendarDays');
            daysContainer.innerHTML = '';
            
            // カレンダーの日付セルを生成
            const current = new Date(startDate);
            while (current <= endDate) {
                const dayDiv = document.createElement('div');
                dayDiv.className = 'mini-calendar-day';
                dayDiv.textContent = current.getDate();
                
                // 今月以外の日付
                if (current.getMonth() !== month) {
                    dayDiv.classList.add('other-month');
                }
                
                // 今日の日付
                const todayDate = new Date();
                if (current.toDateString() === todayDate.toDateString()) {
                    dayDiv.classList.add('today');
                }
                
                // クリックされた日付をハイライト
                if (clickedDate && 
                    current.getFullYear() === clickedDate.getFullYear() && 
                    current.getMonth() === clickedDate.getMonth() && 
                    current.getDate() === clickedDate.getDate()) {
                    dayDiv.classList.add('clicked-day');
                }
                
                // クリックイベント - 安全な日付オブジェクトを作成
                const clickDate = new Date(current.getFullYear(), current.getMonth(), current.getDate(), 12, 0, 0, 0);
                dayDiv.addEventListener('click', () => {
                    selectWeekFromDate(clickDate);
                });
                
                daysContainer.appendChild(dayDiv);
                current.setDate(current.getDate() + 1);
            }
        }

        function selectWeekFromDate(date) {
            console.log('🔍 Original clicked date:', date);
            console.log('🔍 Date details:', {
                year: date.getFullYear(),
                month: date.getMonth() + 1,
                date: date.getDate(),
                dayOfWeek: date.getDay(),
                toString: date.toString()
            });
            
            // 日付を安全に処理 - タイムゾーンの影響を避ける
            const safeDate = new Date(
                date.getFullYear(),
                date.getMonth(),
                date.getDate(),
                12, 0, 0, 0  // 正午に設定してタイムゾーンの問題を回避
            );
            
            console.log('📅 Safe date for calculation:', safeDate);
            
            // 指定された日付が含まれる週の開始日（日曜日）を計算
            const dayOfWeek = safeDate.getDay();
            const targetDate = safeDate.getDate() - dayOfWeek;
            
            console.log('Target date calculation:', safeDate.getDate(), '-', dayOfWeek, '=', targetDate);
            
            // 週の開始日を安全に作成
            const weekStart = new Date(
                safeDate.getFullYear(),
                safeDate.getMonth(),
                targetDate,
                12, 0, 0, 0
            );
            
            console.log('📅 Calculated week start:', weekStart);
            console.log('🔍 Week start details:', {
                year: weekStart.getFullYear(),
                month: weekStart.getMonth() + 1,
                date: weekStart.getDate()
            });
            
            // クリックされた日付を保存
            clickedDate = safeDate;
            
            // 週を更新
            currentWeekStart = weekStart;
            
            // シフト設定と予約データを読み込み、表示を更新
            Promise.all([
                loadShiftSettingsFromBackend(),
                loadReservationsFromBackend()
            ]).then(() => {
                renderWeekView();
            });
            
            // ミニカレンダーを閉じる
            document.getElementById('miniCalendar').classList.remove('show');
            
            // ミニカレンダーを再描画（選択状態を更新）
            renderMiniCalendar();
        }

        function previousMiniCalendarMonth() {
            const prevMonthDate = miniCalendarMonth;
            const prevMonth = new Date(
                prevMonthDate.getFullYear(),
                prevMonthDate.getMonth() - 1,
                15, // 月の中旬に設定
                12, 0, 0, 0
            );
            
            console.log('⬅️ Moving to previous month:', prevMonth);
            miniCalendarMonth = prevMonth;
            renderMiniCalendar();
        }

        function nextMiniCalendarMonth() {
            const nextMonthDate = miniCalendarMonth;
            const nextMonth = new Date(
                nextMonthDate.getFullYear(),
                nextMonthDate.getMonth() + 1,
                15, // 月の中旬に設定
                12, 0, 0, 0
            );
            
            console.log('➡️ Moving to next month:', nextMonth);
            miniCalendarMonth = nextMonth;
            renderMiniCalendar();
        }

        function previousMiniCalendarYear() {
            const prevYearDate = miniCalendarMonth;
            const prevYear = new Date(
                prevYearDate.getFullYear() - 1,
                prevYearDate.getMonth(),
                15, // 月の中旬に設定
                12, 0, 0, 0
            );
            
            console.log('⬅️⬅️ Moving to previous year:', prevYear);
            miniCalendarMonth = prevYear;
            renderMiniCalendar();
        }

        function nextMiniCalendarYear() {
            const nextYearDate = miniCalendarMonth;
            const nextYear = new Date(
                nextYearDate.getFullYear() + 1,
                nextYearDate.getMonth(),
                15, // 月の中旬に設定
                12, 0, 0, 0
            );
            
            console.log('➡️➡️ Moving to next year:', nextYear);
            miniCalendarMonth = nextYear;
            renderMiniCalendar();
        }

        // 予約作成モーダルを開く
        function openBookingModal(date, time) {
            console.log('🔧 Opening booking modal for date:', date, 'time:', time);
            
            // 正しいIDを参照
            const displayDateElement = document.getElementById('bookingDisplayDate');
            const displayTimeElement = document.getElementById('bookingDisplayTime');
            
            if (displayDateElement && displayTimeElement) {
                // 日付と時間の表示用フォーマット
                const displayDate = `${date.getFullYear()}年${String(date.getMonth() + 1)}月${String(date.getDate())}日`;
                const dayNames = ['日', '月', '火', '水', '木', '金', '土'];
                const dayName = dayNames[date.getDay()];
                
                displayDateElement.textContent = `${displayDate}(${dayName})`;
                displayTimeElement.textContent = time;
            }
            
            // 内部的に日付と時間を保存（後で使用する場合）
            window.selectedBookingDate = date;
            window.selectedBookingTime = time;
            
            // フォームフィールドをリセット
            document.getElementById('bookingDuration').value = '';
            document.getElementById('customerName').value = '';
            document.getElementById('customerPhone').value = '';
            document.getElementById('customerEmail').value = '';
            document.getElementById('bookingNote').value = '';
            document.getElementById('bookingStatus').value = 'tentative';
            
            const modal = document.getElementById('bookingModal');
            modal.style.display = 'block';
            
            console.log('✅ Booking modal opened - background click to close is handled by HTML onclick');
        }

        // 予約作成モーダルを閉じる
        function closeBookingModal() {
            document.getElementById('bookingModal').style.display = 'none';
            // 編集モードフラグをリセット
            isEditingReservation = false;
            currentReservation = null;
            reservationToEdit = null;
        }

        // 予約を作成・更新
        function createBooking() {
            const dateTime = document.getElementById('bookingDate').value;
            const duration = document.getElementById('bookingDuration').value;
            const customerName = document.getElementById('customerName').value;
            const customerPhone = document.getElementById('customerPhone').value;
            const customerEmail = document.getElementById('customerEmail').value;
            const bookingNote = document.getElementById('bookingNote').value;
            const bookingStatus = document.getElementById('bookingStatus').value;

            console.log('🔄 Creating/Updating booking, isEditing:', isEditingReservation);

            if (!dateTime || !duration || !customerName || !customerPhone) {
                showMessage('予約日時、コース、お客様名、電話番号は必須です。', 'error');
                return;
            }

            // 営業時間内に収まるかチェック
            const [dateStr, timeStr] = dateTime.split(' ');
            const reservationDate = new Date(dateStr);
            const dayOfWeek = reservationDate.getDay();
            const newDuration = parseInt(duration);
            const defaultInterval = 10; // 新規予約のデフォルト間隔
            
            const validation = validateReservationTimeWithinBusinessHours({
                time: timeStr,
                start_time: dateTime,
                duration: newDuration
            }, newDuration, defaultInterval);
            
            if (!validation.valid) {
                showMessage(validation.message, 'error');
                return;
            }
            
            // 重複チェック
            const overlapValidation = validateReservationOverlap({
                time: timeStr,
                start_time: dateTime,
                duration: newDuration
            }, newDuration, defaultInterval);
            
            if (!overlapValidation.valid) {
                showMessage(overlapValidation.message, 'error');
                return;
            }

            // バックエンドに送信するデータを準備
            const bookingData = {
                reservation: {
                    start_time: dateTime,
                    course: `${duration}分`,
                    name: customerName,
                    note: bookingNote,
                    status: bookingStatus,
                    user_attributes: {
                        name: customerName,
                        phone_number: customerPhone,
                        email: customerEmail
                    }
                }
            };

            // CSRFトークンを取得
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
            console.log('CSRF Token:', csrfToken);
            console.log('Sending booking data:', bookingData);

            // クライアントサイドで重複チェック
            if (!isEditingReservation && checkForOverlap(dateTime, duration)) {
                showMessage('この時間帯には既に予約があります。別の時間を選択してください。', 'error');
                return;
            }

            // バックエンドに送信（編集モードの場合は更新、新規の場合は作成）
            const url = isEditingReservation ? 
                `/admin/reservations/${reservationToEdit.id}/update_booking` : 
                '/admin/reservations/create_booking';
            const method = isEditingReservation ? 'PATCH' : 'POST';
            
            fetch(url, {
                method: method,
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    },
                body: JSON.stringify(bookingData)
  })
  .then(response => {
                console.log('Response status:', response.status);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  })
  .then(data => {
    if (data.success) {
                    // バックエンドから返された予約データを使用
                    const reservationData = data.reservation;
                    
                    if (isEditingReservation) {
                        // 編集モード：既存の予約を更新
                        const updatedReservation = {
                            id: reservationData.id,
                            userId: reservationData.user_id || reservationData.user?.id,
                            time: reservationData.start_time.split('T')[1].substring(0, 5), // HH:MM形式に変換
                            duration: extractDurationFromCourse(reservationData.course),
                            customer: reservationData.name || reservationData.user?.name || '未設定',
                            phone: reservationData.user?.phone_number || '',
                            email: reservationData.user?.email || '',
                            note: reservationData.note || '',
                            status: reservationData.status,
                            createdAt: reservationData.created_at,
                            updatedAt: reservationData.updated_at,
                            effective_interval_minutes: reservationData.effective_interval_minutes ?? 10
                        };
                        
                        // 既存の予約を更新
                        // 古い日付キーを特定（reservationsオブジェクトから該当する日付キーを探す）
                        let oldDateKey = null;
                        for (const dateKey of Object.keys(reservations)) {
                            const dayReservations = reservations[dateKey];
                            const foundReservation = dayReservations.find(r => r.id === reservationToEdit.id);
                            if (foundReservation) {
                                oldDateKey = dateKey;
                                break;
                            }
                        }
                        
                        const newDateKey = formatDateKey(new Date(reservationData.start_time));
                        
                        // 古い日付から削除
                        if (oldDateKey && reservations[oldDateKey]) {
                            reservations[oldDateKey] = reservations[oldDateKey].filter(r => r.id !== reservationToEdit.id);
                            if (reservations[oldDateKey].length === 0) {
                                delete reservations[oldDateKey];
                            }
                        }
                        
                        // 新しい日付に追加
                        if (!reservations[newDateKey]) {
                            reservations[newDateKey] = [];
                        }
                        reservations[newDateKey].push(updatedReservation);
                        
                        
                        
                        // 編集モードフラグをリセット
                        isEditingReservation = false;
                        currentReservation = null;
                        reservationToEdit = null;
                        
                        showMessage('予約が更新されました。', 'success');
                    } else {
                        // 新規作成モード：新しい予約を追加
                        const reservation = {
                            id: reservationData.id,
                            userId: reservationData.user_id || reservationData.user?.id,
                            time: reservationData.start_time.split('T')[1].substring(0, 5), // HH:MM形式に変換
                            duration: extractDurationFromCourse(reservationData.course),
                            customer: reservationData.name || reservationData.user?.name || '未設定',
                            phone: reservationData.user?.phone_number || '',
                            email: reservationData.user?.email || '',
                            note: reservationData.note || '',
                            status: reservationData.status,
                            createdAt: reservationData.created_at,
                            updatedAt: reservationData.updated_at,
                            effective_interval_minutes: reservationData.effective_interval_minutes ?? 10
                        };

                        const dateKey = formatDateKey(new Date(reservationData.start_time));
                        if (!reservations[dateKey]) {
                            reservations[dateKey] = [];
                        }
                        reservations[dateKey].push(reservation);

                        
                        
                        showMessage('予約が作成されました。', 'success');
                    }

                    // カレンダーを再描画
                    generateTimeSlots();

                    closeBookingModal();
    } else {
                    showMessage(`予約の作成に失敗しました: ${data.message}`, 'error');
    }
  })
  .catch(error => {
                console.error('Error creating booking:', error);
                showMessage('予約の作成中にエラーが発生しました。', 'error');
            });
        }

        // 予約詳細モーダルを開く
        function openReservationDetailModal(reservation) {
            // Normalize reservation before using
            reservation = normalizeReservation(reservation);
            // Add detailed logging for all date-related fields
            console.log('🕵️‍♂️ Reservation detail modal - raw reservation:', reservation);
            if (reservation) {
                console.log('🕵️‍♂️ reservation.date:', reservation.date);
                console.log('🕵️‍♂️ reservation.dateKey:', reservation.dateKey);
                console.log('🕵️‍♂️ reservation.start_time:', reservation.start_time);
                if (reservation.start_time) {
                    const parsed = new Date(reservation.start_time);
                    console.log('🕵️‍♂️ Parsed start_time:', parsed, 'Locale:', parsed.toLocaleString());
                }
            }
            // 最新の予約データを取得
            let latestReservation = null;
            let foundDateKey = null;
            for (const dateKey of Object.keys(reservations)) {
                const dayReservations = reservations[dateKey];
                const foundReservation = dayReservations.find(r => r.id === reservation.id);
                if (foundReservation) {
                    latestReservation = foundReservation;
                    foundDateKey = dateKey;
                    break;
                }
            }
            // 最新のデータが見つからない場合は元のデータを使用
            if (!latestReservation) {
                latestReservation = reservation;
            }
            // 必ずcurrentReservationを最新の予約データ（date付き）にセット
            currentReservation = latestReservation;
            // もしdateがなければdateKeyをセット
            if (!currentReservation.date && foundDateKey) {
                currentReservation.date = foundDateKey;
            }
            console.log('🔍 Opening modal with reservation data:', {
                original: {
                    time: reservation.time,
                    date: reservation.date,
                    dateKey: reservation.dateKey,
                    start_time: reservation.start_time
                },
                latest: {
                    time: latestReservation.time,
                    date: latestReservation.date,
                    dateKey: latestReservation.dateKey,
                    start_time: latestReservation.start_time
                }
            });
            
            // 予約データの妥当性チェック
            if (!validateReservationData(latestReservation)) {
                showMessage('予約データが無効です', 'error');
                return;
            }
            
            // 現在の予約を保存（最新のデータを使用）
            currentReservation = latestReservation;
            
            // 予約の実際の日付を特定
            let actualDate = '';
            for (const dateKey of Object.keys(reservations)) {
                const dayReservations = reservations[dateKey];
                const foundReservation = dayReservations.find(r => r.id === latestReservation.id);
                if (foundReservation) {
                    const [year, month, day] = dateKey.split('-').map(Number);
                    const date = new Date(year, month - 1, day);
                    actualDate = date.toLocaleDateString('ja-JP', { 
                        year: 'numeric', 
                        month: 'long', 
                        day: 'numeric',
                        weekday: 'long'
                    });
                    break;
                }
            }
            
            // ステータスに応じた色とアイコンを設定
            const statusConfig = {
                'tentative': { color: 'warning', icon: '⏳', text: '仮予約' },
                'confirmed': { color: 'success', icon: '✓', text: '確認済み' },
                'completed': { color: 'info', icon: '✅', text: '完了' }
            };
            
            const status = statusConfig[latestReservation.status] || { color: 'secondary', icon: '❓', text: latestReservation.status };
            
            // Create customer name HTML
            const customerNameHTML = latestReservation.userId ? 
                `<a href="/admin/users/${latestReservation.userId}" target="_blank" class="customer-link">${latestReservation.customer}</a>` : 
                latestReservation.customer;
            
            const modalContent = document.getElementById('reservationDetailContent');
            modalContent.innerHTML = `
                <div class="reservation-detail-container">
                    <!-- 編集フォーム -->
                    <form id="reservationEditForm" onsubmit="saveReservationChanges(event)">
                    <!-- ヘッダー情報 -->
                    <div class="reservation-header">
                        <div class="header-top">
                            <div class="customer-name-header">
                                <span class="customer-name-large">${latestReservation.customer}</span>
                                    <button type="button" class="btn btn-sm btn-outline-light change-user-btn" onclick="openUserSelectionModal()">
                                        <i class="fas fa-user-edit"></i> 変更
                                    </button>
                            </div>
                            <div class="reservation-status status-${status.color}">
                                    <select id="edit-status" class="form-select status-select" onchange="updateCalendarOnStatusChange()">
                                        <option value="tentative" ${latestReservation.status === 'tentative' ? 'selected' : ''}>仮予約</option>
                                        <option value="confirmed" ${latestReservation.status === 'confirmed' ? 'selected' : ''}>確認済み</option>
                                        <option value="completed" ${latestReservation.status === 'completed' ? 'selected' : ''}>完了</option>
                                    </select>
                            </div>
                        </div>
                        <div class="header-bottom">
                            <div class="header-detail-item">
                                <span class="header-label">予約日時</span>
                                <span class="header-value">${actualDate || '日付不明'} ${latestReservation.time}</span>
                            </div>
                            <div class="header-detail-item">
                                <span class="header-label">コース</span>
                                    <select id="edit-course" class="form-select course-select" onchange="updateCalendarOnCourseChange()">
                                        <option value="40分" ${latestReservation.duration === 40 ? 'selected' : ''}>40分</option>
                                        <option value="60分" ${latestReservation.duration === 60 ? 'selected' : ''}>60分</option>
                                        <option value="80分" ${latestReservation.duration === 80 ? 'selected' : ''}>80分</option>
                                    </select>
                                </div>
                                <div class="header-detail-item">
                                    <span class="header-label">準備時間</span>
                                    <span class="header-value">
                                        <select id="edit-interval" class="interval-select" onchange="updateIntervalOnChange()">
                                            <option value="0" ${(latestReservation.effective_interval_minutes ?? 10) === 0 ? 'selected' : ''}>0分</option>
                                            <option value="5" ${(latestReservation.effective_interval_minutes ?? 10) === 5 ? 'selected' : ''}>5分</option>
                                            <option value="10" ${(latestReservation.effective_interval_minutes ?? 10) === 10 ? 'selected' : ''}>10分</option>
                                            <option value="15" ${(latestReservation.effective_interval_minutes ?? 10) === 15 ? 'selected' : ''}>15分</option>
                                            <option value="20" ${(latestReservation.effective_interval_minutes ?? 10) === 20 ? 'selected' : ''}>20分</option>
                                            <option value="30" ${(latestReservation.effective_interval_minutes ?? 10) === 30 ? 'selected' : ''}>30分</option>
                                        </select>
                                    </span>
                            </div>
                        </div>
                    </div>
                    
                    <!-- お客様基本情報 -->
                    <div class="customer-basic-info">
                        <div class="customer-phone">
                            ${latestReservation.phone || '電話番号未記入'}
                        </div>
                        <div class="customer-email">
                            ${latestReservation.email || 'メールアドレス未記入'}
                        </div>
                    </div>
                    
                        <!-- メモ -->
                        <div class="notes-section">
                            <div class="section-title">メモ</div>
                            <textarea id="edit-note" class="form-control" rows="3" placeholder="メモを入力してください">${latestReservation.note || ''}</textarea>
                        </div>
                    </form>
                    
                    <!-- 回数券と利用履歴を横並びで表示 -->
                    <div class="tickets-history-container">
                    <!-- 回数券 -->
                    <div class="tickets-section">
                        <div class="section-title">回数券</div>
                        <div class="tickets-content" id="tickets-content">
                            <div class="loading">読み込み中...</div>
                        </div>
                    </div>
                    
                        <!-- 利用履歴 -->
                    <div class="reservation-history-section">
                            <div class="section-title">利用履歴</div>
                        <div class="history-content" id="history-content">
                            <div class="loading">読み込み中...</div>
                        </div>
                        </div>
                    </div>
                    
                    <!-- システム情報 -->
                    <div class="system-info-section">
                        <div class="detail-item">
                            <span class="detail-label">作成日時</span>
                            <span class="detail-value">${new Date(latestReservation.createdAt).toLocaleString('ja-JP')}</span>
                        </div>
                        ${latestReservation.updatedAt && new Date(latestReservation.updatedAt).getTime() !== new Date(latestReservation.createdAt).getTime() ? `
                        <div class="detail-item">
                            <span class="detail-label">変更日時</span>
                            <span class="detail-value">${new Date(latestReservation.updatedAt).toLocaleString('ja-JP')}</span>
                        </div>
                        ` : ''}
                    </div>
                </div>
            `;
            document.getElementById('reservationDetailModal').style.display = 'block';
            
            // Add click event listener to customer link
            setTimeout(() => {
                const customerLink = document.querySelector('.customer-link');
                if (customerLink) {
        
                    customerLink.addEventListener('click', function(e) {
            
                        e.preventDefault();
                        window.open(this.href, '_blank');
                    });
                } else {
                    console.log('❌ Customer link not found');
                }
            }, 100);
            
            // チケットと予約履歴を読み込み（ユーザーIDベース）
            if (latestReservation.userId) {
                loadTicketsAndHistoryForUser(latestReservation.userId);
            } else {
            loadTicketsAndHistory(latestReservation);
            }
            
            // ユーザーリストは検索時に動的に読み込み
        }

        // 予約詳細モーダルを閉じる
        function closeReservationDetailModal() {
            document.getElementById('reservationDetailModal').style.display = 'none';
            currentReservation = null; // 現在の予約をリセット
        }

        // モーダル外クリックで閉じる機能
        function setupModalClickOutside() {
            console.log('🔧 Setting up modal click outside functionality...');
            
            // 予約詳細モーダル
            const reservationDetailModal = document.getElementById('reservationDetailModal');
            if (reservationDetailModal) {
                console.log('✅ Found reservationDetailModal, setting up click outside...');
                reservationDetailModal.addEventListener('click', function(event) {
                    console.log('🎯 reservationDetailModal clicked, target:', event.target);
                    // モーダル背景（.modal）をクリックした場合のみ閉じる
                    if (event.target === reservationDetailModal) {
                        console.log('✅ Closing reservationDetailModal via click outside');
                        closeReservationDetailModal();
                    }
                });
            } else {
                console.log('❌ reservationDetailModal not found');
            }
            
            // 新規予約作成モーダル
            const bookingModal = document.getElementById('bookingModal');
            if (bookingModal) {
                console.log('✅ Found bookingModal, setting up click outside...');
                bookingModal.addEventListener('click', function(event) {
                    console.log('🎯 bookingModal clicked, target:', event.target);
                    console.log('🎯 bookingModal element:', bookingModal);
                    // モーダル背景（.booking-modal）をクリックした場合のみ閉じる
                    if (event.target === bookingModal) {
                        console.log('✅ Closing bookingModal via click outside');
                        closeBookingModal();
                    }
                });
            } else {
                console.log('❌ bookingModal not found');
            }
            
            // 休憩作成モーダル
            const breakModal = document.getElementById('breakModal');
            if (breakModal) {
                console.log('✅ Found breakModal, setting up click outside...');
                breakModal.addEventListener('click', function(event) {
                    console.log('🎯 breakModal clicked, target:', event.target);
                    // モーダル背景（.break-modal）をクリックした場合のみ閉じる
                    if (event.target === breakModal) {
                        console.log('✅ Closing breakModal via click outside');
                        closeBreakModal();
                    }
                });
            } else {
                console.log('❌ breakModal not found');
            }
            
            console.log('🔧 Modal click outside setup completed');
        }

        // チケットと利用履歴を読み込み
        function loadTicketsAndHistory(reservation) {
            // チケット情報を読み込み
            loadTickets(reservation);
            // 利用履歴を読み込み
            loadReservationHistory(reservation);
        }

        // ユーザーIDでチケットと利用履歴を読み込み
        function loadTicketsAndHistoryForUser(userId) {
            // チケット情報を読み込み
            loadTicketsForUser(userId);
            // 利用履歴を読み込み
            loadReservationHistoryForUser(userId);
        }

        // チケット情報を読み込み
        function loadTickets(reservation) {

            
            const ticketsContent = document.getElementById('tickets-content');
            if (!ticketsContent) {
                console.error('❌ Tickets content element not found');
                return;
            }

            // 予約データの妥当性チェック
            if (!validateReservationData(reservation)) {
                ticketsContent.innerHTML = '<div class="no-data">予約データが無効です</div>';
                return;
            }

            // ユーザーIDがある場合はチケット情報を取得
            if (reservation.userId) {
    
    
                
                // エラーハンドリングを追加
                fetch(`/admin/reservations/${reservation.id}/tickets`, {
                    headers: {
                        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
                    }
                })
    .then(response => {
                        console.log('📡 Response status:', response.status);
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
      return response.json();
    })
                    .then(data => {
            
                        if (data.success) {
                            displayTickets(data.tickets);
                        } else {
                            console.warn('⚠️ No tickets data:', data.message);
                            ticketsContent.innerHTML = '<div class="no-data">チケット情報がありません</div>';
                        }
    })
    .catch(error => {
                        console.error('❌ Error loading tickets:', error);
                        console.error('❌ Error details:', {
                            message: error.message,
                            stack: error.stack,
                            reservationId: reservation.id,
                            userId: reservation.userId
                        });
                        ticketsContent.innerHTML = '<div class="no-data">チケット情報の読み込みに失敗しました</div>';
                    });
            } else {
                console.warn('⚠️ No user ID found for reservation');
                ticketsContent.innerHTML = '<div class="no-data">ユーザー情報がありません</div>';
            }
        }

        // ユーザーIDでチケット情報を読み込み
        function loadTicketsForUser(userId) {
            const ticketsContent = document.getElementById('tickets-content');
            if (!ticketsContent) {
                console.error('❌ Tickets content element not found');
                return;
            }

            // ユーザーIDがある場合はチケット情報を取得
            if (userId) {
                fetch(`/admin/users/${userId}/tickets.json`)
                    .then(response => {
                        console.log('📡 User tickets response status:', response.status);
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        return response.json();
                    })
                    .then(tickets => {
                        console.log('📡 User tickets data:', tickets);
                        displayUserTickets(tickets);
                    })
                    .catch(error => {
                        console.error('❌ Error loading user tickets:', error);
                        ticketsContent.innerHTML = '<div class="no-data">チケット情報の読み込みに失敗しました</div>';
                    });
            } else {
                console.warn('⚠️ No user ID provided');
                ticketsContent.innerHTML = '<div class="no-data">ユーザー情報がありません</div>';
            }
        }

        // ユーザーチケット情報を表示
        function displayUserTickets(tickets) {
            const ticketsContent = document.getElementById('tickets-content');
            if (!ticketsContent) {
                console.error('❌ Tickets content element not found in displayUserTickets');
                return;
            }

            if (!tickets || tickets.length === 0) {
                console.log('ℹ️ No user tickets to display');
                ticketsContent.innerHTML = '<div class="no-data">チケットがありません</div>';
                return;
            }

            // Limit to 5 tickets like the original
            const limitedTickets = tickets.slice(0, 5);

            const ticketsHtml = limitedTickets.map(ticket => {
                const isExpired = ticket.remaining === 0 || new Date(ticket.expires_at) < new Date();
                const expiryDate = ticket.expires_at ? new Date(ticket.expires_at).toLocaleDateString('ja-JP') : '無期限';
                
                return `
                    <div class="ticket-item ${isExpired ? 'expired' : ''}">
                        <div class="ticket-checkbox">□</div>
                        <div class="ticket-info">
                            <div class="ticket-name">${ticket.name}</div>
                            <div class="ticket-details">残${ticket.remaining}枚 / 有効期限:${expiryDate}</div>
                        </div>
                    </div>
                `;
            }).join('');

            ticketsContent.innerHTML = ticketsHtml;
        }

        // チケット情報を表示
        function displayTickets(tickets) {

            
            const ticketsContent = document.getElementById('tickets-content');
            if (!ticketsContent) {
                console.error('❌ Tickets content element not found in displayTickets');
                return;
            }

            if (!tickets || tickets.length === 0) {
                console.log('ℹ️ No tickets to display');
                ticketsContent.innerHTML = '<div class="no-data">チケットがありません</div>';
                return;
            }


            
            const ticketsHtml = tickets.map(ticket => {
                const isExpired = ticket.remaining_count === 0 || new Date(ticket.expiry_date) < new Date();
                const expiryDate = new Date(ticket.expiry_date).toLocaleDateString('ja-JP');
                

                
                return `
                    <div class="ticket-item ${isExpired ? 'expired' : ''}">
                        <div class="ticket-checkbox">□</div>
                        <div class="ticket-info">
                            <div class="ticket-name">${ticket.ticket_template_name}</div>
                            <div class="ticket-details">残${ticket.remaining_count}${ticket.unit_type} / 有効期限:${expiryDate}</div>
          </div>
        </div>
      `;
            }).join('');


            ticketsContent.innerHTML = ticketsHtml;
        }

        // ユーザーIDで利用履歴を読み込み
        function loadReservationHistoryForUser(userId) {
            const historyContent = document.getElementById('history-content');
            if (!historyContent) return;

            // ユーザーIDがある場合は利用履歴を取得
            if (userId) {
                fetch(`/admin/users/${userId}/history.json`)
                    .then(response => {
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        return response.json();
                    })
                    .then(data => {
                        console.log('📡 User history data:', data);
                        if (data.success) {
                            displayReservationHistory(data.usages);
                        } else {
                            historyContent.innerHTML = '<div class="no-data">利用履歴がありません</div>';
                        }
                    })
                    .catch(error => {
                        console.error('❌ Error loading user history:', error);
                        historyContent.innerHTML = '<div class="no-data">利用履歴の読み込みに失敗しました</div>';
                    });
            } else {
                historyContent.innerHTML = '<div class="no-data">ユーザー情報がありません</div>';
            }
        }

        // 利用履歴を読み込み
        function loadReservationHistory(reservation) {

            
            const historyContent = document.getElementById('history-content');
            if (!historyContent) return;

            // 予約データの妥当性チェック
            if (!validateReservationData(reservation)) {
                historyContent.innerHTML = '<div class="no-data">予約データが無効です</div>';
                return;
            }

            // ユーザーIDがある場合は利用履歴を取得
            if (reservation.userId) {
                fetch(`/admin/reservations/${reservation.id}/history`, {
                    headers: {
                        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
                    }
                })
                    .then(response => {
                        if (!response.ok) {
                            throw new Error(`HTTP error! status: ${response.status}`);
                        }
                        return response.json();
                    })
                    .then(data => {
                        if (data.success) {
                            displayReservationHistory(data.usages);
                        } else {
                            historyContent.innerHTML = '<div class="no-data">利用履歴がありません</div>';
                        }
                    })
                    .catch(error => {
                        console.error('❌ Error loading usage history:', error);
                        console.error('❌ Error details:', {
                            message: error.message,
                            stack: error.stack,
                            reservationId: reservation.id,
                            userId: reservation.userId
                        });
                        historyContent.innerHTML = '<div class="no-data">利用履歴の読み込みに失敗しました</div>';
                    });
            } else {
                historyContent.innerHTML = '<div class="no-data">ユーザー情報がありません</div>';
            }
        }

        // 利用履歴を表示
        function displayReservationHistory(usages) {
            const historyContent = document.getElementById('history-content');
            if (!historyContent) return;

            if (!usages || usages.length === 0) {
                historyContent.innerHTML = '<div class="no-data">利用履歴がありません</div>';
                return;
            }

            const historyHtml = usages.map(usage => {
                // デバッグ用：利用履歴データの詳細をログ出力
                console.log('📋 Processing usage:', usage);
                
                const usageDate = new Date(usage.usage_date || usage.created_at || Date.now()).toLocaleDateString('ja-JP');
                const usageTime = new Date(usage.usage_date || usage.created_at || Date.now()).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
                const ticketName = usage.ticket_name || 'チケット名未定';
                
                return `
                    <div class="history-item">
                        <div class="history-icon">🎫</div>
                        <div class="history-content">
                            <div class="history-ticket-name">${ticketName}</div>
                            <div class="history-date-time">${usageDate} ${usageTime}</div>
                        </div>
                    </div>
                `;
            }).join('');

            historyContent.innerHTML = historyHtml;
        }



        // ステータスアイコンを取得
        function getStatusIcon(status) {
            const statusIcons = {
                'confirmed': '✅',
                'tentative': '⏳',
                'cancelled': '❌',
                'completed': '✅',
                'no_show': '⚠️'
            };
            return statusIcons[status] || '❓';
        }



        // 予約を編集
        function editReservation(reservationId, dateKey) {
          setCurrentReservationById(reservationId, dateKey);
          if (!currentReservation) {
            showMessage('編集する予約が見つかりませんでした。', 'error');
            return;
          }
          console.log('✏️ Editing reservation:', currentReservation);
          
          // 編集モードフラグを設定
          isEditingReservation = true;
          
          // 予約データを保存（モーダルを閉じる前に）
          reservationToEdit = { ...currentReservation };
          
          // 予約の実際の日付を特定（reservationsオブジェクトから該当する日付キーを探す）
          let actualReservationDate = null;
          let foundDateKey = null;
          
          // すべての日付キーをチェックして該当する予約を探す
          for (const dateKey of Object.keys(reservations)) {
              const dayReservations = reservations[dateKey];
              const foundReservation = dayReservations.find(r => r.id === currentReservation.id);
              
              if (foundReservation) {
                  foundDateKey = dateKey;
                  // 日付キーから実際の日付を計算
                  const [year, month, day] = dateKey.split('-').map(Number);
                  const [hours, minutes] = currentReservation.time.split(':').map(Number);
                  actualReservationDate = new Date(year, month - 1, day, hours, minutes, 0, 0);
                  break;
              }
          }
          
          // 見つからない場合はcreatedAtから計算（フォールバック）
          if (!actualReservationDate) {
              console.warn('⚠️ Could not find reservation in date keys, using createdAt as fallback');
              actualReservationDate = new Date(reservationToEdit.createdAt);
              const [hours, minutes] = reservationToEdit.time.split(':').map(Number);
              actualReservationDate.setHours(hours, minutes, 0, 0);
          }
          
          console.log('📅 Actual reservation date:', actualReservationDate, 'from date key:', foundDateKey);
          
          // 予約詳細モーダルを閉じる
          closeReservationDetailModal();
          
          // 予約編集モーダルを開く
          openBookingModal(actualReservationDate, reservationToEdit.time);
          
          // フォームフィールドを既存の予約データで埋める（モーダルが開いた後に実行）
          setTimeout(() => {
              const customerNameField = document.getElementById('customerName');
              const customerPhoneField = document.getElementById('customerPhone');
              const customerEmailField = document.getElementById('customerEmail');
              const bookingDurationField = document.getElementById('bookingDuration');
              const bookingNoteField = document.getElementById('bookingNote');
              const bookingStatusField = document.getElementById('bookingStatus');
              
              if (customerNameField) customerNameField.value = reservationToEdit.customer;
              if (customerPhoneField) customerPhoneField.value = reservationToEdit.phone;
              if (customerEmailField) customerEmailField.value = reservationToEdit.email;
              if (bookingDurationField) bookingDurationField.value = reservationToEdit.duration;
              if (bookingNoteField) bookingNoteField.value = reservationToEdit.note;
              if (bookingStatusField) bookingStatusField.value = reservationToEdit.status;
          }, 200);
          
          showMessage('予約を編集できます。', 'info');
        }

        // 予約を削除
        function deleteReservation() {
            if (!currentReservation) {
                showMessage('削除する予約が見つかりませんでした。', 'error');
    return;
  }
  
            const confirmed = confirm(`この予約を完全に削除しますか？\n\nお客様: ${currentReservation.customer}\n日時: ${currentReservation.time}\nコース: ${currentReservation.duration}分\n\nこの操作は取り消せません。`);
            
            if (!confirmed) {
                return;
            }
            
            console.log('🗑️ Deleting reservation:', currentReservation);
            
            // 視覚的なフィードバック: 削除アニメーションを開始
            const reservationBlocks = document.querySelectorAll('.reservation-block');
            reservationBlocks.forEach(block => {
                if (block.textContent.includes(currentReservation.customer) && 
                    block.textContent.includes(currentReservation.time)) {
                    block.classList.add('deleting');
                }
            });
            
            // バックエンドに削除リクエストを送信
            fetch('/admin/reservations/delete_reservation', {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    },
                body: JSON.stringify({
                    reservation_id: currentReservation.id
  })
  })
            .then(response => response.json())
  .then(data => {
    if (data.success) {
                    console.log('✅ Reservation deleted successfully');
                    
                    // ローカルデータから予約を削除
                    // 予約の実際の日付を特定するために、すべての日付キーをチェック
                    console.log('🗑️ Searching for reservation ID:', currentReservation.id, 'in all date keys');
                    console.log('🗑️ Available date keys:', Object.keys(reservations));
                    
                    let foundDateKey = null;
                    let foundReservation = null;
                    
                    // すべての日付キーをチェックして該当する予約を探す
                    for (const dateKey of Object.keys(reservations)) {
                        const dayReservations = reservations[dateKey];
                        const matchingReservation = dayReservations.find(r => r.id === currentReservation.id);
                        
                        if (matchingReservation) {
                            foundDateKey = dateKey;
                            foundReservation = matchingReservation;
                            console.log(`🗑️ Found reservation in date key: ${dateKey}`);
                            break;
                        }
                    }
                    
                    if (foundDateKey && foundReservation) {
                        const beforeCount = reservations[foundDateKey].length;
                        reservations[foundDateKey] = reservations[foundDateKey].filter(r => r.id !== currentReservation.id);
                        const afterCount = reservations[foundDateKey].length;
                        
                        console.log(`🗑️ Removed reservation: ${beforeCount} → ${afterCount} reservations for ${foundDateKey}`);
                        
                        if (reservations[foundDateKey].length === 0) {
                            delete reservations[foundDateKey];
                            console.log(`🗑️ Deleted empty date key: ${foundDateKey}`);
                        }
  } else {
                        console.warn(`⚠️ Reservation ID ${currentReservation.id} not found in any date key`);
                        console.warn(`⚠️ Available reservations:`, reservations);
                    }
                    
                    // カレンダーを再描画
                    generateTimeSlots();
      
      // モーダルを閉じる
                    closeReservationDetailModal();
                    
                    // 成功メッセージを表示
                    showMessage('予約が削除されました。', 'success');
                    
                    // デバッグ: 削除後の予約データを確認
                    console.log('✅ After deletion - reservations data:', reservations);
    } else {
                    console.error('❌ Failed to delete reservation:', data.message);
                    showMessage(`予約の削除に失敗しました: ${data.message}`, 'error');
    }
  })
  .catch(error => {
                console.error('❌ Error deleting reservation:', error);
                showMessage('予約の削除中にエラーが発生しました。', 'error');
            });
        }

        // 予約をキャンセル（削除）
        function cancelReservation() {
            if (!currentReservation) {
                showMessage('キャンセルする予約が見つかりませんでした。', 'error');
                return;
            }
            
            const confirmed = confirm(`この予約を完全に削除しますか？\n\nお客様: ${currentReservation.customer}\n日時: ${currentReservation.time}\nコース: ${currentReservation.duration}分\n\nこの操作は取り消せません。`);
            
            if (!confirmed) {
    return;
  }
  

            
            // バックエンドに削除リクエストを送信
            fetch('/admin/reservations/delete_reservation', {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
                },
                body: JSON.stringify({ reservation_id: currentReservation.id })
            })
            .then(response => response.json())
  .then(data => {
    if (data.success) {

                    

                    
                    // キャンセル表示エリアに追加（削除前に予約データと日付を保存）
                    const reservationToCancel = { ...currentReservation };
                    
                    // 予約の実際の日付を特定（dateKeyから抽出）- 削除前に実行
                    let actualReservationDate = null;
                    let foundDateKey = null;
                    
                    // すべての日付キーをチェックして該当する予約を探す
                    for (const dateKey of Object.keys(reservations)) {
                        const dayReservations = reservations[dateKey];
                        const foundReservation = dayReservations.find(r => r.id === reservationToCancel.id);
                        
                        if (foundReservation) {
                            foundDateKey = dateKey;
                            const [year, month, day] = dateKey.split('-').map(Number);
                            actualReservationDate = new Date(year, month - 1, day);
                            break;
                        }
                    }
                    
                    // 見つからない場合はcreatedAtから計算
                    if (!actualReservationDate) {
                        actualReservationDate = new Date(reservationToCancel.createdAt);
                    }
                    
                    // ローカルデータから予約を削除
                    if (foundDateKey) {
                        const beforeCount = reservations[foundDateKey].length;
                        reservations[foundDateKey] = reservations[foundDateKey].filter(r => r.id !== reservationToCancel.id);
                        const afterCount = reservations[foundDateKey].length;
                        
                        if (reservations[foundDateKey].length === 0) {
                            delete reservations[foundDateKey];
                        }
                    }
                    
                    addToCancellationDisplay({
                        ...reservationToCancel,
                        start_time: actualReservationDate.toISOString()
                    });
                    
                    // カレンダーを再描画
                    generateTimeSlots();
                    
                    // キャンセル表示を更新（DOM操作後に確実に更新）
                    setTimeout(() => {
                        updateCancellationDisplay();
                    }, 50);
                    
                    // モーダルを閉じる
                    closeReservationDetailModal();
                    
                    showMessage('予約がキャンセル（削除）されました。', 'success');
                } else {
                    console.error('❌ Failed to cancel reservation:', data.message);
                    showMessage(`予約のキャンセルに失敗しました: ${data.message}`, 'error');
    }
  })
  .catch(error => {
                console.error('❌ Error cancelling reservation:', error);
                showMessage('予約のキャンセル中にエラーが発生しました。', 'error');
            });
        }

        // コースから時間を抽出する関数
        function extractDurationFromCourse(courseString) {
            if (!courseString) return 60;
            
            const match = courseString.match(/(\d+)分/);
            return match ? parseInt(match[1]) : 60;
        }

        // 重複チェック関数
        function checkForOverlap(dateTime, duration) {
            const startTime = new Date(dateTime);
            const endTime = new Date(startTime.getTime() + parseInt(duration) * 60 * 1000);
            const dateKey = formatDateKey(startTime);
            
            // 指定日の予約を取得
            const dayReservations = reservations[dateKey] || [];
            
            // 重複チェック（インターバル時間も含む）
            for (const reservation of dayReservations) {
                const reservationStart = new Date(`${dateKey}T${reservation.time}`);
                const reservationEnd = new Date(reservationStart.getTime() + reservation.duration * 60 * 1000);
                
                // インターバル時間を取得（effective_interval_minutesを使用）
                const intervalMinutes = reservation.effective_interval_minutes ?? 10;
                const reservationEndWithInterval = new Date(reservationEnd.getTime() + intervalMinutes * 60 * 1000);
                
                // 現在の予約のインターバル時間（デフォルト10分）
                const currentIntervalMinutes = 10; // デフォルト10分
                const currentEndWithInterval = new Date(endTime.getTime() + currentIntervalMinutes * 60 * 1000);
                
                // 重複判定（インターバル時間も含む）
                if (startTime < reservationEndWithInterval && currentEndWithInterval > reservationStart) {
                    return true; // 重複あり
                }
            }
            
            return false; // 重複なし
        }

        // 予約可能時間をハイライトする関数
        function highlightAvailableSlots() {
            const dateTime = document.getElementById('bookingDate')?.value;
            const duration = document.getElementById('bookingDuration')?.value;
            
            if (!dateTime || !duration) return;
            
            const startTime = new Date(dateTime);
            const endTime = new Date(startTime.getTime() + parseInt(duration) * 60 * 1000);
            const dateKey = formatDateKey(startTime);
            
            // 既存のハイライトをクリア
            document.querySelectorAll('.time-slot').forEach(slot => {
                slot.classList.remove('overlap-warning', 'available-slot');
            });
            
            // 指定日の予約を取得
            const dayReservations = reservations[dateKey] || [];
            
            // 各時間スロットをチェック
            document.querySelectorAll('.time-slot').forEach(slot => {
                const slotTime = slot.getAttribute('data-time');
                if (!slotTime) return;
                
                const slotStart = new Date(`${dateKey}T${slotTime}`);
                const slotEnd = new Date(slotStart.getTime() + parseInt(duration) * 60 * 1000);
                
                // 重複チェック（インターバル時間も含む）
                let hasOverlap = false;
                for (const reservation of dayReservations) {
                    const reservationStart = new Date(`${dateKey}T${reservation.time}`);
                    const reservationEnd = new Date(reservationStart.getTime() + reservation.duration * 60 * 1000);
                    
                    // インターバル時間を取得（effective_interval_minutesを使用）
                    const intervalMinutes = reservation.effective_interval_minutes ?? 10;
                    const reservationEndWithInterval = new Date(reservationEnd.getTime() + intervalMinutes * 60 * 1000);
                    
                    // 現在のスロットのインターバル時間（デフォルト10分）
                    const currentIntervalMinutes = 10; // デフォルト10分
                    const slotEndWithInterval = new Date(slotEnd.getTime() + currentIntervalMinutes * 60 * 1000);
                    
                    if (slotStart < reservationEndWithInterval && slotEndWithInterval > reservationStart) {
                        hasOverlap = true;
                        break;
                    }
                }
                
                if (hasOverlap) {
                    slot.classList.add('overlap-warning');
                } else {
                    slot.classList.add('available-slot');
                }
            });
        }

        // ドラッグ&ドロップ機能
        let isDragging = false;
        let draggedReservationData = null;

        function handleDragStart(e) {
            console.log('🎯 handleDragStart called for target:', e.target);
            isDragging = true;
            
            // The target should be the reservation block itself
            const reservationBlock = e.target;
            
            if (!reservationBlock || !reservationBlock.classList.contains('reservation-block')) {
                console.error('❌ Target is not a reservation block');
                return;
            }
            
            const reservationId = reservationBlock.dataset.reservationId;
            
            if (!reservationId) {
                console.error('❌ Reservation ID not found');
                return;
            }
            
            console.log('🎯 Drag started for reservation:', reservationId, 'from block:', reservationBlock);
            
            // Store the original reservation data for better debugging
            const reservationData = JSON.parse(reservationBlock.dataset.reservationData);
            draggedReservationData = reservationData; // Store globally
            
            console.log('🎯 Original reservation data:', {
                id: reservationData.id,
                customer: reservationData.customer,
                time: reservationData.time,
                date: reservationBlock.dataset.originalDateKey
            });
            
            e.dataTransfer.setData('text/plain', reservationId);
            reservationBlock.classList.add('dragging');
            e.dataTransfer.effectAllowed = 'move';
            
            // Use the original block as the drag image so it follows the cursor
            e.dataTransfer.setDragImage(reservationBlock, 50, 25);
            
            // Prevent other drag events from firing
            e.stopPropagation();
        }

        function handleDragEnd(e) {
            // The target should be the reservation block itself
            const reservationBlock = e.target;
            
            if (reservationBlock && reservationBlock.classList.contains('reservation-block')) {
                reservationBlock.classList.remove('dragging');
            }
            
            document.querySelectorAll('.schedule-cell').forEach(cell => {
                cell.classList.remove('drag-over');
                cell.classList.remove('drag-over-invalid');
            });
            
                            // 少し遅延してからフラグをリセット（誤クリックを防ぐ）
                setTimeout(() => {
                    isDragging = false;
                    draggedReservationData = null; // Clear global data
                }, 100);
        }

        function handleDragOver(e) {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            
            const cell = e.target.closest('.schedule-cell');
            if (cell) {
                // Clear all previous drag-over states
                document.querySelectorAll('.schedule-cell').forEach(c => {
                    c.classList.remove('drag-over');
                    c.classList.remove('drag-over-invalid');
                });
                
                // Get the reservation data from global variable
                if (draggedReservationData) {
                    const reservationData = draggedReservationData;
                    const duration = reservationData.duration || 60;
                    const interval = reservationData.effective_interval_minutes ?? 10;
                    const totalDuration = duration + interval;
                    
                    // Calculate how many cells this reservation would occupy (10-minute slots)
                    const cellsToOccupy = Math.ceil(totalDuration / 10);
                    
                    // Check if all required cells are within business hours
                    let currentCell = cell;
                    let allCellsValid = true;
                    let cellsToCheck = [];
                    
                    // First, collect all cells that would be occupied
                    for (let i = 0; i < cellsToOccupy && currentCell; i++) {
                        cellsToCheck.push(currentCell);
                        
                        // Move to the next row (next time slot) in the same day column
                        const currentRow = currentCell.parentElement;
                        const nextRow = currentRow.nextElementSibling;
                        if (nextRow) {
                            const nextCell = nextRow.querySelector(`[data-day="${currentCell.dataset.day}"]`);
                            if (nextCell && nextCell.classList.contains('schedule-cell')) {
                                currentCell = nextCell;
                            } else {
                                break; // No more cells in this day column
                            }
                        } else {
                            break; // No more rows
                        }
                    }
                    
                    // Check if all cells are within business hours
                    for (let checkCell of cellsToCheck) {
                        const dayOfWeek = parseInt(checkCell.dataset.day);
                        const timeStr = checkCell.dataset.time;
                        
                        if (!isBusinessHour(dayOfWeek, timeStr)) {
                            allCellsValid = false;
                            break;
                        }
                    }
                    
                    // Only highlight if all cells are valid
                    if (allCellsValid) {
                        for (let checkCell of cellsToCheck) {
                            checkCell.classList.add('drag-over');
                        }
                    } else {
                        // Show invalid drop effect and visual feedback
                        e.dataTransfer.dropEffect = 'none';
                        for (let checkCell of cellsToCheck) {
                            checkCell.classList.add('drag-over-invalid');
                        }
                    }
                } else {
                    // If no dragged data, check if current cell is within business hours
                    const dayOfWeek = parseInt(cell.dataset.day);
                    const timeStr = cell.dataset.time;
                    
                    if (isBusinessHour(dayOfWeek, timeStr)) {
                        cell.classList.add('drag-over');
                    } else {
                        e.dataTransfer.dropEffect = 'none';
                    }
                }
            }
        }

        function handleDragEnter(e) {
            e.preventDefault();
            if (e.target.classList.contains('schedule-cell')) {
                e.target.classList.add('drag-over');
            }
        }

        function handleDragLeave(e) {
            if (e.target.classList.contains('schedule-cell')) {
                e.target.classList.remove('drag-over');
            }
        }

        function handleDrop(e) {
            e.preventDefault();
            e.stopPropagation();
            
            // ドラッグオーバー状態をクリア
            document.querySelectorAll('.schedule-cell').forEach(cell => {
                cell.classList.remove('drag-over');
                cell.classList.remove('drag-over-invalid');
            });
            
            const cell = e.target.closest('.schedule-cell');
            if (!cell) return;
            
            const reservationId = e.dataTransfer.getData('text/plain');
            console.log('🎯 Drop detected for reservation:', reservationId, 'at cell:', cell.dataset.day, cell.dataset.time);
            
            if (!reservationId || reservationId.trim() === '') {
                console.log('❌ Empty reservation ID, ignoring drop');
                return;
            }
            
            const reservationBlock = document.querySelector(`[data-reservation-id="${reservationId}"]`);
            
            if (!reservationBlock) {
                console.log('❌ Reservation block not found for ID:', reservationId);
                return;
            }
            
            const reservationData = JSON.parse(reservationBlock.dataset.reservationData);
            const newDay = parseInt(cell.dataset.day);
            const newTime = cell.dataset.time;
            
            // Check if the target time slot is within business hours
            if (!isBusinessHour(newDay, newTime)) {
                showMessage('営業時間外のため、この時間に予約を移動できません。', 'error');
                return;
            }
            
            // Check if all required time slots for the reservation are within business hours
            const duration = reservationData.duration || 60;
            const interval = reservationData.effective_interval_minutes ?? 10;
            const totalDuration = duration + interval;
            const cellsToOccupy = Math.ceil(totalDuration / 10);
            
            let currentCell = cell;
            let allSlotsValid = true;
            
            for (let i = 0; i < cellsToOccupy && currentCell; i++) {
                const dayOfWeek = parseInt(currentCell.dataset.day);
                const timeStr = currentCell.dataset.time;
                
                if (!isBusinessHour(dayOfWeek, timeStr)) {
                    allSlotsValid = false;
                    break;
                }
                
                // Move to the next row (next time slot) in the same day column
                const currentRow = currentCell.parentElement;
                const nextRow = currentRow.nextElementSibling;
                if (nextRow) {
                    const nextCell = nextRow.querySelector(`[data-day="${currentCell.dataset.day}"]`);
                    if (nextCell && nextCell.classList.contains('schedule-cell')) {
                        currentCell = nextCell;
                    } else {
                        break; // No more cells in this day column
                    }
                } else {
                    break; // No more rows
                }
            }
            
            if (!allSlotsValid) {
                showMessage('予約時間が営業時間外に及ぶため、この位置に移動できません。', 'error');
                return;
            }
            
            // 新しい日付を計算
            const newDate = new Date(currentWeekStart);
            newDate.setDate(newDate.getDate() + newDay);
            const newDateKey = formatDateKey(newDate);
            
            // 重複チェック
            console.log('🔍 Checking for overlap:', {
                reservationId: reservationData.id,
                from: `${reservationBlock.dataset.originalDateKey} ${reservationBlock.dataset.originalTimeStr}`,
                to: `${newDateKey} ${newTime}`,
                duration: reservationData.duration,
                interval: reservationData.effective_interval_minutes ?? 10
            });
            
            // 同じ場所にドロップした場合は何もしない
            if (reservationBlock.dataset.originalDateKey === newDateKey && 
                reservationBlock.dataset.originalTimeStr === newTime) {
                console.log('⏭️ Dropped in same location, ignoring');
                return;
            }
            
            if (checkForOverlapOnDrop(newDateKey, newTime, reservationData)) {
                showMessage('この時間帯には既に予約があります。別の時間を選択してください。', 'error');
                return;
            }
            
            console.log('✅ Proceeding with reservation update');
            
            // Prevent multiple updates for the same reservation
            if (reservationBlock.dataset.updating === 'true') {
                console.log('⏭️ Reservation already being updated, skipping');
                return;
            }
            
            reservationBlock.dataset.updating = 'true';
            updateReservationTime(reservationData.id, newDateKey, newTime);
        }

        // ドロップ時の重複チェック
        function checkForOverlapOnDrop(dateKey, timeStr, reservationData) {
            const startTime = new Date(`${dateKey}T${timeStr}`);
            const endTime = new Date(startTime.getTime() + reservationData.duration * 60 * 1000);
            
            // 指定日の予約を取得（自分以外）
            const dayReservations = reservations[dateKey] || [];
            
            console.log('🔍 Checking overlaps for:', {
                dateKey: dateKey,
                timeStr: timeStr,
                reservationId: reservationData.id,
                duration: reservationData.duration,
                dayReservations: dayReservations.length
            });
            
            // 重複チェック（インターバル時間も含む）
            for (const reservation of dayReservations) {
                if (reservation.id === reservationData.id) {
                    console.log('⏭️ Skipping self:', reservation.id);
                    continue; // 自分は除外
                }
                
                const reservationStart = new Date(`${dateKey}T${reservation.time}`);
                const reservationEnd = new Date(reservationStart.getTime() + reservation.duration * 60 * 1000);
                
                // インターバル時間を取得（effective_interval_minutesを使用）
                const intervalMinutes = reservation.effective_interval_minutes ?? 10;
                const reservationEndWithInterval = new Date(reservationEnd.getTime() + intervalMinutes * 60 * 1000);
                
                // 現在の予約のインターバル時間
                const currentIntervalMinutes = reservationData.effective_interval_minutes ?? 10;
                const currentEndWithInterval = new Date(endTime.getTime() + currentIntervalMinutes * 60 * 1000);
                
                console.log('🔍 Comparing with reservation:', {
                    existingId: reservation.id,
                    existingTime: `${reservation.time} - ${new Date(reservationEndWithInterval).toTimeString().slice(0, 5)}`,
                    newTime: `${timeStr} - ${new Date(currentEndWithInterval).toTimeString().slice(0, 5)}`,
                    existingInterval: intervalMinutes,
                    newInterval: currentIntervalMinutes
                });
                
                // 重複判定（インターバル時間も含む）
                if (startTime < reservationEndWithInterval && currentEndWithInterval > reservationStart) {
                    console.log('🚫 Overlap detected:', {
                        newReservation: `${timeStr} - ${new Date(currentEndWithInterval).toTimeString().slice(0, 5)}`,
                        existingReservation: `${reservation.time} - ${new Date(reservationEndWithInterval).toTimeString().slice(0, 5)}`,
                        date: dateKey
                    });
                    return true; // 重複あり
                }
            }
            
            console.log('✅ No overlaps detected');
            return false; // 重複なし
        }

        // 予約時間を更新する関数
        function updateReservationTime(reservationId, newDateKey, newTime) {
            // 元の予約データを取得
            const originalDateKey = document.querySelector(`[data-reservation-id="${reservationId}"]`)?.dataset.originalDateKey;
            const originalTimeStr = document.querySelector(`[data-reservation-id="${reservationId}"]`)?.dataset.originalTimeStr;
            
            if (!originalDateKey || !originalTimeStr) {
                showMessage('予約データの取得に失敗しました。', 'error');
                return;
            }
            
            // 新しい開始時間をISO形式で作成
            const newStartTime = `${newDateKey}T${newTime}`;
            
            // バックエンドに更新リクエストを送信
            const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
            
            // 予約データを取得してコース情報も含める
            const reservationBlock = document.querySelector(`[data-reservation-id="${reservationId}"]`);
            const reservationData = reservationBlock ? JSON.parse(reservationBlock.dataset.reservationData) : null;
            
            fetch(`/admin/reservations/${reservationId}/update_booking`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrfToken
                },
                body: JSON.stringify({
                    reservation: {
                        start_time: newStartTime,
                        course: reservationData ? `${reservationData.duration}分` : undefined
                    }
                })
            })
            .then(response => {
                if (!response.ok) {
                    return response.json().then(errorData => {
                        throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.message || 'Unknown error'}`);
                    }).catch(() => {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    });
                }
                return response.json();
            })
            .then(data => {
                if (data.success) {
                    // ローカルデータを更新
                    updateLocalReservationData(reservationId, newDateKey, newTime);
                    
                    // updatedAtフィールドを更新
                    if (data.reservation && data.reservation.updated_at) {
                        // グローバルreservationsオブジェクトのupdatedAtを更新
                        const reservationIndex = reservations[newDateKey].findIndex(r => r.id === parseInt(reservationId));
                        if (reservationIndex !== -1) {
                            reservations[newDateKey][reservationIndex].updatedAt = data.reservation.updated_at;
                        }
                        
                        // 現在開いているモーダルの変更日時を即座に更新
                        if (currentReservation && currentReservation.id === parseInt(reservationId)) {
                            console.log('🔄 Updating currentReservation after drag-and-drop:', {
                                before: {
                                    time: currentReservation.time,
                                    date: currentReservation.date,
                                    dateKey: currentReservation.dateKey,
                                    start_time: currentReservation.start_time
                                }
                            });
                            
                            currentReservation.updatedAt = data.reservation.updated_at;
                            // 日付と時間も更新
                            currentReservation.time = newTime;
                            currentReservation.date = newDateKey;
                            currentReservation.dateKey = newDateKey;
                            // start_timeも更新
                            const [hours, minutes] = newTime.split(':');
                            const newStartTime = new Date(`${newDateKey}T${hours}:${minutes}:00+09:00`);
                            currentReservation.start_time = newStartTime.toISOString();
                            
                            console.log('🔄 Updated currentReservation after drag-and-drop:', {
                                after: {
                                    time: currentReservation.time,
                                    date: currentReservation.date,
                                    dateKey: currentReservation.dateKey,
                                    start_time: currentReservation.start_time
                                }
                            });
                            
                            updateModalUpdatedAt(data.reservation.updated_at);
                        } else {
                            console.log('❌ currentReservation not found or ID mismatch:', {
                                currentReservation: currentReservation ? currentReservation.id : 'null',
                                reservationId: reservationId
                            });
                            
                            // モーダルが開いている場合は、最新のデータでcurrentReservationを更新
                            const modal = document.getElementById('reservationDetailModal');
                            console.log('🔍 Modal display status:', modal ? modal.style.display : 'modal not found');
                            
                            if (modal && modal.style.display === 'block') {
                                console.log('🔍 Modal is open, updating currentReservation...');
                                // 最新の予約データを取得してcurrentReservationを更新
                                for (const dateKey of Object.keys(reservations)) {
                                    const dayReservations = reservations[dateKey];
                                    const foundReservation = dayReservations.find(r => r.id === parseInt(reservationId));
                                    if (foundReservation) {
                                        currentReservation = foundReservation;
                                        console.log('🔄 Updated currentReservation from reservations data:', {
                                            time: currentReservation.time,
                                            date: currentReservation.date,
                                            dateKey: currentReservation.dateKey,
                                            start_time: currentReservation.start_time
                                        });
                                        break;
                                    }
                                }
                            } else {
                                console.log('🔍 Modal is not open, skipping currentReservation update');
                            }
                        }
                    }
                    
                    // カレンダーを再描画
                    console.log('🔄 Regenerating calendar after reservation move');
                    generateTimeSlots();
                    
                    showMessage('予約時間が更新されました。', 'success');
                } else {
                    showMessage(`予約の更新に失敗しました: ${data.message}`, 'error');
                }
                
                // Reset updating flag
                const reservationBlock = document.querySelector(`[data-reservation-id="${reservationId}"]`);
                if (reservationBlock) {
                    reservationBlock.dataset.updating = 'false';
                }
            })
            .catch(error => {
                console.error('Error updating reservation:', error);
                showMessage('予約の更新中にエラーが発生しました。', 'error');
                
                // Reset updating flag on error
                const reservationBlock = document.querySelector(`[data-reservation-id="${reservationId}"]`);
                if (reservationBlock) {
                    reservationBlock.dataset.updating = 'false';
                }
            });
        }

        // ローカル予約データを更新
        function updateLocalReservationData(reservationId, newDateKey, newTime) {
            console.log('🔄 Updating local reservation data:', {
                reservationId: reservationId,
                newDateKey: newDateKey,
                newTime: newTime
            });
            
            // 元の予約データを取得
            let originalReservationData = null;
            let originalDateKey = null;
            
            // 元の予約を見つけて削除
            for (const dateKey of Object.keys(reservations)) {
                const reservationIndex = reservations[dateKey].findIndex(r => r.id === parseInt(reservationId));
                if (reservationIndex !== -1) {
                    originalReservationData = { ...reservations[dateKey][reservationIndex] };
                    originalDateKey = dateKey;
                    reservations[dateKey].splice(reservationIndex, 1);
                    
                    // 空の配列の場合は日付キーを削除
                    if (reservations[dateKey].length === 0) {
                        delete reservations[dateKey];
                    }
                    break;
                }
            }
            
            if (!originalReservationData) {
                console.error('❌ Original reservation data not found for ID:', reservationId);
                return;
            }
            
            // 新しい場所に予約を追加
            if (!reservations[newDateKey]) {
                reservations[newDateKey] = [];
            }
            
            // 予約データを更新
            const updatedReservationData = {
                ...originalReservationData,
                time: newTime,
                date: newDateKey,
                dateKey: newDateKey,
                // start_timeも更新
                start_time: new Date(`${newDateKey}T${newTime}:00+09:00`).toISOString()
            };
            
            reservations[newDateKey].push(updatedReservationData);
            
            // DOM要素のデータ属性も更新
            const reservationBlock = document.querySelector(`[data-reservation-id="${reservationId}"]`);
            if (reservationBlock) {
                reservationBlock.dataset.originalDateKey = newDateKey;
                reservationBlock.dataset.originalTimeStr = newTime;
                reservationBlock.dataset.reservationData = JSON.stringify(updatedReservationData);
            }
            
            console.log('✅ Local reservation data updated:', {
                from: originalDateKey,
                to: newDateKey,
                reservationId: reservationId
            });
        }

        // 予約データの妥当性をチェックする関数
        function validateReservationData(reservation) {
            if (!reservation) {
                console.error('❌ Reservation is null or undefined');
                return false;
            }
            
            if (!reservation.id || reservation.id === 'null' || reservation.id === null) {
                console.error('❌ Invalid reservation ID:', reservation.id);
                return false;
            }
            
            if (!reservation.userId || reservation.userId === 'null' || reservation.userId === null) {
                console.warn('⚠️ No user ID for reservation:', reservation.id);
                // Don't return false - allow modal to open without userId
            }
            

            
            return true;
        }

                // ユーザー検索機能
        function setupUserSearch() {
            const customerNameInput = document.getElementById('customerName');
            const searchResults = document.getElementById('userSearchResults');
            
            if (!customerNameInput || !searchResults) return;
            
            // 入力イベント
            customerNameInput.addEventListener('input', function() {
                const query = this.value.trim();
                
                // デバウンス処理
                if (searchTimeout) {
                    clearTimeout(searchTimeout);
                }
                
                if (query.length < 2) {
                    hideUserSearchResults();
                    return;
                }
                
                searchTimeout = setTimeout(() => {
                    searchUsers(query);
                }, 300);
            });
            
            // フォーカスアウト時に結果を隠す
            customerNameInput.addEventListener('blur', function() {
                setTimeout(() => {
                    hideUserSearchResults();
                }, 200);
            });
            
            // フォーカス時に結果を表示（入力がある場合）
            customerNameInput.addEventListener('focus', function() {
                const query = this.value.trim();
                if (query.length >= 2) {
                    searchUsers(query);
                }
            });
        }
        
        function searchUsers(query) {

            
            fetch(`/admin/reservations/search_users?query=${encodeURIComponent(query)}`)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        displayUserSearchResults(data.users);
    } else {
                        console.error('❌ User search failed:', data.message);
                        hideUserSearchResults();
    }
  })
  .catch(error => {
                    console.error('❌ Error searching users:', error);
                    hideUserSearchResults();
                });
        }
        
        function displayUserSearchResults(users) {
            const searchResults = document.getElementById('userSearchResults');
            if (!searchResults) return;
            
            if (users.length === 0) {
                searchResults.innerHTML = '<div class="user-search-item">該当するユーザーが見つかりません</div>';
                searchResults.style.display = 'block';
                return;
            }
            
            const resultsHtml = users.map(user => `
                <div class="user-search-item" onclick="selectUser(${user.id}, '${user.name}', '${user.phone_number}', '${user.email}')">
                    <div class="user-name">${user.name}</div>
                    <div class="user-details">
                        📞 ${user.phone_number || '未設定'} | 📧 ${user.email || '未設定'}
                        ${user.active_tickets > 0 ? `<span class="user-tickets"> | 🎫 残${user.active_tickets}枚</span>` : ''}
                        ${user.last_visit !== 'なし' ? ` | 📅 最終来店: ${user.last_visit}` : ''}
                    </div>
                </div>
            `).join('');
            
            searchResults.innerHTML = resultsHtml;
            searchResults.style.display = 'block';
        }
        
        function selectUser(userId, name, phone, email) {

            
            // フォームフィールドを更新
            document.getElementById('customerName').value = name;
            document.getElementById('customerPhone').value = phone;
            document.getElementById('customerEmail').value = email;
            
            // 検索結果を隠す
            hideUserSearchResults();
            
            // 成功メッセージ
            showMessage(`既存ユーザー「${name}」を選択しました`, 'success');
        }
        
        function hideUserSearchResults() {
            console.log('🔍 hideUserSearchResults called');
            const searchResults = document.getElementById('userSelectionSearchResults');
            if (searchResults) {
                searchResults.style.display = 'none';
                searchResults.innerHTML = ''; // Also clear the content
                console.log('🔍 Search results hidden and cleared');
            } else {
                console.log('🔍 Search results element not found for hiding');
            }
        }

        // キャンセル表示エリアに予約を追加
        function addToCancellationDisplay(reservation) {
            if (!reservation) {
                console.error('❌ Reservation is null or undefined');
                return;
            }
            
            // 予約の実際の日付を特定
            let actualReservationDate = null;
            
            // start_timeが利用可能な場合はそれを使用（最優先）
            if (reservation.start_time) {
                actualReservationDate = new Date(reservation.start_time);
            } else {
                // reservationsオブジェクトから検索
                for (const dateKey of Object.keys(reservations)) {
                    const dayReservations = reservations[dateKey];
                    const foundReservation = dayReservations.find(r => r.id === reservation.id);
                    if (foundReservation) {
                        const [year, month, day] = dateKey.split('-').map(Number);
                        actualReservationDate = new Date(year, month - 1, day);
                        break;
                    }
                }
                
                // 見つからない場合はcreatedAtから計算
                if (!actualReservationDate) {
                    actualReservationDate = new Date(reservation.createdAt);
                }
            }
            
            const cancellationData = {
                id: reservation.id,
                customer: reservation.customer,
                time: reservation.time,
                duration: reservation.duration,
                date: actualReservationDate.toLocaleDateString('ja-JP'),
                cancelledAt: new Date().toLocaleString('ja-JP')
            };
            
            cancelledReservations.unshift(cancellationData); // 最新を先頭に追加
  
  // ローカルストレージに保存
            saveCancelledReservations();
            

            
            // 即座に更新を試行（次のフレームで実行）
            requestAnimationFrame(() => {
                updateCancellationDisplayImmediately();
            });
        }

        // キャンセル表示エリアを更新（即座に実行）
        // 現在の週のキャンセル履歴をフィルタリング
        function getCurrentWeekCancellations() {
            const weekStart = new Date(currentWeekStart);
            const weekEnd = new Date(currentWeekStart);
            weekEnd.setDate(weekEnd.getDate() + 6);
            
            return cancelledReservations.filter(reservation => {
                const reservationDate = new Date(reservation.date);
                return reservationDate >= weekStart && reservationDate <= weekEnd;
            });
        }

        function updateCancellationDisplayImmediately() {
            const btn = document.getElementById('showCancellationsBtn');
            const countSpan = document.getElementById('cancellation-count');
            const display = document.getElementById('cancellation-display');
            const list = document.getElementById('cancellation-list');
            
            // 現在の週のキャンセル履歴を取得
            const currentWeekCancellations = getCurrentWeekCancellations();
            
            console.log('🔄 Attempting to update cancellation display, total count:', cancelledReservations.length, 'current week:', currentWeekCancellations.length);
            console.log('🔍 Elements found:', { btn: !!btn, countSpan: !!countSpan, display: !!display, list: !!list });
            
            // ボタンが存在する場合は即座に更新（spanがなくてもボタンテキストを直接更新）
            if (btn) {
                console.log('🔄 Updating cancellation display immediately, current week count:', currentWeekCancellations.length);
                
                // ボタンの状態を更新（spanがなくても直接テキストを更新）
                if (currentWeekCancellations.length === 0) {
                    btn.disabled = false;
                    btn.textContent = `❌ キャンセル履歴 (0)`;
                    if (display) {
                        display.style.display = 'none';
                    }
                    console.log('✅ Updated cancellation display for 0 cancellations in current week');
    } else {
                    btn.disabled = false;
                    btn.textContent = `❌ キャンセル履歴 (${currentWeekCancellations.length})`;
                    console.log('✅ Updated cancellation display for', currentWeekCancellations.length, 'cancellations in current week');
                }
                
                // spanが存在する場合はそれも更新
                if (countSpan) {
                    countSpan.textContent = currentWeekCancellations.length;
                }
                
                // リストを更新（表示されている場合のみ）
                if (display && display.style.display === 'block' && list) {
                    const listHtml = currentWeekCancellations.map(reservation => `
                        <div class="cancellation-item">
                            <div class="cancellation-info">
                                <div class="cancellation-customer">${reservation.customer}</div>
                                <div class="cancellation-details">
                                    📅 ${reservation.date} <span class="cancellation-time">${reservation.time}</span> | 
                                    ⏱️ ${reservation.duration}分 | 
                                    🗑️ ${reservation.cancelledAt}
                                </div>
                            </div>
                        </div>
                    `).join('');
                    
                    list.innerHTML = listHtml;
                }
            } else {
                if (!domReady) {
                    console.log('⚠️ DOM not ready yet, will update when ready');
                    // DOMが準備できていない場合は後で更新
                    setTimeout(() => {
                        updateCancellationDisplayImmediately();
                    }, 200);
                } else {
                    console.log('⚠️ Cancellation button not found, will update later');
                    // 要素が準備できていない場合は後で更新（より長い間隔で）
                    setTimeout(() => {
                        updateCancellationDisplayImmediately();
                    }, 100);
                }
            }
        }

        // キャンセル表示エリアを更新（待機版）
        function updateCancellationDisplay() {
            // 即座に更新を試行
            updateCancellationDisplayImmediately();
        }

        // キャンセル表示エリアの表示/非表示を切り替え
        function toggleCancellationDisplay() {
            const display = document.getElementById('cancellation-display');
            const btn = document.getElementById('showCancellationsBtn');
            const list = document.getElementById('cancellation-list');
            
            // 要素が存在しない場合は早期リターン
            if (!display || !btn || !list) {
                console.error('❌ Cancellation display elements not found');
                showMessage('キャンセル表示エリアが見つかりませんでした。', 'error');
                return;
            }
            
            if (display.style.display === 'none') {
                // 表示する
                display.style.display = 'block';
                btn.classList.add('active');
                
                // 現在の週のキャンセル履歴を取得してリストを更新
                const currentWeekCancellations = getCurrentWeekCancellations();
                const listHtml = currentWeekCancellations.map(reservation => `
                    <div class="cancellation-item">
                        <div class="cancellation-info">
                            <div class="cancellation-customer">${reservation.customer}</div>
                            <div class="cancellation-details">
                                📅 ${reservation.date} <span class="cancellation-time">${reservation.time}</span> | 
                                ⏱️ ${reservation.duration}分 | 
                                🗑️ ${reservation.cancelledAt}
                            </div>
                        </div>
                    </div>
                `).join('');
                
                list.innerHTML = listHtml;
                
                showMessage('キャンセル履歴を表示しました。', 'info');
            } else {
                // 非表示にする
                display.style.display = 'none';
                btn.classList.remove('active');
                showMessage('キャンセル履歴を非表示にしました。', 'info');
            }
        }

        // キャンセル表示エリアをクリア
        function clearCancellationDisplay() {
            console.log('🗑️ Clearing cancellation display...');
            
            // データをクリア
            cancelledReservations = [];
            
            // ローカルストレージからも削除
            localStorage.removeItem('cancelledReservations');
            
            // 要素を取得
            const display = document.getElementById('cancellation-display');
            const btn = document.getElementById('showCancellationsBtn');
            const countSpan = document.getElementById('cancellation-count');
            const list = document.getElementById('cancellation-list');
            
            // 要素が存在する場合のみ操作
            if (btn && countSpan) {
                // カウントを更新
                countSpan.textContent = '0';
                btn.textContent = '❌ キャンセル履歴 (0)';
                btn.disabled = false;
            }
            
            if (display) {
                display.style.display = 'none';
            }
            
            if (btn) {
                btn.classList.remove('active');
            }
            
            if (list) {
                list.innerHTML = '';
            }
            
            console.log('✅ Cancellation display cleared successfully');
            
            // 即座に更新
            updateCancellationDisplayImmediately();
            
            showMessage('キャンセル履歴をクリアしました。', 'info');
        }
        
        // キャンセル表示の初期化（即座に実行）
        function initializeCancellationDisplay() {
            console.log('🚀 Starting cancellation display initialization...');
            loadCancelledReservations();
            
            // 即座に更新を試行
            setTimeout(() => {
                updateCancellationDisplayImmediately();
                cancellationDisplayReady = true;
                console.log('✅ Cancellation display initialized successfully');
            }, 100);
        }
        
        // 初期化実行
        init();
        
        // DOMが完全に読み込まれてからキャンセル表示を初期化
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => {
                domReady = true;
                setTimeout(() => {
                    initializeCancellationDisplay();
                }, 100);
            });
        } else {
            // DOMが既に読み込まれている場合
            domReady = true;
            setTimeout(() => {
                initializeCancellationDisplay();
            }, 100);
        }
        
        // ユーザー検索機能を初期化
        document.addEventListener('DOMContentLoaded', function() {
            setupUserSearch();
        });

        // Add this helper near the top of the file (or before validateReservationTimeWithinBusinessHours)
        function parseLocalDate(dateStr) {
          const [year, month, day] = dateStr.split('-').map(Number);
          return new Date(year, month - 1, day);
        }

        if (currentReservation) {
          if (!currentReservation.date) {
            if (currentReservation.dateKey) {
              currentReservation.date = currentReservation.dateKey;
            } else if (currentReservation.original && currentReservation.original.date) {
              currentReservation.date = currentReservation.original.date;
            } else if (currentReservation.latest && currentReservation.latest.date) {
              currentReservation.date = currentReservation.latest.date;
            } else if (typeof selectedDateKey !== 'undefined') {
              currentReservation.date = selectedDateKey;
            } else if (typeof currentDateKey !== 'undefined') {
              currentReservation.date = currentDateKey;
            } else if (currentReservation.id) {
              // Fallback: look up in loaded reservations
              for (const key in reservations) {
                const found = reservations[key]?.find(r => r.id === currentReservation.id);
                if (found && found.date) {
                  currentReservation.date = found.date;
                  break;
                }
              }
            }
          }
          console.log('AFTER PATCH: currentReservation.date =', currentReservation.date);
        }

        // Helper to set currentReservation by id (and optional dateKey)
        function setCurrentReservationById(reservationId, dateKey) {
          let found = null;
          if (dateKey && reservations[dateKey]) {
            found = reservations[dateKey].find(r => r.id === reservationId);
          }
          if (!found) {
            for (const key in reservations) {
              const r = reservations[key]?.find(r => r.id === reservationId);
              if (r) {
                found = r;
                break;
              }
            }
          }
          if (found) {
            currentReservation = found;
            console.log('setCurrentReservationById: found reservation with date', currentReservation.date);
          } else {
            console.warn('setCurrentReservationById: reservation not found for id', reservationId);
          }
        }

        // Example usage: Replace any direct assignment to currentReservation when opening the edit modal or starting to edit a reservation with:
        // setCurrentReservationById(reservationId, dateKey);

        // Normalize reservation object to ensure start_time is always set
        function normalizeReservation(reservation) {
            if (!reservation.start_time && reservation.reservationDate) {
                reservation.start_time = reservation.reservationDate;
                console.log('🛠️ Normalized reservation.start_time from reservationDate:', reservation.start_time);
            }
            // Always set reservation.date if missing
            if (!reservation.date && (reservation.start_time || reservation.reservationDate)) {
                const dateObj = new Date(reservation.start_time || reservation.reservationDate);
                // Format as YYYY-MM-DD in local time
                const yyyy = dateObj.getFullYear();
                const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
                const dd = String(dateObj.getDate()).padStart(2, '0');
                reservation.date = `${yyyy}-${mm}-${dd}`;
                console.log('🛠️ Normalized reservation.date from start_time/reservationDate:', reservation.date);
            }
            return reservation;
        }

        // Example usage: when loading or processing reservations
        // Wherever reservations are loaded from backend or processed, call normalizeReservation(reservation)
        // For example, in loadReservationsFromBackend or similar functions:
        // reservations.forEach(normalizeReservation);

        // Helper to get correct day of week for reservation (local time)
        function getReservationDayOfWeek(reservation) {
            if (reservation.date) {
                // Parse as local date
                const [year, month, day] = reservation.date.split('-').map(Number);
                const date = new Date(year, month - 1, day);
                return date.getDay();
            }
            const dateStr = reservation.start_time || reservation.reservationDate;
            if (!dateStr) return undefined;
            const date = new Date(dateStr);
            return date.getDay();
        }