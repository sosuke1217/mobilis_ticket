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
      
      // チケット情報を設定
      newRow.innerHTML = `
        <td>
          <strong>${ticket.ticket_template.name}</strong>
          <br><small class="text-muted">¥${ticket.ticket_template.price.toLocaleString()}</small>
        </td>
        <td>
          <span class="badge bg-primary fs-6 fw-bold">
            ${ticket.remaining_count} / ${ticket.total_count}
          </span>
        </td>
        <td>${ticket.purchase_date ? new Date(ticket.purchase_date).toLocaleDateString('ja-JP') : '不明'}</td>
        <td>${ticket.expiry_date ? new Date(ticket.expiry_date).toLocaleDateString('ja-JP') : '無期限'}</td>
        <td>
          <span class="badge bg-success">利用可能</span>
        </td>
        <td>
          <button type="button" 
                  class="btn btn-sm btn-outline-primary use-ticket-btn"
                  data-ticket-id="${ticket.id}"
                  data-ticket-name="${ticket.ticket_template.name || '不明'}">
            使用
          </button>
          <button type="button" 
                  class="btn btn-sm btn-outline-danger delete-ticket-btn ms-1"
                  data-ticket-id="${ticket.id}"
                  data-ticket-name="${ticket.ticket_template.name || '不明'}">
            <i class="fas fa-trash"></i>
          </button>
        </td>
      `
      
      // リストに追加
      this.ticketListTarget.appendChild(newRow)
      console.log('✅ 新規チケット行を追加')
      
      // 新しく追加された行のボタンにイベントリスナーを設定
      this.setupButtonsForRow(newRow)
      
      // チケット数を更新
      this.updateTicketCounts()
      
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
      
      // 残り回数セルを検索（複数の方法で）
      let remainingCountCell = ticketRow.querySelector('.badge')
      
      if (!remainingCountCell) {
        // 代替方法1: 残り回数を含むセルを検索
        remainingCountCell = Array.from(ticketRow.children).find(cell => 
          cell.textContent.includes('/') || cell.textContent.includes('回')
        )
      }
      
      if (!remainingCountCell) {
        // 代替方法2: 4番目のセル（残り回数が表示される位置）
        const cells = ticketRow.children
        if (cells.length >= 4) {
          remainingCountCell = cells[3]
        }
      }
      
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
        
        // 既存の内容をクリアしてから新しい内容を設定
        remainingCountCell.innerHTML = ''
        badgeElement = document.createElement('span')
        badgeElement.className = 'badge bg-primary fs-6 fw-bold'
        remainingCountCell.appendChild(badgeElement)
        
        // 改行や空白を除去してテキストを設定
        badgeElement.textContent = `${remainingCount}/${totalCount}`
        console.log('✅ 残り回数を更新:', `${remainingCount}/${totalCount}`)
        console.log('🔍 更新後の残り回数セルの内容:', remainingCountCell.innerHTML)
        
        // 残り回数に応じてバッジの色を変更
        if (parseInt(remainingCount) === 0) {
          badgeElement.className = 'badge bg-secondary fs-6 fw-bold'
          console.log('✅ 使用済みチケットとして表示を更新')
        } else if (parseInt(remainingCount) <= 2) {
          badgeElement.className = 'badge bg-warning fs-6 fw-bold'
          console.log('✅ 残り少ないチケットとして表示を更新')
        } else {
          badgeElement.className = 'badge bg-primary fs-6 fw-bold'
          console.log('✅ 利用可能チケットとして表示を更新')
        }
        
        // 残り回数が0になった場合の処理
        if (parseInt(remainingCount) === 0) {
          // 行の背景色を変更して使用済みであることを示す
          ticketRow.classList.add('table-secondary')
          ticketRow.classList.add('text-muted')
          
          // 使用ボタンを無効化
          const useButton = ticketRow.querySelector('.use-ticket-btn')
          if (useButton) {
            useButton.disabled = true
            useButton.classList.add('disabled')
            useButton.title = '使用済み'
            useButton.innerHTML = '<i class="fas fa-ticket-alt me-1"></i>使用済み'
          }
          
          // ステータスセルを更新
          const statusCell = ticketRow.querySelector('td:nth-child(5)')
          if (statusCell) {
            const statusBadge = statusCell.querySelector('.badge')
            if (statusBadge) {
              statusBadge.className = 'badge bg-secondary fs-6 fw-bold'
              statusBadge.textContent = '使用済み'
            }
          }
          
          console.log('✅ 使用済みチケットとして表示を更新')
        }
      }
      
      // チケット数を再計算（即座に実行）
      this.updateTicketCounts()
      
      // 成功メッセージを表示
      this.showAlert('success', 'チケットを使用しました')
      
      console.log('✅ チケット使用後の表示更新完了')
      
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
