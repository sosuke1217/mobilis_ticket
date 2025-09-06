// チケット管理ページ専用のJavaScriptコントローラー
// 重複実行を完全に防ぐための強力なメカニズム

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "ticketList", "ticketCount", "totalPrice", "modal", "modalName", "modalRemaining", "confirmButton"]
  
  // コントローラーが接続されたときの処理
  connect() {
    try {
      console.log('🔌 チケット管理コントローラーが接続されました')
      
      // 初期化処理を実行
      this.initialize()
      
    } catch (error) {
      console.error('❌ コントローラー接続中にエラーが発生しました:', error)
    }
  }

  // コントローラーが切断されたときの処理
  disconnect() {
    try {
      console.log('🔌 チケット管理コントローラーが切断されました')
      
      // イベントリスナーのクリーンアップ
      this.cleanup()
      
    } catch (error) {
      console.error('❌ コントローラー切断中にエラーが発生しました:', error)
    }
  }
  
  // 初期化処理
  initialize() {
    try {
      console.log('🚀 チケット管理コントローラーの初期化開始')
      
      // フォームハンドラーの設定
      this.setupFormHandlers()
      
      // チケットボタンの設定（少し遅延させて実行）
      setTimeout(() => {
        this.setupTicketButtons()
      }, 100)
      
      // チケット数の初期表示
      this.updateTicketCounts()
      
      console.log('✅ チケット管理コントローラーの初期化完了')
      
    } catch (error) {
      console.error('❌ 初期化中にエラーが発生しました:', error)
    }
  }
  
  // フォームハンドラーの設定
  setupFormHandlers() {
    console.log('📝 フォームハンドラーの設定開始')
    
    // フォームのsubmitイベントリスナーを設定
    this.formTarget.addEventListener('submit', this.handleTicketSubmit.bind(this))
    
    console.log('📝 フォームハンドラーの設定完了')
  }
  
  // 特定の行のボタンにイベントリスナーを設定
  setupButtonsForRow(row) {
    try {
      console.log('🔘 行のボタン設定開始:', row)
      
      // 使用ボタンの設定
      const useButton = row.querySelector('.use-ticket-btn')
      if (useButton) {
        const ticketId = useButton.getAttribute('data-ticket-id')
        const ticketName = useButton.getAttribute('data-ticket-name')
        
        console.log('🔘 使用ボタンを設定:', { ticketId, ticketName })
        
        // 既存のイベントリスナーを削除
        useButton.removeEventListener('click', this.handleTicketButtonClick)
        
        // 新しいイベントリスナーを追加
        useButton.addEventListener('click', (e) => {
          e.preventDefault()
          e.stopPropagation()
          
          if (e.target.disabled) {
            console.log('⏳ ボタンが無効化されているため、処理をスキップします')
            return
          }
          
          if (!ticketId) {
            console.error('❌ チケットIDが設定されていません')
            this.showAlert('danger', 'チケットIDが設定されていません')
            return
          }
          
          console.log('🎫 使用ボタンクリック:', { ticketId, ticketName })
          
          // 確認ダイアログを表示
          if (confirm(`「${ticketName || 'チケット'}」を1回使用しますか？`)) {
            this.useTicket(ticketId, useButton)
          }
        })
        
        console.log('✅ 使用ボタンの設定完了:', ticketId)
      }
      
      // 削除ボタンの設定
      const deleteButton = row.querySelector('.delete-ticket-btn')
      if (deleteButton) {
        const ticketId = deleteButton.getAttribute('data-ticket-id')
        const ticketName = deleteButton.getAttribute('data-ticket-name')
        
        console.log('🔘 削除ボタンを設定:', { ticketId, ticketName })
        
        // 既存のイベントリスナーを削除
        deleteButton.removeEventListener('click', this.handleTicketButtonClick)
        
        // 新しいイベントリスナーを追加
        deleteButton.addEventListener('click', (e) => {
          e.preventDefault()
          e.stopPropagation()
          
          if (e.target.disabled) {
            console.log('⏳ ボタンが無効化されているため、処理をスキップします')
            return
          }
          
          if (!ticketId) {
            console.error('❌ チケットIDが設定されていません')
            this.showAlert('danger', 'チケットIDが設定されていません')
            return
          }
          
          console.log('🗑️ 削除ボタンクリック:', { ticketId, ticketName })
          
          // 削除確認モーダルを表示
          this.handleTicketDelete(deleteButton)
        })
        
        console.log('✅ 削除ボタンの設定完了:', ticketId)
      }
      
      console.log('✅ 行のボタン設定完了')
      
    } catch (error) {
      console.error('❌ 行のボタン設定中にエラーが発生しました:', error)
    }
  }

  // チケットボタンの設定
  setupTicketButtons() {
    try {
      console.log('🔘 チケットボタンの設定開始')
      
      // 使用ボタンの設定
      const useButtons = document.querySelectorAll('.use-ticket-btn')
      console.log('🔍 使用ボタンの数:', useButtons.length)
      
      useButtons.forEach((button, index) => {
        const ticketId = button.getAttribute('data-ticket-id')
        const ticketName = button.getAttribute('data-ticket-name')
        
        console.log(`🔘 使用ボタン${index + 1}を設定:`, { ticketId, ticketName })
        
        // 既存のイベントリスナーを削除
        button.removeEventListener('click', this.handleTicketButtonClick)
        
        // 新しいイベントリスナーを追加
        button.addEventListener('click', (e) => {
          e.preventDefault()
          e.stopPropagation()
          
          if (e.target.disabled) {
            console.log('⏳ ボタンが無効化されているため、処理をスキップします')
            return
          }
          
          if (!ticketId) {
            console.error('❌ チケットIDが設定されていません')
            this.showAlert('danger', 'チケットIDが設定されていません')
            return
          }
          
          console.log('🎫 使用ボタンクリック:', { ticketId, ticketName })
          
          // 確認ダイアログを表示
          if (confirm(`「${ticketName || 'チケット'}」を1回使用しますか？`)) {
            this.useTicket(ticketId, button)
          }
        })
        
        console.log(`✅ 使用ボタン${index + 1}の設定完了:`, ticketId)
      })
      
      // 削除ボタンの設定
      const deleteButtons = document.querySelectorAll('.delete-ticket-btn')
      console.log('🔍 削除ボタンの数:', deleteButtons.length)
      
      deleteButtons.forEach((button, index) => {
        const ticketId = button.getAttribute('data-ticket-id')
        const ticketName = button.getAttribute('data-ticket-name')
        
        console.log(`🔘 削除ボタン${index + 1}を設定:`, { ticketId, ticketName })
        
        // 既存のイベントリスナーを削除
        button.removeEventListener('click', this.handleTicketButtonClick)
        
        // 新しいイベントリスナーを追加
        button.addEventListener('click', (e) => {
          e.preventDefault()
          e.stopPropagation()
          
          if (e.target.disabled) {
            console.log('⏳ ボタンが無効化されているため、処理をスキップします')
            return
          }
          
          if (!ticketId) {
            console.error('❌ チケットIDが設定されていません')
            this.showAlert('danger', 'チケットIDが設定されていません')
            return
          }
          
          console.log('🗑️ 削除ボタンクリック:', { ticketId, ticketName })
          
          // 削除確認モーダルを表示
          this.handleTicketDelete(button)
        })
        
        console.log(`✅ 削除ボタン${index + 1}の設定完了:`, ticketId)
      })
      
      console.log('✅ チケットボタンの設定完了')
      
    } catch (error) {
      console.error('❌ チケットボタンの設定中にエラーが発生しました:', error)
    }
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
  
  // 新規チケットをリストに追加
  addNewTicketToList(ticket) {
    try {
      console.log('➕ 新規チケットをリストに追加:', ticket)
      
      // "保有チケットがありません"の行を削除
      const noTicketsRow = this.ticketListTarget.querySelector('tr:has(td[colspan="6"])')
      if (noTicketsRow) {
        noTicketsRow.remove()
        console.log('✅ "保有チケットがありません"の行を削除')
      }
      
      // 新しい行を作成
      const newRow = document.createElement('tr')
      newRow.setAttribute('data-ticket-id', ticket.id)
      
      // 購入日と有効期限のフォーマット
      const purchaseDate = ticket.purchase_date ? new Date(ticket.purchase_date).toLocaleDateString('ja-JP', { month: '2-digit', day: '2-digit' }) : '不明'
      const expiryDate = ticket.expiry_date ? new Date(ticket.expiry_date).toLocaleDateString('ja-JP', { month: '2-digit', day: '2-digit' }) : '無期限'
      
      // チケット情報を設定（新しいレイアウトに合わせて）
      newRow.innerHTML = `
        <td class="px-3">
          <div>
            <strong>${ticket.ticket_template.name}</strong>
            <br>
            <small class="text-muted">
              ¥${Math.floor(ticket.ticket_template.price / ticket.ticket_template.total_count).toLocaleString()}
            </small>
          </div>
        </td>
        <td>
          <span class="badge bg-primary">
            ${ticket.remaining_count} / ${ticket.total_count}
          </span>
        </td>
        <td>
          <i class="fas fa-calendar-day me-1 text-muted"></i>
          ${purchaseDate}
        </td>
        <td>
          ${ticket.expiry_date ? 
            `<i class="fas fa-clock me-1 text-muted"></i>${expiryDate}` : 
            '<span class="text-muted">無期限</span>'
          }
        </td>
        <td>
          <span class="badge bg-success">
            <i class="fas fa-check me-1"></i>利用可能
          </span>
        </td>
        <td class="text-center">
          <div class="btn-group" role="group">
            <button type="button" 
                    class="btn btn-sm btn-outline-primary use-ticket-btn"
                    data-ticket-id="${ticket.id}"
                    data-ticket-name="${ticket.ticket_template.name || '不明'}"
                    title="チケットを使用">
              <i class="fas fa-play"></i>
            </button>
            <button type="button" 
                    class="btn btn-sm btn-outline-danger delete-ticket-btn"
                    data-ticket-id="${ticket.id}"
                    data-ticket-name="${ticket.ticket_template.name || '不明'}"
                    title="チケットを削除">
              <i class="fas fa-trash"></i>
            </button>
          </div>
        </td>
      `
      
      // リストに追加
      this.ticketListTarget.appendChild(newRow)
      console.log('✅ 新規チケット行を追加')
      
      // 新しく追加された行のボタンにイベントリスナーを設定
      this.setupButtonsForRow(newRow)
      
      // チケット数を更新（DOMの更新を待つ）
      setTimeout(() => {
        this.updateTicketCounts()
      }, 100)
      
      // 成功メッセージを表示
      this.showAlert('success', 'チケットを発行しました')
      
    } catch (error) {
      console.error('❌ 新規チケットの追加中にエラーが発生しました:', error)
      this.showAlert('danger', 'チケットの追加中にエラーが発生しました')
    }
  }
  
  // チケット使用処理
  useTicket(ticketId, button) {
    if (this.isProcessing) {
      console.log('⏳ 処理中のため、チケット使用をスキップします')
      return
    }
    
    this.isProcessing = true
    const originalButtonText = button.innerHTML
    button.disabled = true
    button.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>使用中...'
    
    try {
      console.log('🎫 チケット使用開始:', ticketId)
      
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
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
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.json()
      })
      .then(data => {
        console.log('✅ チケット使用成功:', data)
        
        // 残り回数と総回数を取得（複数の形式に対応）
        let remainingCount = null
        let totalCount = null
        
        // 形式1: remaining_count, total_count
        if (data.remaining_count !== undefined && data.total_count !== undefined) {
          remainingCount = data.remaining_count
          totalCount = data.total_count
          console.log('📊 形式1で残り回数情報を取得:', { remainingCount, totalCount })
        }
        // 形式2: remainingCount, totalCount
        else if (data.remainingCount !== undefined && data.totalCount !== undefined) {
          remainingCount = data.remainingCount
          totalCount = data.totalCount
          console.log('📊 形式2で残り回数情報を取得:', { remainingCount, totalCount })
        }
        // 形式3: remaining, total
        else if (data.remaining !== undefined && data.total !== undefined) {
          remainingCount = data.remaining
          totalCount = data.total
          console.log('📊 形式3で残り回数情報を取得:', { remainingCount, totalCount })
        }
        // 形式4: 現在の行から情報を取得
        else {
          console.log('⚠️ APIレスポンスに残り回数情報が含まれていません。現在の行から情報を取得します。')
          
          // 現在の行から残り回数情報を取得
          const currentRow = document.querySelector(`tr[data-ticket-id="${ticketId}"]`)
          if (currentRow) {
            const badgeElement = currentRow.querySelector('.badge')
            if (badgeElement) {
              const badgeText = badgeElement.textContent.trim()
              const match = badgeText.match(/(\d+)\s*\/\s*(\d+)/)
              if (match) {
                remainingCount = parseInt(match[1]) - 1 // 1回使用したので-1
                totalCount = parseInt(match[2])
                console.log('📊 現在の行から残り回数情報を取得:', { remainingCount, totalCount })
              }
            }
          }
        }
        
        // 値の検証
        if (remainingCount === null || totalCount === null || 
            isNaN(remainingCount) || isNaN(totalCount)) {
          console.error('❌ 残り回数情報が無効です:', { remainingCount, totalCount })
          
          // 現在の行から再度情報を取得
          const currentRow = document.querySelector(`tr[data-ticket-id="${ticketId}"]`)
          if (currentRow) {
            const badgeElement = currentRow.querySelector('.badge')
            if (badgeElement) {
              const badgeText = badgeElement.textContent.trim()
              const match = badgeText.match(/(\d+)\s*\/\s*(\d+)/)
              if (match) {
                remainingCount = parseInt(match[1]) - 1 // 1回使用したので-1
                totalCount = parseInt(match[2])
                console.log('📊 再取得した残り回数情報:', { remainingCount, totalCount })
              }
            }
          }
        }
        
        if (remainingCount !== null && totalCount !== null && 
            !isNaN(remainingCount) && !isNaN(totalCount)) {
          console.log('📊 最終的な残り回数情報:', { remainingCount, totalCount })
          
          // 表示を即座に更新
          this.updateTicketDisplayAfterUse(ticketId, remainingCount, totalCount)
          
        } else {
          console.error('❌ 残り回数情報が取得できませんでした:', { remainingCount, totalCount })
          // 情報が取得できない場合は、チケット数を再計算
          this.updateTicketCounts()
        }
      })
      .catch(error => {
        console.error('❌ チケット使用中にエラーが発生しました:', error)
        
        // エラーメッセージを表示
        let errorMessage = 'チケットの使用中にエラーが発生しました'
        if (error.message.includes('HTTP error')) {
          errorMessage = 'サーバーエラーが発生しました。しばらく待ってから再試行してください。'
        }
        
        this.showAlert('danger', errorMessage)
      })
      .finally(() => {
        // ボタンを元の状態に戻す
        button.disabled = false
        button.innerHTML = originalButtonText
        
        this.isProcessing = false
        console.log('🎫 チケット使用処理完了')
      })
      
    } catch (error) {
      console.error('❌ チケット使用処理の初期化中にエラーが発生しました:', error)
      this.showAlert('danger', 'チケット使用処理の初期化に失敗しました')
      
      // ボタンを元の状態に戻す
      button.disabled = false
      button.innerHTML = originalButtonText
      
      this.isProcessing = false
    }
  }
  
  // チケット使用後の表示更新
  updateTicketDisplayAfterUse(ticketId, remainingCount, totalCount) {
    try {
      console.log('🔄 チケット使用後の表示更新開始:', { ticketId, remainingCount, totalCount })
      
      // チケット行を検索（複数の方法で）
      let ticketRow = document.querySelector(`tr[data-ticket-id="${ticketId}"]`)
      
      if (!ticketRow) {
        // 代替方法1: より柔軟なセレクター
        ticketRow = document.querySelector(`tr:has([data-ticket-id="${ticketId}"])`)
      }
      
      if (!ticketRow) {
        // 代替方法2: テーブル内の全行を検索
        const allRows = document.querySelectorAll('tbody tr')
        ticketRow = Array.from(allRows).find(row => {
          const ticketIdCell = row.querySelector('[data-ticket-id]')
          return ticketIdCell && ticketIdCell.getAttribute('data-ticket-id') === ticketId
        })
      }
      
      if (!ticketRow) {
        console.error('❌ チケット行が見つかりません:', ticketId)
        // 行が見つからない場合は、チケット数を再計算してページを更新
        this.updateTicketCounts()
        return
      }
      
      console.log('✅ チケット行を発見:', ticketRow)
      
      // 残り回数セルを検索（2番目のセル）
      const remainingCountCell = ticketRow.children[1]
      
      if (!remainingCountCell) {
        console.error('❌ 残り回数セルが見つかりません')
        // セルが見つからない場合は、チケット数を再計算
        this.updateTicketCounts()
        return
      }
      
      console.log('✅ 残り回数セルを発見:', remainingCountCell)
      
      // 残り回数を更新
      if (remainingCountCell) {
        console.log('🔍 残り回数セルの現在の内容:', remainingCountCell.innerHTML)
        
        // 既存のbadge要素を探す
        let badgeElement = remainingCountCell.querySelector('.badge')
        
        if (!badgeElement) {
          // badge要素がない場合は新しく作成
          badgeElement = document.createElement('span')
          badgeElement.className = 'badge bg-primary'
          remainingCountCell.appendChild(badgeElement)
        }
        
        // 既存のbadge要素の内容のみを更新（セル全体をクリアしない）
        badgeElement.textContent = `${remainingCount}/${totalCount}`
        console.log('✅ 残り回数を更新:', `${remainingCount}/${totalCount}`)
        console.log('🔍 更新後の残り回数セルの内容:', remainingCountCell.innerHTML)
        
        // 残り回数に応じてバッジの色を変更
        if (parseInt(remainingCount) === 0) {
          badgeElement.className = 'badge bg-secondary'
          console.log('✅ 使用済みチケットとして表示を更新')
          
          // 残り回数が0になった場合は行を削除
          ticketRow.remove()
          console.log('✅ 使用済みチケットの行を削除')
          
          // チケット数を再計算（即座に実行）
          this.updateTicketCounts()
          
          // 成功メッセージを表示
          this.showAlert('success', 'チケットを使用しました')
          
          console.log('✅ チケット使用後の表示更新完了')
          return
        } else if (parseInt(remainingCount) <= 2) {
          badgeElement.className = 'badge bg-warning'
          console.log('✅ 残り少ないチケットとして表示を更新')
        } else {
          badgeElement.className = 'badge bg-primary'
          console.log('✅ 利用可能チケットとして表示を更新')
        }
        
        // ステータスセルを更新（5番目のセル）
        const statusCell = ticketRow.children[4]
        if (statusCell) {
          const statusBadge = statusCell.querySelector('.badge')
          if (statusBadge) {
            if (parseInt(remainingCount) === 0) {
              statusBadge.className = 'badge bg-secondary'
              statusBadge.innerHTML = '<i class="fas fa-check me-1"></i>使用済み'
            } else if (parseInt(remainingCount) <= 2) {
              statusBadge.className = 'badge bg-warning'
              statusBadge.innerHTML = '<i class="fas fa-exclamation me-1"></i>残り少ない'
            } else {
              statusBadge.className = 'badge bg-success'
              statusBadge.innerHTML = '<i class="fas fa-check me-1"></i>利用可能'
            }
            console.log('✅ ステータスバッジを更新')
          }
        }
        
        // 操作ボタンを更新（6番目のセル）
        const actionCell = ticketRow.children[5]
        if (actionCell && parseInt(remainingCount) === 0) {
          // 残り回数が0の場合は使用ボタンを無効化
          const useButton = actionCell.querySelector('.use-ticket-btn')
          if (useButton) {
            useButton.disabled = true
            useButton.className = 'btn btn-sm btn-outline-secondary'
            useButton.innerHTML = '<i class="fas fa-ban"></i>'
            useButton.title = '使用不可'
          }
        }
        
        // チケット数を再計算（即座に実行）
        this.updateTicketCounts()
        
        // 成功メッセージを表示
        this.showAlert('success', 'チケットを使用しました')
        
        console.log('✅ チケット使用後の表示更新完了')
      }
    } catch (error) {
      console.error('❌ チケット使用後の表示更新中にエラーが発生しました:', error)
      // エラーが発生した場合は、チケット数を再計算
      this.updateTicketCounts()
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
      
      // チケット行を検索（複数の方法で）
      let ticketRow = button.closest('tr')
      
      if (!ticketRow) {
        // 代替方法1: ボタングループから親要素を辿る
        const btnGroup = button.closest('.btn-group')
        if (btnGroup) {
          ticketRow = btnGroup.closest('tr')
        }
      }
      
      if (!ticketRow) {
        // 代替方法2: data-ticket-id属性で行を検索
        ticketRow = document.querySelector(`tr[data-ticket-id="${ticketId}"]`)
      }
      
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
      
      // 残り回数を抽出（改行や空白を含む形式に対応）
      const remainingCountText = remainingCountCell.textContent.trim()
      console.log('🔍 残り回数セルのテキスト:', `"${remainingCountText}"`)
      
      // 複数の形式に対応した正規表現
      let remainingCountMatch = remainingCountText.match(/(\d+)\s*\/\s*(\d+)/)
      
      if (!remainingCountMatch) {
        // 代替方法: より柔軟な正規表現
        remainingCountMatch = remainingCountText.match(/(\d+).*?(\d+)/)
      }
      
      if (!remainingCountMatch) {
        console.error('❌ 残り回数の形式が期待と異なります:', `"${remainingCountText}"`)
        console.log('🔍 セルの完全なHTML:', remainingCountCell.innerHTML)
        
        // 最後の手段: badge要素から直接取得
        const badgeElement = remainingCountCell.querySelector('.badge')
        if (badgeElement) {
          const badgeText = badgeElement.textContent.trim()
          console.log('🔍 badge要素のテキスト:', `"${badgeText}"`)
          
          remainingCountMatch = badgeText.match(/(\d+)\s*\/\s*(\d+)/)
          if (!remainingCountMatch) {
            remainingCountMatch = badgeText.match(/(\d+).*?(\d+)/)
          }
        }
      }
      
      if (!remainingCountMatch) {
        console.error('❌ 残り回数の抽出に失敗しました。セルの内容を詳しく調査します...')
        
        // セルの詳細な内容をログ出力
        console.log('🔍 セルの詳細調査:')
        console.log('- textContent:', `"${remainingCountCell.textContent}"`)
        console.log('- innerHTML:', remainingCountCell.innerHTML)
        console.log('- children:', remainingCountCell.children.length)
        
        if (remainingCountCell.children.length > 0) {
          Array.from(remainingCountCell.children).forEach((child, index) => {
            console.log(`  - child${index}:`, {
              tagName: child.tagName,
              className: child.className,
              textContent: `"${child.textContent}"`,
              innerHTML: child.innerHTML
            })
          })
        }
        
        this.isProcessing = false
        return
      }
      
      const remainingCount = remainingCountMatch[1]
      const totalCount = remainingCountMatch[2]
      console.log('📊 残り回数:', remainingCount, '/', totalCount)
      
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
      
      console.log('🔍 モーダル表示前の状態:', {
        modalDisplay: deleteTicketModal.style.display,
        modalPosition: deleteTicketModal.style.position,
        bodyOverflow: document.body.style.overflow,
        bodyClassList: document.body.classList.toString()
      })
      
      // 既存の背景をクリア
      const existingBackdrops = document.querySelectorAll('.modal-backdrop')
      console.log('🔍 既存の背景要素数:', existingBackdrops.length)
      existingBackdrops.forEach((backdrop, index) => {
        console.log(`🗑️ 背景要素${index + 1}を削除中...`)
        backdrop.remove()
      })
      
      // モーダルにデータを設定
      deleteTicketName.textContent = ticketName || '不明'
      deleteTicketRemaining.textContent = remainingCount || '不明'
      
      // モーダルを手動で表示
      deleteTicketModal.style.display = 'block'
      deleteTicketModal.style.position = 'fixed'
      deleteTicketModal.style.top = '0'
      deleteTicketModal.style.left = '0'
      deleteTicketModal.style.width = '100%'
      deleteTicketModal.style.height = '100%'
      deleteTicketModal.style.zIndex = '1050'
      deleteTicketModal.style.backgroundColor = 'rgba(0, 0, 0, 0.5)'
      
      // bodyのスタイルを設定
      document.body.classList.add('modal-open')
      document.body.style.overflow = 'hidden'
      
      // 背景の暗さを追加
      const backdrop = document.createElement('div')
      backdrop.className = 'modal-backdrop fade show'
      backdrop.style.position = 'fixed'
      backdrop.style.top = '0'
      backdrop.style.left = '0'
      backdrop.style.width = '100%'
      backdrop.style.height = '100%'
      backdrop.style.zIndex = '1040'
      backdrop.style.backgroundColor = 'rgba(0, 0, 0, 0.5)'
      document.body.appendChild(backdrop)
      
      console.log('🔍 モーダル表示後の状態:', {
        modalDisplay: deleteTicketModal.style.display,
        modalPosition: deleteTicketModal.style.position,
        bodyOverflow: document.body.style.overflow,
        bodyClassList: document.body.classList.toString(),
        backdropCount: document.querySelectorAll('.modal-backdrop').length
      })
      
      // 削除実行ボタンのイベントリスナーを設定
      const confirmBtn = document.querySelector('#confirmDeleteTicketBtn')
      if (confirmBtn) {
        // 既存のイベントリスナーを削除
        confirmBtn.onclick = null
        
        // 新しいイベントリスナーを追加
        confirmBtn.onclick = (e) => {
          e.preventDefault()
          e.stopPropagation()
          console.log('🔍 削除実行ボタンがクリックされました')
          this.deleteTicket(ticketId)
          this.hideDeleteTicketModal()
        }
      }
      
      // モーダルが表示されているか確認
      setTimeout(() => {
        console.log('🔍 モーダル表示確認（1秒後）:', {
          modalDisplay: deleteTicketModal.style.display,
          modalVisible: deleteTicketModal.offsetParent !== null,
          backdropCount: document.querySelectorAll('.modal-backdrop').length
        })
      }, 1000)
      
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
                <td colspan="6" class="text-center py-5">
                  <div class="text-muted">
                    <i class="fas fa-ticket-alt fa-3x mb-3"></i>
                    <p class="mb-0">保有チケットがありません</p>
                    <small>新規チケットを発行してください</small>
                  </div>
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
          // 改行や空白を含む形式に対応した正規表現
          const match = badgeElement.textContent.trim().match(/(\d+)\s*\/\s*(\d+)/)
          if (!match) {
            // 代替方法: より柔軟な正規表現
            const altMatch = badgeElement.textContent.trim().match(/(\d+).*?(\d+)/)
            if (altMatch) {
              const remaining = parseInt(altMatch[1])
              const total = parseInt(altMatch[2])
              if (remaining > 0) {
                remainingTickets++
                totalRemainingCount += remaining
              }
            }
          } else {
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
        ticketCountElement.textContent = totalRemainingCount
        console.log('✅ 残り回数合計表示を更新しました')
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
          priceElementExists: !!priceElement,
          priceElementHTML: priceElement?.innerHTML,
          rowHTML: row.innerHTML.substring(0, 200) + '...'
        })
        
        if (badgeElement && priceElement) {
          // 残り回数を取得
          const badgeText = badgeElement.textContent.trim()
          console.log(`🔍 バッジテキスト: "${badgeText}"`)
          
          // 残り回数を抽出（例: "3 / 5" から 3 を取得）
          let remainingCount = 0
          const countMatch = badgeText.match(/(\d+)\s*\/\s*(\d+)/)
          if (countMatch) {
            remainingCount = parseInt(countMatch[1])
            console.log(`📊 残り回数: ${remainingCount}`)
          } else {
            // 代替方法: より柔軟な正規表現
            const altMatch = badgeText.match(/(\d+).*?(\d+)/)
            if (altMatch) {
              remainingCount = parseInt(altMatch[1])
              console.log(`📊 残り回数（代替）: ${remainingCount}`)
            }
          }
          
          // 価格を取得（より確実な方法）
          const priceText = priceElement.textContent.trim()
          console.log(`🔍 価格テキスト: "${priceText}"`)
          
          // innerHTMLも確認（アイコンが含まれている場合）
          const priceHTML = priceElement.innerHTML
          console.log(`🔍 価格HTML: "${priceHTML}"`)
          
          // 複数の価格形式に対応
          let priceMatch = null
          
          // 1. 通常の¥記号付き価格（優先）
          priceMatch = priceText.match(/¥([\d,]+)/)
          
          // 2. カンマ付き数字のみ
          if (!priceMatch) {
            priceMatch = priceText.match(/([\d,]+)/)
          }
          
          // 2.5. ¥記号付き価格（HTMLから）
          if (!priceMatch) {
            priceMatch = priceHTML.match(/¥([\d,]+)/)
          }
          
          // 3. 数字のみ
          if (!priceMatch) {
            priceMatch = priceText.match(/(\d+)/)
          }
          
          // 4. HTMLから直接数字を抽出（アイコンが含まれている場合）
          if (!priceMatch) {
            priceMatch = priceHTML.match(/(\d+(?:,\d+)*)/)
          }
          
          // 5. 最後の手段：数字とカンマの組み合わせを探す
          if (!priceMatch) {
            priceMatch = priceText.match(/(\d{1,3}(?:,\d{3})*)/)
          }
          
          // 6. さらに柔軟な抽出：HTML内の数字を探す
          if (!priceMatch) {
            const allNumbers = priceHTML.match(/\d+/g)
            if (allNumbers && allNumbers.length > 0) {
              // 最も長い数字を選択（価格の可能性が高い）
              const longestNumber = allNumbers.reduce((a, b) => a.length > b.length ? a : b)
              priceMatch = [null, longestNumber]
              console.log(`🔍 代替抽出: 最長数字 "${longestNumber}"`)
            }
          }
          
          if (priceMatch && remainingCount > 0) {
            const unitPrice = parseInt(priceMatch[1].replace(/,/g, ''))
            if (!isNaN(unitPrice)) {
              const ticketValue = unitPrice * remainingCount
              totalPrice += ticketValue
              console.log(`💰 チケット${index + 1}: 抽出価格="${priceMatch[1]}", 単価=${unitPrice}, 残り回数=${remainingCount}, 価値=${ticketValue}, 累計価格=${totalPrice}`)
            } else {
              console.log(`⚠️ チケット${index + 1}: 価格が数値ではありません: ${priceMatch[1]}`)
              console.log(`⚠️ チケット${index + 1}: 価格変換詳細:`, {
                originalMatch: priceMatch[1],
                afterReplace: priceMatch[1].replace(/,/g, ''),
                parseIntResult: parseInt(priceMatch[1].replace(/,/g, '')),
                isNaN: isNaN(parseInt(priceMatch[1].replace(/,/g, '')))
              })
            }
          } else if (priceMatch) {
            console.log(`⚠️ チケット${index + 1}: 価格は抽出されたが残り回数が0: 価格="${priceMatch[1]}", 残り回数=${remainingCount}`)
          } else if (!priceMatch) {
            console.log(`⚠️ チケット${index + 1}: 価格が見つかりません: "${priceText}"`)
            console.log(`⚠️ チケット${index + 1}: 価格要素の詳細:`, {
              element: priceElement,
              innerHTML: priceElement.innerHTML,
              textContent: priceElement.textContent,
              children: Array.from(priceElement.children).map(child => ({
                tagName: child.tagName,
                textContent: child.textContent,
                innerHTML: child.innerHTML
              }))
            })
            
            // 追加のデバッグ：行全体の構造を確認
            console.log(`⚠️ チケット${index + 1}: 行全体のHTML:`, row.innerHTML)
          } else if (remainingCount <= 0) {
            console.log(`⚠️ チケット${index + 1}: 残り回数が0以下: ${remainingCount}`)
          }
        } else {
          console.log(`⚠️ チケット${index + 1}: 要素が見つかりません`)
          console.log(`⚠️ チケット${index + 1}: 要素検索結果:`, {
            badgeElement: badgeElement,
            priceElement: priceElement,
            allSmallElements: Array.from(row.querySelectorAll('small')),
            allTextMutedElements: Array.from(row.querySelectorAll('.text-muted'))
          })
        }
      })
      
      console.log('💰 最終チケット価格合計:', totalPrice)
      
      // チケット価格合計を表示
      const totalPriceElement = this.element.querySelector('#remainingTicketValue')
      if (totalPriceElement) {
        totalPriceElement.textContent = `¥${totalPrice.toLocaleString()}`
        console.log('✅ 残り回数価値合計表示を更新しました:', totalPrice)
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
  
  // 削除モーダルを閉じる
  hideDeleteTicketModal() {
    console.log('🔍 Hiding delete ticket modal from Stimulus controller')
    
    const modalElement = document.getElementById('deleteTicketModal')
    if (!modalElement) {
      console.error('❌ Delete ticket modal not found')
      return
    }
    
    // isProcessingフラグをリセット
    this.isProcessing = false
    console.log('✅ isProcessing flag reset to false')
    
    // 複数の方法でモーダルを閉じる
    try {
      // 方法1: BootstrapのモーダルAPIを使用
      const modal = bootstrap.Modal.getInstance(modalElement)
      if (modal) {
        modal.hide()
        console.log('✅ Modal hidden via Bootstrap API')
      } else {
        // 方法2: 新しいBootstrapモーダルインスタンスを作成
        const newModal = new bootstrap.Modal(modalElement)
        newModal.hide()
        console.log('✅ Modal hidden via new Bootstrap instance')
      }
    } catch (error) {
      console.log('⚠️ Bootstrap API failed, using manual method:', error)
    }
    
    // 方法3: 確実に手動で非表示（フォールバック）
    setTimeout(() => {
      // モーダル要素を完全にリセット
      modalElement.style.display = 'none'
      modalElement.style.position = ''
      modalElement.style.top = ''
      modalElement.style.left = ''
      modalElement.style.width = ''
      modalElement.style.height = ''
      modalElement.style.zIndex = ''
      modalElement.style.backgroundColor = ''
      modalElement.classList.remove('show')
      modalElement.setAttribute('aria-hidden', 'true')
      modalElement.setAttribute('aria-modal', 'false')
      
      // bodyの状態を完全にリセット
      document.body.classList.remove('modal-open')
      document.body.style.overflow = ''
      document.body.style.paddingRight = ''
      document.body.style.position = ''
      
      // すべての背景要素を削除
      const backdrops = document.querySelectorAll('.modal-backdrop')
      backdrops.forEach(backdrop => backdrop.remove())
      
      // 追加のクリーンアップ: すべてのモーダル関連クラスを削除
      document.querySelectorAll('.modal').forEach(modal => {
        modal.classList.remove('show')
        modal.style.display = 'none'
      })
      
      // 背景クリーンアップも実行
      this.cleanupModalBackground()
      
      console.log('✅ Delete ticket modal hidden manually (fallback)')
      
      // 最終確認: 1秒後にモーダルがまだ表示されている場合は強制削除
      setTimeout(() => {
        if (modalElement.style.display !== 'none' || modalElement.offsetParent !== null) {
          console.log('🚨 Modal still visible, forcing removal')
          modalElement.remove()
          document.body.classList.remove('modal-open')
          document.body.style.overflow = ''
          console.log('🚨 Modal forcibly removed')
        }
      }, 1000)
    }, 100)
  }
  
  // クリーンアップ処理
  cleanup() {
    try {
      console.log('🧹 チケット管理コントローラーのクリーンアップ開始')
      
      // フォームのイベントリスナーを削除
      if (this.hasFormTarget) {
        this.formTarget.removeEventListener('submit', this.handleTicketSubmit)
      }
      
      console.log('✅ チケット管理コントローラーのクリーンアップ完了')
      
    } catch (error) {
      console.error('❌ クリーンアップ中にエラーが発生しました:', error)
    }
  }
}
