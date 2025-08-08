import consumer from "./consumer"

const settingsChannel = consumer.subscriptions.create("SettingsChannel", {
  connected() {
    console.log("📡 Connected to SettingsChannel")
  },

  disconnected() {
    console.log("📡 Disconnected from SettingsChannel")
  },

  received(data) {
    console.log("📨 Settings update received:", data)
    
    if (data.type === "business_hours_changed") {
      // シフトハイライト機能に通知
      if (window.shiftHighlighter) {
        window.shiftHighlighter.changeShift(data.start_hour, data.end_hour);
        
        // 通知メッセージを表示
        showRemoteUpdateNotification(data);
      }
    }
  }
});

function showRemoteUpdateNotification(data) {
  const notification = document.createElement('div');
  notification.className = 'alert alert-info position-fixed';
  notification.style.cssText = `
    top: 20px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 2000;
    min-width: 300px;
    text-align: center;
    animation: slideDown 0.5s ease-out;
  `;
  
  notification.innerHTML = `
    <strong>🔄 営業時間が更新されました</strong><br>
    新しい時間: ${data.start_hour}:00 - ${data.end_hour}:00
    ${data.updated_by ? `<br><small>更新者: ${data.updated_by}</small>` : ''}
  `;
  
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.animation = 'slideUp 0.5s ease-in';
    setTimeout(() => notification.remove(), 500);
  }, 5000);
} 