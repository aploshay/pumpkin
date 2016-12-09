namespace :pmp do
  desc "Preingest a file into ingest yaml, using the specified preingest pipeline"
  task :preingest, [:document_type] => :environment do |task, args|
    file = ARGV[1]
    abort "usage: rake preingest[document_type] /path/to/preingest/file" unless args.document_type && file
    begin
      document_class = "IuMetadata::Preingest::#{args.document_type.titleize}".constantize
    rescue
      abort "unknown preingest pipeline: #{args.document_type}"
    end
    user = User.find_by_user_key( ENV['USER'] ) if ENV['USER']
    user = User.all.select{ |u| u.admin? }.first unless user
    state = ENV['STATE']

    logger = Logger.new(STDOUT)
    PreingestJob.logger = logger
    logger.info "preingesting file: #{file}"
    logger.info "preingesting as: #{user.user_key} (override with USER=foo)"
    if state
      logger.info "forcing state: #{state}"
    else
      logger.info "using default state (override with STATE=foo)"
    end
    if Dir.exists?(file)
      abort "Directory given instead of file: #{file}"
    elsif !File.exists?(file)
      abort "File not found: #{file}"
    else
      begin
        PreingestJob.perform_now(document_class, file, user, state)
      rescue => e
        logger.info "Error: #{e.message}"
        logger.info e.backtrace
        abort "Error encountered"
      end
    end
  end
end
