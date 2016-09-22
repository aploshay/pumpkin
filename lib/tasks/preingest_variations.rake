desc "Preingest one or more Variations files"
task preingest_variations: :environment do
  user = User.find_by_user_key( ENV['USER'] ) if ENV['USER']
  user = User.all.select{ |u| u.admin? }.first unless user

  collections = (ENV['COLLECTIONS'] || "").split(" ")

  logger = Logger.new(STDOUT)
  PreingestVariationsJob.logger = logger
  logger.info "preingesting xml files from: #{ARGV[1]}"
  logger.info "preingesting as: #{user.user_key} (override with USER=foo)"
  abort "usage: rake ingest_variations /path/to/xml/files" unless ARGV[1] && Dir.exist?(ARGV[1])
  Dir["#{ARGV[1]}/**/*.xml"].each do |file|
    begin
      PreingestVariationsJob.perform_now(file, user, collections)
    rescue => e
      puts "Error: #{e.message}"
      puts e.backtrace
    end
  end
end
