require "base64"
require "stringio"

User.create!(email: "backup@example.invalid", name: "Backup Verification", password: "verification-password123")
png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1kAAAAASUVORK5CYII=")
blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "backup.png", content_type: "image/png")
File.write("/rails/tmp/backup-fixture-key", blob.key)
