# Run with: bin/rails runner script/check_release.rb
# Static release checks complement the request and model specs.
sources = Dir.glob("app/{controllers,helpers,mailers,models,services}/**/*.rb")
views = Dir.glob("app/views/**/*.erb")
sources.each { |path| RubyVM::InstructionSequence.compile_file(path) }

handler = ActionView::Template.handler_for_extension("erb")
views.each do |path|
  format = path.end_with?(".text.erb") ? :text : :html
  template = ActionView::Template.new(File.read(path), path, handler, locals: [], format: format)
  template.send(:compile, Module.new)
end

keys = (sources + views).flat_map do |path|
  File.read(path).scan(/\b(?:I18n\.)?t\(\s*["']([^"']+)["']/).flatten
end.uniq.reject { |key| key.include?('#{') || key.start_with?(".") }
missing = keys.flat_map do |key|
  %i[id en].filter_map { |locale| "#{locale}:#{key}" unless I18n.exists?(key, locale: locale, fallback: false) }
end
abort "Missing translations:\n#{missing.join("\n")}" if missing.any?

actions = Rails.application.routes.routes.filter_map do |route|
  controller = route.defaults[:controller]
  action = route.defaults[:action]
  [controller, action] if controller && action
end.uniq
invalid = actions.filter_map do |name, action|
  controller = "#{name.camelize}Controller".safe_constantize
  "#{name}##{action}" unless controller && controller.action_methods.include?(action.to_s)
end
abort "Missing route actions:\n#{invalid.join("\n")}" if invalid.any?

registered_controllers = File.read("app/javascript/controllers/index.js").scan(/application\.register\(["']([^"']+)["']/).flatten
referenced_controllers = views.flat_map do |path|
  source = File.read(path)
  source.scan(/data-controller=["']([^"']+)["']/).flatten.flat_map(&:split) +
    source.scan(/data-action=["']([^"']+)["']/).flatten.flat_map { |action| action.scan(/([a-z][a-z0-9-]*)#/).flatten }
end.uniq
unregistered = referenced_controllers - registered_controllers
abort "Unregistered Stimulus controllers:\n#{unregistered.join("\n")}" if unregistered.any?

puts({ ruby_files: sources.size, erb_templates: views.size, static_translation_keys: keys.size,
       locales: %w[id en], route_actions: actions.size, stimulus_controllers: registered_controllers.size, result: "passed" }.to_json)
