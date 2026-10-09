class Account::BaseController < ApplicationController
  include Paginatable

  layout "account"
  before_action :authenticate_user!

  private

  def current_business_for_owner
    current_user.businesses.first
  end
end
