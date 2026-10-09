class PwaController < ApplicationController
  def manifest
    response.headers["Cache-Control"] = "private, no-cache"
    render template: "pwa/manifest", layout: false
  end
end
