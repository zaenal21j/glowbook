# Compile PNG exports from the same vector mark used by the website.
# Run: bundle exec ruby script/render_pwa_icons.rb
require "vips"

root = File.expand_path("..", __dir__)
source = Vips::Image.svgload(File.join(root, "public/icon.svg"))
{ "icon.png" => 512, "icon-192.png" => 192 }.each do |filename, size|
  source.resize(size.to_f / source.width).pngsave(File.join(root, "public", filename))
end
