class OauthProviderSetup
  def self.call(env, provider)
    configuration = IntegrationSetting.effective(provider)
    raise OmniAuth::Error, "provider_not_configured" unless configuration.ready?

    strategy = env.fetch("omniauth.strategy")
    strategy.options[:client_id] = configuration.settings.fetch("client_id")
    strategy.options[:client_secret] = configuration.settings.fetch("client_secret")
    strategy.options[:redirect_uri] = "#{Rails.configuration.x.app_host.chomp('/')}/users/auth/#{provider}/callback"
    strategy.options[:callback_url] = strategy.options[:redirect_uri]
  end
end
