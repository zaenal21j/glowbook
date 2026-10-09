require "rails_helper"

RSpec.describe "PWA and public navigation", type: :request do
  it "provides branded PNG icons with the sizes declared in the manifest" do
    get pwa_manifest_path
    expect(response).to have_http_status(:ok)
    manifest = JSON.parse(response.body)
    expect(manifest).to include("name" => "GlowBook", "display" => "standalone", "lang" => "id", "theme_color" => "#e11d54")
    expect(manifest.fetch("icons").map { |icon| icon.fetch("sizes") }).to eq(%w[192x192 512x512])
    manifest.fetch("icons").each do |icon|
      png = File.binread(Rails.root.join("public", icon.fetch("src").delete_prefix("/")))
      expect(png.bytes.first(8)).to eq([137, 80, 78, 71, 13, 10, 26, 10])
      expect(png.byteslice(16, 8).unpack("N2").join("x")).to eq(icon.fetch("sizes"))
      expect(icon.fetch("purpose")).to include("maskable")
    end
    get pwa_service_worker_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('`${CACHE_PREFIX}v3`', '"/icon-192.png"')
  end

  it "localizes the manifest description and language" do
    post locale_path(:en)
    get pwa_manifest_path
    expect(JSON.parse(response.body)).to include("lang" => "en", "description" => "Book beauty and wellness services with GlowBook.")
  end

  it "links the manifest and icons from public, account and dashboard layouts" do
    get root_path
    expect(Nokogiri::HTML(response.body).at_css('link[rel="manifest"]')["href"]).to eq(pwa_manifest_path)
    sign_in create(:user)
    get account_root_path
    expect(Nokogiri::HTML(response.body).at_css('link[rel="apple-touch-icon"]')["href"]).to eq("/icon-192.png")
    sign_in create(:user, :admin)
    get admin_root_path
    expect(Nokogiri::HTML(response.body).at_css('link[rel="icon"][type="image/svg+xml"]')["href"]).to eq("/icon.svg")
  end

  it "binds menu buttons and panels to their controllers and includes mobile city links" do
    business = create(:business)
    sign_in create(:user)
    get root_path
    html = Nokogiri::HTML(response.body)
    header = html.at_css('header[data-controller="mobile-menu"]')
    button = header.at_css('[data-mobile-menu-target="button"]')
    panel = header.at_css('[data-mobile-menu-target="menu"]')
    expect(button["aria-controls"]).to eq(panel["id"])
    expect(button["aria-expanded"]).to eq("false")
    expect(panel.css("a").map { |link| link["href"] }).to include(city_path(business.city.slug))
    expect(header.css('[data-controller="dropdown"]').size).to eq(3)
    header.css('[data-controller="dropdown"]').each do |dropdown|
      toggle = dropdown.at_css('[data-dropdown-target="button"]')
      menu = dropdown.at_css('[data-dropdown-target="menu"]')
      expect(toggle["aria-controls"]).to eq(menu["id"])
      expect(toggle["aria-expanded"]).to eq("false")
      expect(menu["class"].split).to include("hidden")
    end
  end
end
