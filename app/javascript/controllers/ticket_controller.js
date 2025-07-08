import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["remaining", "button"]
  static values = { id: Number }

  async use(event) {
    console.log("使うボタンが押されました")

    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute("content")

    const response = await fetch(`/admin/tickets/${this.idValue}/use`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Content-Type": "application/json"
      }
    })

    if (response.ok) {
      const data = await response.json()
      console.log("成功:", data)
      this.remainingTarget.textContent = `残り: ${data.remaining_count} 回`
    } else {
      console.error("失敗")
      alert("消費に失敗しました")
    }
  }
}
