class Admin::BaseController < ApplicationController
  layout "dashboard"

  before_action :require_admin!

  helper_method :admin_section?

  private

  def admin_section?
    true
  end
end
