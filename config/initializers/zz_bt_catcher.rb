# TEMPORARY debug middleware: dumps full backtrace of any exception to /tmp/bt.txt
class BtCatcher
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue Exception => e
    File.write("/tmp/bt.txt", "#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}")
    raise
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::DebugExceptions, BtCatcher
