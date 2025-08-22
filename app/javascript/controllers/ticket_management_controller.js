// チケット管理ページ専用のJavaScriptコントローラー
// 重複実行を完全に防ぐための強力なメカニズム

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "ticketList", "ticketCount", "totalPrice", "modal", "modalName", "modalRemaining", "confirmButton"]
  
  connect() {
    console.log('🎫 チケット管理ページコントローラー接続開始')
    
    // 重複実行チェック
    if (this.isAlreadyInitialized()) {
      console.log('⚠️ 既に初期化済みです')
      return
    }
    
    this.initialize()
  }
  
  disconnect() {
    console.log('🎫 チケット管理ページコントローラー切断')
    this.cleanup()
  }
  
  // 重複初期化チェック
  isAlreadyInitialized() {
    return window.ticketManagementControllerInitialized === true
  }
  
  // 初期化完了マーク
  markAsInitialized() {
    window.ticketManagementControllerInitialized = true
    console.log('✅ チケット管理ページコントローラー初期化完了フラグを設定')
  }
  
  // 初期化処理
  initialize() {
    try {
      console.log('🎫 チケット管理ページ初期化開始')
      
      // チケット発行フォームの確認
      if (!this.hasFormTarget) {
        console.error('❌ チケット発行フォームが見つかりません')
        return
      }
      
      console.log('✅ チケット発行フォームを発見')
      
      // フォームのイベントリスナーを設定
      this.setupFormHandlers()
      
      // チケットボタンのイベントリスナーを設定
      this.setupTicketButtons()
      
      // 初期化完了をマーク
      this.markAsInitialized()
      
      console.log('✅ チケット管理ページ初期化完了')
      
    } catch (error) {
      console.error('❌ チケット管理ページ初期化中にエラーが発生しました:', error)
    }
  }
  
  // フォームハンドラーの設定
  setupFormHandlers() {
    console.log('📝 フォームハンドラーの設定開始')
    
    // フォームのsubmitイベントリスナーを設定
    this.formTarget.addEventListener('submit', this.handleTicketSubmit.bind(this))
    
    console.log('📝 フォームハンドラーの設定完了')
  }
  
  // チケットボタンの設定
  setupTicketButtons() {
    console.log('🔘 チケットボタンの設定開始')
    
    // 使用ボタンと削除ボタンのイベントリスナーを設定
    this.element.addEventListener('click', (e) => {
      const useBtn = e.target.closest('.use-ticket-btn')
      const deleteBtn = e.target.closest('.delete-ticket-btn')
      
      if (useBtn && !useBtn.disabled) {
        e.preventDefault()
        e.stopPropagation()
        this.handleTicketUse(useBtn)
      } else if (deleteBtn && !deleteBtn.disabled) {
        e.preventDefault()
        e.stopPropagation()
        this.handleTicketDelete(deleteBtn)
      }
    })
    
    console.log('🔘 チケットボタンの設定完了')
  }
  
  // チケット発行処理
  handleTicketSubmit(event) {
    event.preventDefault()
    
    if (this.isProcessing) {
      console.log('⚠️ 既に処理中のため、重複実行をスキップ')
      return
    }
    
    this.isProcessing = true
    
    try {
      console.log('🎫 チケット発行処理開始')
      
      const templateId = document.getElementById('ticketTemplate').value
      const count = document.getElementById('ticketCount').value
      
      if (!templateId) {
        alert('チケット種類を選択してください')
        this.isProcessing = false
        return
      }
      
      // ボタンを無効化
      const submitBtn = event.target.querySelector('button[type="submit"]')
      const originalText = submitBtn.innerHTML
      submitBtn.disabled = true
      submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>発行中...'
      
      // CSRF トークンを取得
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      if (!csrfToken) {
        throw new Error('CSRFトークンが見つかりません')
      }
      
      // チケット発行APIを呼び出し
      fetch('/admin/tickets/create_for_user', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({
          user_id: this.getUserIdFromPage(),
          ticket_template_id: templateId,
          count: count
        })
      })
      .then(response => {
        console.log('Response status:', response.status)
        
        if (!response.ok) {
          return response.json().then(data => {
            throw new Error(data.error || 'チケット発行に失敗しました')
          })
        }
        return response.json()
      })
      .then(data => {
        console.log('✅ Ticket created:', data)
        
        // 成功メッセージを表示
        this.showAlert('success', data.message)
        
        // チケット一覧を更新
        if (data.ticket) {
          this.addNewTicketToList(data.ticket)
        }
        
        // フォームをリセット
        event.target.reset()
        
        // チケット数を更新
        setTimeout(() => {
          this.updateTicketCounts()
        }, 100)
        
        // 既存チケットがある場合の残額更新
        setTimeout(() => {
          this.updateTicketCounts()
        }, 200)
        
        this.isProcessing = false
      })
      .catch(error => {
        console.error('❌ Error creating ticket:', error)
        this.showAlert('danger', `チケット発行エラー: ${error.message}`)
        this.isProcessing = false
      })
      .finally(() => {
        // ボタンを元に戻す
        submitBtn.disabled = false
        submitBtn.innerHTML = originalText
      })
      
    } catch (error) {
      console.error('❌ チケット発行処理中にエラーが発生しました:', error)
      this.showAlert('danger', `発行処理エラー: ${error.message}`)
      this.isProcessing = false
    }
  }
  
  // ページからユーザーIDを取得
  getUserIdFromPage() {
    // URLからユーザーIDを抽出（例: /admin/users/1/ticket_management から 1 を取得）
    const urlMatch = window.location.pathname.match(/\/admin\/users\/(\d+)\/ticket_management/)
    if (urlMatch) {
      return urlMatch[1]
    }
    
    // 代替方法: ページ内の要素から取得
    const userIdElement = document.querySelector('[data-user-id]')
    if (userIdElement) {
      return userIdElement.getAttribute('data-user-id')
    }
    
    throw new Error('ユーザーIDを取得できませんでした')
  }
  
  // 新チケットを一覧に追加
  addNewTicketToList(ticket) {
    try {
      console.log('🎫 新チケット追加開始:', ticket)
      
      // 「保有チケットがありません」の行を削除
      const noTicketsRow = this.element.querySelector('tbody tr td[colspan]')
      if (noTicketsRow) {
        console.log('🗑️ 「保有チケットがありません」の行を削除')
        noTicketsRow.closest('tr').remove()
      }
      
      // チケット一覧のtbodyを取得
      const tbody = this.element.querySelector('tbody')
      if (!tbody) {
        console.error('❌ tbodyが見つかりません')
        return
      }
      
      // 新しいチケット行を作成
      const newRow = document.createElement('tr')
      newRow.setAttribute('data-ticket-id', ticket.id)
      newRow.innerHTML = `
        <td>
          <strong>${ticket.ticket_template.name}</strong>
          <br><small class="text-muted">¥${ticket.ticket_template.price.toLocaleString()}</small>
        </td>
        <td>
          <span class="badge bg-primary">${ticket.remaining_count}/${ticket.total_count}</span>
        </td>
        <td>${ticket.purchase_date ? new Date(ticket.purchase_date).toLocaleDateString('ja-JP') : 'なし'}</td>
        <td>${ticket.expiry_date ? new Date(ticket.expiry_date).toLocaleDateString('ja-JP') : '無期限'}</td>
        <td>
          <span class="badge bg-success">利用可能</span>
        </td>
        <td>
          <button class="btn btn-sm btn-outline-primary use-ticket-btn" data-ticket-id="${ticket.id}" data-ticket-name="${ticket.ticket_template.name}">
            <i class="fas fa-ticket-alt me-1"></i>使用
          </button>
          <button class="btn btn-sm btn-outline-danger delete-ticket-btn ms-1" data-ticket-id="${ticket.id}" data-ticket-name="${ticket.ticket_template.name}">
            <i class="fas fa-trash me-1"></i>削除
          </button>
        </td>
      `
      
      // 新しい行をtbodyに追加
      tbody.appendChild(newRow)
      
      console.log('✅ 新チケットを一覧に追加完了')
      console.log('🔍 追加後のtbody行数:', tbody.children.length)
      
    } catch (error) {
      console.error('❌ 新チケット追加中にエラーが発生しました:', error)
    }
  }
  
  // チケット使用処理
  handleTicketUse(button) {
    if (this.isProcessing) {
      console.log('⚠️ 既に処理中のため、重複実行をスキップ')
      return
    }
    
    this.isProcessing = true
    
    try {
      const ticketId = button.getAttribute('data-ticket-id')
      const ticketName = button.getAttribute('data-ticket-name')
      
      console.log('🎫 チケット使用処理開始:', { ticketId, ticketName })
      
      // 確認ダイアログ
      if (!confirm(`「${ticketName}」を1回使用しますか？`)) {
        console.log('❌ ユーザーがキャンセルしました')
        this.isProcessing = false
        return
      }
      
      // チケット使用APIを呼び出し
      this.useTicket(ticketId, button)
      
    } catch (error) {
      console.error('❌ チケット使用処理中にエラーが発生しました:', error)
      this.showAlert('danger', `使用処理エラー: ${error.message}`)
      this.isProcessing = false
    }
  }
  
  // チケット使用実行
  useTicket(ticketId, button) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    
    if (!csrfToken) {
      throw new Error('CSRFトークンが見つかりません')
    }
    
    fetch(`/admin/tickets/${ticketId}/use`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken
      }
    })
    .then(response => {
      if (!response.ok) {
        return response.json().then(data => {
          throw new Error(data.error || 'チケット使用に失敗しました')
        })
      }
      return response.json()
    })
    .then(data => {
      console.log('✅ Ticket used:', data)
      
      if (data.success) {
        // 成功メッセージを表示
        this.showAlert('success', 'チケットを使用しました')
        
        // チケット表示を即座に更新
        this.updateTicketDisplayAfterUse(ticketId, data.remaining_count, data.total_count)
        
        // チケット数を更新
        setTimeout(() => {
          this.updateTicketCounts()
        }, 100)
      }
      
      this.isProcessing = false
    })
    .catch(error => {
      console.error('❌ Error using ticket:', error)
      this.showAlert('danger', `チケット使用エラー: ${error.message}`)
      this.isProcessing = false
    })
  }
  
  // チケット使用後の表示更新
  updateTicketDisplayAfterUse(ticketId, remainingCount, totalCount) {
    try {
      const ticketRow = this.element.querySelector(`tr[data-ticket-id="${ticketId}"]`)
      if (!ticketRow) {
        console.error('❌ チケット行が見つかりません')
        return
      }
      
      // 残り回数を更新
      const badgeElement = ticketRow.querySelector('.badge')
      if (badgeElement) {
        badgeElement.textContent = `${remainingCount}/${totalCount}`
        
        // 残り回数に応じてバッジの色を変更
        if (remainingCount === 0) {
          badgeElement.className = 'badge bg-secondary'
          const statusElement = ticketRow.querySelector('.badge.bg-success')
          if (statusElement) {
            statusElement.className = 'badge bg-secondary'
            statusElement.textContent = '使用済み'
          }
        } else if (remainingCount < totalCount) {
          badgeElement.className = 'badge bg-warning'
        }
      }
      
      // 使用ボタンを無効化（残り回数が0の場合）
      if (remainingCount === 0) {
        const useButton = ticketRow.querySelector('.use-ticket-btn')
        if (useButton) {
          useButton.disabled = true
          useButton.className = 'btn btn-sm btn-secondary me-1'
          useButton.innerHTML = '<i class="fas fa-ticket-alt me-1"></i>使用済み'
        }
      }
      
      console.log('✅ チケット表示を更新しました')
      
    } catch (error) {
      console.error('❌ チケット表示更新中にエラーが発生しました:', error)
    }
  }
  
  // チケット削除処理
  handleTicketDelete(button) {
    if (this.isProcessing) {
      console.log('⚠️ 既に処理中のため、重複実行をスキップ')
      return
    }
    
    this.isProcessing = true
    
    try {
      console.log('🗑️ チケット削除処理開始')
      
      // 削除ボタンの詳細情報をログ出力
      console.log('🔍 削除ボタンの詳細:', {
        element: button,
        classList: button.className,
        attributes: Array.from(button.attributes).map(attr => ({ name: attr.name, value: attr.value })),
        innerHTML: button.innerHTML,
        outerHTML: button.outerHTML.substring(0, 200) + '...'
      })
      
      const ticketId = button.getAttribute('data-ticket-id')
      const ticketName = button.getAttribute('data-ticket-name')
      
      // 属性値の取得結果をログ出力
      console.log('🔍 属性値の取得結果:', {
        ticketId: ticketId,
        ticketName: ticketName,
        ticketIdType: typeof ticketId,
        ticketNameType: typeof ticketName,
        ticketIdTruthy: !!ticketId,
        ticketNameTruthy: !!ticketName
      })
      
      if (!ticketId || !ticketName) {
        console.error('❌ 削除ボタンに必要な属性が設定されていません:', { ticketId, ticketName })
        this.isProcessing = false
        return
      }
      
      console.log('🎫 削除対象:', { ticketId, ticketName })
      
      // チケット行から残り回数を取得
      const ticketRow = button.closest('tr')
      if (!ticketRow) {
        console.error('❌ チケット行が見つかりません')
        this.isProcessing = false
        return
      }
      
      console.log('🔍 チケット行の詳細:', {
        element: ticketRow,
        innerHTML: ticketRow.innerHTML.substring(0, 200) + '...',
        children: ticketRow.children.length
      })
      
      // 残り回数を取得（2列目）
      const remainingCountCell = ticketRow.children[1] // 0-indexedなので2列目は1
      if (!remainingCountCell) {
        console.error('❌ 残り回数セルが見つかりません')
        this.isProcessing = false
        return
      }
      
      // 残り回数を抽出（例: "4/4" から "4" を取得）
      const remainingCountMatch = remainingCountCell.textContent.match(/(\d+)\/(\d+)/)
      if (!remainingCountMatch) {
        console.error('❌ 残り回数の形式が期待と異なります:', remainingCountCell.textContent)
        this.isProcessing = false
        return
      }
      
      const remainingCount = remainingCountMatch[1]
      console.log('📊 残り回数:', remainingCount)
      
      // 削除確認モーダルを表示
      this.showDeleteModal(ticketId, ticketName, remainingCount)
      
    } catch (error) {
      console.error('❌ チケット削除処理中にエラーが発生しました:', error)
      this.showAlert('danger', `削除処理エラー: ${error.message}`)
      this.isProcessing = false
    }
  }
  
  // 削除確認モーダル表示
  showDeleteModal(ticketId, ticketName, remainingCount) {
    try {
      console.log('🎭 モーダル表示開始:', { ticketId, ticketName, remainingCount })
      
      // モーダル要素を取得
      const deleteTicketModal = document.querySelector('#deleteTicketModal')
      const deleteTicketName = document.querySelector('#deleteTicketName')
      const deleteTicketRemaining = document.querySelector('#deleteTicketRemaining')
      
      if (!deleteTicketModal || !deleteTicketName || !deleteTicketRemaining) {
        console.error('❌ 必要なモーダル要素が見つかりません')
        alert('削除確認モーダルの準備に失敗しました。ページを再読み込みしてください。')
        this.isProcessing = false
        return
      }
      
      // モーダルにデータを設定
      deleteTicketName.textContent = ticketName || '不明'
      deleteTicketRemaining.textContent = remainingCount || '不明'
      
      // モーダルを表示
      const deleteModal = new bootstrap.Modal(deleteTicketModal)
      deleteModal.show()
      
      // 削除実行ボタンのイベントリスナー
      const confirmBtn = document.querySelector('#confirmDeleteTicketBtn')
      if (confirmBtn) {
        confirmBtn.onclick = () => {
          this.deleteTicket(ticketId)
          deleteModal.hide()
          this.cleanupModalBackground()
        }
      }
      
      console.log('✅ 削除確認モーダル表示完了')
      
    } catch (error) {
      console.error('❌ モーダル表示中にエラーが発生しました:', error)
      alert('モーダル表示中にエラーが発生しました: ' + error.message)
      this.isProcessing = false
    }
  }
  
  // チケット削除実行
  deleteTicket(ticketId) {
    try {
      console.log('🔄 チケット削除API呼び出し中...')
      
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      if (!csrfToken) {
        throw new Error('CSRFトークンが見つかりません')
      }
      
      fetch(`/admin/tickets/${ticketId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        }
      })
      .then(response => {
        console.log('Response status:', response.status)
        console.log('Response headers:', response.headers)
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        
        return response.json().catch(() => ({ success: true }))
      })
      .then(data => {
        console.log('✅ Ticket deleted:', ticketId)
        
        // 成功メッセージを表示
        this.showAlert('success', 'チケットを削除しました')
        
        // チケット行を即座に削除
        const ticketRow = this.element.querySelector(`tr[data-ticket-id="${ticketId}"]`)
        if (ticketRow) {
          ticketRow.remove()
          console.log('✅ チケット行を削除しました')
        }
        
        // チケットが0件になった場合の処理
        const remainingRows = this.element.querySelectorAll('tbody tr')
        if (remainingRows.length === 0) {
          const tbody = this.element.querySelector('tbody')
          if (tbody) {
            tbody.innerHTML = `
              <tr>
                <td colspan="6" class="text-center py-4">
                  <i class="fas fa-ticket-alt fa-3x text-muted mb-3"></i>
                  <p class="text-muted">保有チケットがありません</p>
                </td>
              </tr>
            `
            console.log('✅ 「保有チケットがありません」の表示を追加しました')
          }
        }
        
        // チケット数を更新
        setTimeout(() => {
          this.updateTicketCounts()
        }, 100)
        
        // 既存チケットがある場合の残額更新
        setTimeout(() => {
          this.updateTicketCounts()
        }, 200)
        
        this.isProcessing = false
      })
      .catch(error => {
        console.error('❌ Error deleting ticket:', error)
        this.showAlert('danger', `チケット削除エラー: ${error.message}`)
        this.isProcessing = false
      })
      
    } catch (error) {
      console.error('❌ チケット削除処理中にエラーが発生しました:', error)
      this.showAlert('danger', `削除処理エラー: ${error.message}`)
      this.isProcessing = false
    }
  }
  
  // チケット数と残額の更新
  updateTicketCounts() {
    try {
      console.log('🔄 チケット数更新開始')
      
      const tbody = this.element.querySelector('tbody')
      if (!tbody) {
        console.error('❌ tbodyが見つかりません')
        return
      }
      
      const rows = Array.from(tbody.children)
      console.log('🔍 現在のtbody状態:', { totalRows: rows.length, rows: rows })
      
      // 残りチケット数と残り回数を計算
      let remainingTickets = 0
      let totalRemainingCount = 0
      
      rows.forEach(row => {
        const badgeElement = row.querySelector('.badge')
        if (badgeElement && badgeElement.textContent.includes('/')) {
          const match = badgeElement.textContent.match(/(\d+)\/(\d+)/)
          if (match) {
            const remaining = parseInt(match[1])
            const total = parseInt(match[2])
            if (remaining > 0) {
              remainingTickets++
              totalRemainingCount += remaining
            }
          }
        }
      })
      
      console.log('📊 計算結果:', { 
        remainingTickets: remainingTickets, 
        totalRemainingCount: totalRemainingCount 
      })
      
      // 残りチケット数を表示
      const ticketCountElement = this.element.querySelector('#remainingTicketCount')
      if (ticketCountElement) {
        ticketCountElement.innerHTML = `<strong>残チケット:</strong> ${totalRemainingCount} 回`
        console.log('✅ 残りチケット数表示を更新しました')
      }
      
      // チケット価格合計を計算
      console.log('💰 チケット価格計算開始:', remainingTickets + '件のチケットを処理')
      console.log('🔍 全tbody行の内容:')
      
      let totalPrice = 0
      rows.forEach((row, index) => {
        const badgeElement = row.querySelector('.badge')
        const priceElement = row.querySelector('small.text-muted')
        
        console.log(`行${index + 1}: ${row.innerHTML}`)
        console.log('🔍 行' + (index + 1) + 'の要素:', { 
          badge: badgeElement?.textContent, 
          priceElement: priceElement?.textContent,
          rowHTML: row.innerHTML.substring(0, 200) + '...'
        })
        
        if (badgeElement && priceElement) {
          const priceMatch = priceElement.textContent.match(/¥([\d,]+)/)
          if (priceMatch) {
            const price = parseInt(priceMatch[1].replace(/,/g, ''))
            if (!isNaN(price)) {
              totalPrice += price
              console.log(`💰 チケット${index + 1}: 価格=${price}, 累計価格=${totalPrice}`)
            }
          }
        } else {
          console.log(`⚠️ チケット${index + 1}: 要素が見つかりません`)
        }
      })
      
      console.log('💰 最終チケット価格合計:', totalPrice)
      
      // チケット価格合計を表示
      const totalPriceElement = this.element.querySelector('#remainingTicketValue')
      if (totalPriceElement) {
        totalPriceElement.innerHTML = `<strong>チケット価格合計:</strong> ¥${totalPrice.toLocaleString()}`
        console.log('✅ チケット価格合計表示を更新しました:', totalPrice)
      }
      
      // デバッグ情報コンテナの確認
      const debugContainer = this.element.querySelector('.bg-light.border.rounded')
      if (!debugContainer) {
        console.log('⚠️ デバッグ情報コンテナが見つかりません')
      }
      
      console.log('🔄 チケット数更新完了')
      
    } catch (error) {
      console.error('❌ チケット数更新中にエラーが発生しました:', error)
    }
  }
  
  // アラート表示
  showAlert(type, message) {
    const alertDiv = document.createElement('div')
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`
    alertDiv.innerHTML = `
      <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-triangle'} me-2"></i>
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `
    
    const container = this.element.querySelector('.container-lg')
    if (container) {
      container.insertBefore(alertDiv, container.querySelector('.card'))
      
      // アラートを自動で消す
      setTimeout(() => {
        if (alertDiv && alertDiv.parentNode) {
          alertDiv.remove()
        }
      }, 5000)
    }
  }
  
  // モーダル背景のクリーンアップ
  cleanupModalBackground() {
    try {
      console.log('🔄 背景クリーンアップ開始')
      
      // 既存のモーダル背景要素を削除
      const existingBackdrops = document.querySelectorAll('.modal-backdrop')
      console.log('📊 発見された背景要素:', existingBackdrops.length, '個')
      
      existingBackdrops.forEach((backdrop, index) => {
        console.log(`🗑️ 背景要素${index + 1}を削除中...`)
        backdrop.remove()
        console.log(`✅ 背景要素${index + 1}を削除完了`)
      })
      
      // bodyのmodal-openクラスを削除
      document.body.classList.remove('modal-open')
      document.body.style.overflow = ''
      document.body.style.paddingRight = ''
      
      console.log('✅ 背景クリーンアップ完了')
      
    } catch (error) {
      console.error('❌ 背景クリーンアップ中にエラーが発生しました:', error)
    }
  }
  
  // クリーンアップ処理
  cleanup() {
    // イベントリスナーの削除など
    console.log('🧹 チケット管理ページコントローラークリーンアップ完了')
  }
}
