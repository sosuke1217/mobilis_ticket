class PwaController < ApplicationController
  def manifest
    render json: {
      name: "Mobilis Ticket System",
      short_name: "Mobilis",
      description: "チケット管理システム",
      start_url: "/",
      display: "standalone",
      background_color: "#ffffff",
      theme_color: "#007bff",
      icons: [
        {
          src: "/icon.png",
          sizes: "192x192",
          type: "image/png"
        },
        {
          src: "/icon.svg",
          sizes: "any",
          type: "image/svg+xml"
        }
      ]
    }
  end

  def service_worker
    render file: Rails.root.join('app', 'views', 'pwa', 'service-worker.js'), 
           content_type: 'application/javascript'
  end
end 