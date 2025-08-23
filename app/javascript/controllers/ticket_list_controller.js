// チケット一覧ページ専用のJavaScriptコントローラー
// 重複実行を完全に防ぐための強力なメカニズム

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["deleteButton", "modal", "modalName", "modalUser", "modalRemaining", "confirmButton"]
  
  connect() {
    console.log('🎫 チケット一覧ページコントローラー接続開始')
    
    // 重複実行チェック
    if (this.isAlreadyInitialized()) {
      console.log('⚠️ 既に初期化済みです')
      return
    }
    
    this.initialize()
  }
  
  disconnect() {
    console.log('🎫 チケット一覧ページコントローラー切断')
    this.cleanup()
  }
  
  // 重複初期化チェック
  isAlreadyInitialized() {
    return window.ticketListControllerInitialized === true
  }
  
  // 初期化完了マーク
  markAsInitialized() {
    window.ticketListControllerInitialized = true
    console.log('✅ チケット一覧ページコントローラー初期化完了フラグを設定')
  }
  
  // 初期化処理
  initialize() {
    try {
      console.log('🎫 チケット一覧ページ初期化開始')
      
      // 削除ボタンのイベントリスナーを設定
      this.setupDeleteButtons()
      
      // 初期化完了をマーク
      this.markAsInitialized()
      
      console.log('✅ チケット一覧ページ初期化完了')
      
    } catch (error) {
      console.error('❌ チケット一覧ページ初期化中にエラーが発生しました:', error)
    }
  }
  
  // 削除ボタンの設定
  setupDeleteButtons() {
    const deleteButtons = this.element.querySelectorAll('.delete-ticket-btn')
    console.log(`🔘 削除ボタン${deleteButtons.length}個を発見`)
    
    deleteButtons.forEach(button => {
      // 既存のイベントリスナーを削除
      button.removeEventListener('click', this.handleDeleteClick.bind(this))
      
      // 新しいイベントリスナーを追加
      button.addEventListener('click', this.handleDeleteClick.bind(this))
    })
  }
  
  // 削除ボタンクリック処理
  handleDeleteClick(event) {
    event.preventDefault()
    event.stopPropagation()
    
    try {
      const button = event.currentTarget
      const ticketId = button.getAttribute('data-ticket-id')
      const ticketName = button.getAttribute('data-ticket-name')
      const userName = button.getAttribute('data-user-name')
      
      console.log('🗑️ チケット削除処理開始:', { ticketId, ticketName, userName })
      
      // 必要な属性の確認
      if (!ticketId || !ticketName) {
        console.error('❌ 削除ボタンに必要な属性が設定されていません:', { ticketId, ticketName })
        return
      }
      
      // モーダル表示
      this.showDeleteModal(ticketId, ticketName, userName)
      
    } catch (error) {
      console.error('❌ チケット削除処理中にエラーが発生しました:', error)
      alert('削除処理の準備中にエラーが発生しました: ' + error.message)
    }
  }
  
  // 削除確認モーダル表示
  showDeleteModal(ticketId, ticketName, userName) {
    try {
      console.log('🎭 モーダル表示開始:', { ticketId, ticketName, userName })
      
      // 残り回数を取得
      const remainingCount = this.getRemainingCount(ticketId)
      console.log('📊 残り回数:', remainingCount)
      
      // モーダル要素を複数の方法で検索
      let deleteTicketModal = null
      let deleteTicketName = null
      let deleteTicketUser = null
      let deleteTicketRemaining = null
      
      // 方法1: 直接的なID検索
      deleteTicketModal = document.querySelector('#deleteTicketModal')
      deleteTicketName = document.querySelector('#deleteTicketName')
      deleteTicketUser = document.querySelector('#deleteTicketUser')
      deleteTicketRemaining = document.querySelector('#deleteTicketRemaining')
      
      console.log('🔍 方法1での検索結果:', {
        modal: !!deleteTicketModal,
        name: !!deleteTicketName,
        user: !!deleteTicketUser,
        remaining: !!deleteTicketRemaining
      })
      
      // 方法2: より柔軟な検索（IDの一部を含む要素）
      if (!deleteTicketModal) {
        deleteTicketModal = document.querySelector('[id*="deleteTicketModal"]')
        console.log('🔍 方法2でのモーダル検索結果:', !!deleteTicketModal)
      }
      
      if (!deleteTicketName) {
        deleteTicketName = document.querySelector('[id*="deleteTicketName"]')
        console.log('🔍 方法2での名前要素検索結果:', !!deleteTicketName)
      }
      
      if (!deleteTicketUser) {
        deleteTicketUser = document.querySelector('[id*="deleteTicketUser"]')
        console.log('🔍 方法2でのユーザー要素検索結果:', !!deleteTicketUser)
      }
      
      if (!deleteTicketRemaining) {
        deleteTicketRemaining = document.querySelector('[id*="deleteTicketRemaining"]')
        console.log('🔍 方法2での残り回数要素検索結果:', !!deleteTicketRemaining)
      }
      
      // 方法3: ページ全体からモーダル要素を検索
      if (!deleteTicketModal) {
        const allModals = document.querySelectorAll('.modal')
        console.log('🔍 ページ内の全モーダル要素:', allModals.length)
        
        allModals.forEach((modal, index) => {
          console.log(`  - モーダル${index + 1}:`, {
            id: modal.id,
            className: modal.className,
            visible: modal.style.display !== 'none'
          })
        })
        
        // 削除関連のモーダルを探す
        deleteTicketModal = Array.from(allModals).find(modal => 
          modal.id.includes('delete') || 
          modal.querySelector('[id*="delete"]') ||
          modal.textContent.includes('削除')
        )
        
        if (deleteTicketModal) {
          console.log('✅ 削除関連のモーダルを発見:', deleteTicketModal.id)
        }
      }
      
      // 方法4: データ属性による検索
      if (!deleteTicketModal) {
        deleteTicketModal = document.querySelector('[data-ticket-list-target="modal"]')
        console.log('🔍 データ属性でのモーダル検索結果:', !!deleteTicketModal)
      }
      
      // 必要な要素の存在確認
      if (!deleteTicketModal) {
        console.error('❌ モーダル本体が見つかりません')
        console.log('🔍 ページ内の全要素の詳細調査:')
        console.log('- body要素:', !!document.body)
        console.log('- 全モーダル要素:', document.querySelectorAll('.modal').length)
        console.log('- 削除関連の要素:', document.querySelectorAll('[id*="delete"]').length)
        
        // ページのHTML構造を確認
        const pageHTML = document.body.innerHTML.substring(0, 1000)
        console.log('🔍 ページHTML（最初の1000文字）:', pageHTML)
        
        alert('削除確認モーダルの準備に失敗しました。ページを再読み込みしてください。')
        return
      }
      
      if (!deleteTicketName) {
        console.error('❌ チケット名要素が見つかりません')
        // 代替要素を探す
        deleteTicketName = deleteTicketModal.querySelector('[id*="Name"]') || 
                          deleteTicketModal.querySelector('[class*="name"]') ||
                          deleteTicketModal.querySelector('span, div')
        
        if (deleteTicketName) {
          console.log('✅ 代替のチケット名要素を発見:', deleteTicketName.tagName, deleteTicketName.className)
        }
      }
      
      if (!deleteTicketUser) {
        console.error('❌ ユーザー名要素が見つかりません')
        // 代替要素を探す
        deleteTicketUser = deleteTicketModal.querySelector('[id*="User"]') || 
                          deleteTicketModal.querySelector('[class*="user"]') ||
                          deleteTicketModal.querySelector('span, div')
        
        if (deleteTicketUser) {
          console.log('✅ 代替のユーザー名要素を発見:', deleteTicketUser.tagName, deleteTicketUser.className)
        }
      }
      
      if (!deleteTicketRemaining) {
        console.error('❌ 残り回数要素が見つかりません')
        // 代替要素を探す
        deleteTicketRemaining = deleteTicketModal.querySelector('[id*="Remaining"]') || 
                               deleteTicketModal.querySelector('[class*="remaining"]') ||
                               deleteTicketModal.querySelector('span, div')
        
        if (deleteTicketRemaining) {
          console.log('✅ 代替の残り回数要素を発見:', deleteTicketRemaining.tagName, deleteTicketRemaining.className)
        }
      }
      
      // 最低限必要な要素の確認
      if (!deleteTicketModal) {
        console.error('❌ モーダル本体が絶対に見つかりません')
        alert('削除確認モーダルの準備に失敗しました。ページを再読み込みしてください。')
        return
      }
      
      // モーダルにデータを設定（要素が見つからない場合は警告を表示）
      if (deleteTicketName) {
        deleteTicketName.textContent = ticketName || '不明'
      } else {
        console.warn('⚠️ チケット名要素が見つからないため、モーダルに表示できません')
      }
      
      if (deleteTicketUser) {
        deleteTicketUser.textContent = userName || '不明'
      } else {
        console.warn('⚠️ ユーザー名要素が見つからないため、モーダルに表示できません')
      }
      
      if (deleteTicketRemaining) {
        deleteTicketRemaining.textContent = remainingCount || '不明'
      } else {
        console.warn('⚠️ 残り回数要素が見つからないため、モーダルに表示できません')
      }
      
      // モーダルを表示
      try {
        const modal = new bootstrap.Modal(deleteTicketModal)
        modal.show()
        console.log('✅ モーダル表示成功')
      } catch (modalError) {
        console.error('❌ モーダル表示中にエラーが発生しました:', modalError)
        alert('モーダルの表示に失敗しました: ' + modalError.message)
        return
      }
      
      // 削除実行ボタンのイベントリスナー
      const confirmBtn = deleteTicketModal.querySelector('#confirmDeleteTicketBtn') ||
                        deleteTicketModal.querySelector('[id*="confirm"]') ||
                        deleteTicketModal.querySelector('.btn-danger')
      
      if (confirmBtn) {
        console.log('✅ 削除確認ボタンを発見:', confirmBtn.tagName, confirmBtn.className)
        confirmBtn.onclick = () => {
          this.deleteTicket(ticketId)
          try {
            const modal = bootstrap.Modal.getInstance(deleteTicketModal)
            if (modal) {
              modal.hide()
            }
          } catch (e) {
            console.warn('⚠️ モーダルを閉じる際にエラーが発生しました:', e)
          }
          this.cleanupModalBackground()
        }
      } else {
        console.error('❌ 削除確認ボタンが見つかりません')
        alert('削除確認ボタンが見つかりません。ページを再読み込みしてください。')
        return
      }
      
      console.log('✅ 削除確認モーダル表示完了')
      
    } catch (error) {
      console.error('❌ モーダル表示中にエラーが発生しました:', error)
      alert('モーダル表示中にエラーが発生しました: ' + error.message)
    }
  }
  
  // 残り回数を取得
  getRemainingCount(ticketId) {
    try {
      const ticketRow = this.element.querySelector(`tr:has(button[data-ticket-id="${ticketId}"])`)
      if (!ticketRow) {
        console.error('❌ チケット行が見つかりません')
        return null
      }
      
      // 残り回数を取得（4列目）
      const remainingCountCell = ticketRow.children[3] // 0-indexedなので4列目は3
      if (!remainingCountCell) {
        console.error('❌ 残り回数セルが見つかりません')
        return null
      }
      
      // 残り回数を抽出（例: "残り: 3 回" から "3" を取得）
      const remainingCountMatch = remainingCountCell.textContent.match(/残り:\s*(\d+)\s*回/)
      if (!remainingCountMatch) {
        console.error('❌ 残り回数の形式が期待と異なります:', remainingCountCell.textContent)
        return null
      }
      
      return remainingCountMatch[1]
      
    } catch (error) {
      console.error('❌ 残り回数取得中にエラーが発生しました:', error)
      return null
    }
  }
  
  // チケット削除実行
  deleteTicket(ticketId) {
    if (this.isProcessing) {
      console.log('⚠️ 既に処理中のため、重複実行をスキップ')
      return
    }
    
    this.isProcessing = true
    
    try {
      console.log('🔄 チケット削除API呼び出し中...')
      
      // CSRF トークンを取得
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      if (!csrfToken) {
        throw new Error('CSRFトークンが見つかりません')
      }
      
      // チケット削除APIを呼び出し
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
        
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`)
        }
        
        return response.json().catch(() => ({ success: true }))
      })
      .then(data => {
        console.log('✅ Ticket deleted:', data)
        
        // 成功メッセージを表示
        this.showAlert('success', 'チケットを削除しました')
        
        // チケット行を即座に削除
        this.removeTicketRow(ticketId)
        
        // 成功メッセージを3秒後に自動で消す
        setTimeout(() => {
          this.removeAlert('success')
        }, 3000)
        
        console.log('🔄 チケット削除完了')
        this.isProcessing = false
      })
      .catch(error => {
        console.error('❌ Error deleting ticket:', error)
        alert('チケットの削除に失敗しました: ' + error.message)
        this.isProcessing = false
      })
      
    } catch (error) {
      console.error('❌ チケット削除処理中にエラーが発生しました:', error)
      alert('削除処理の準備中にエラーが発生しました: ' + error.message)
      this.isProcessing = false
    }
  }
  
  // チケット行を削除
  removeTicketRow(ticketId) {
    const ticketRow = this.element.querySelector(`tr:has(button[data-ticket-id="${ticketId}"])`)
    if (ticketRow) {
      ticketRow.remove()
      console.log('✅ チケット行を削除しました')
      
      // チケットが0件になった場合の処理
      const remainingRows = this.element.querySelectorAll('tbody tr')
      if (remainingRows.length === 0) {
        const tbody = this.element.querySelector('tbody')
        if (tbody) {
          tbody.innerHTML = `
            <tr>
              <td colspan="6" class="text-center py-4">
                <i class="fas fa-ticket-alt fa-3x text-muted mb-3"></i>
                <p class="text-muted">チケットがありません</p>
              </td>
            </tr>
          `
          console.log('✅ 「チケットがありません」の表示を追加しました')
        }
      }
    }
  }
  
  // 成功メッセージを表示
  showAlert(type, message) {
    const alertDiv = document.createElement('div')
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`
    alertDiv.innerHTML = `
      <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-triangle'} me-2"></i>
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `
    
    const container = this.element.querySelector('.container')
    if (container) {
      container.insertBefore(alertDiv, container.firstChild)
    }
  }
  
  // アラートを削除
  removeAlert(type) {
    const alertElement = this.element.querySelector(`.alert-${type}`)
    if (alertElement && alertElement.parentNode) {
      alertElement.remove()
    }
  }
  
  // モーダル背景のクリーンアップ
  cleanupModalBackground() {
    try {
      console.log('🔄 モーダル背景クリーンアップ開始')
      
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
      
      console.log('✅ モーダル背景クリーンアップ完了')
      
    } catch (error) {
      console.error('❌ モーダル背景クリーンアップ中にエラーが発生しました:', error)
    }
  }
  
  // クリーンアップ処理
  cleanup() {
    // イベントリスナーの削除など
    console.log('🧹 チケット一覧ページコントローラークリーンアップ完了')
  }
}
