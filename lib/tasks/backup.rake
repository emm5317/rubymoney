namespace :db do
  desc "Backup the database to db/backups/ with timestamped filename"
  task backup: :environment do
    backup_dir = Rails.root.join("db", "backups")
    FileUtils.mkdir_p(backup_dir)

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    filename = backup_dir.join("rubymoney_#{timestamp}.sql.gz")

    db_url = ENV.fetch("DATABASE_URL")
    uri = URI.parse(db_url)

    env = {}
    env["PGPASSWORD"] = uri.password if uri.password

    host = uri.host || "localhost"
    port = uri.port || 5432
    database = uri.path.sub(%r{^/}, "")
    user = uri.user

    cmd = "pg_dump -h #{host} -p #{port}"
    cmd += " -U #{user}" if user
    cmd += " #{database} | gzip > #{filename}"

    puts "Backing up database to #{filename}..."
    success = system(env, cmd)

    if success
      puts "Backup completed: #{filename}"

      # Rotate: delete backups older than 30 days
      cutoff = 30.days.ago
      Dir.glob(backup_dir.join("rubymoney_*.sql.gz")).each do |file|
        if File.mtime(file) < cutoff
          File.delete(file)
          puts "Deleted old backup: #{File.basename(file)}"
        end
      end
    else
      puts "Backup failed!"
      exit 1
    end
  end
end
