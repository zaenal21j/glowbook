class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s
    unless I18n.available_locales.map(&:to_s).include?(locale)
      return redirect_to(request.referer.presence || root_path,
                         alert: I18n.t("locale.invalid"))
    end

    session[:locale] = locale
    language = I18n.t("locale.names.#{locale}", locale: locale.to_sym)
    redirect_to request.referer.presence || root_path,
                notice: I18n.t("locale.changed", language: language, locale: locale.to_sym)
  end
end
