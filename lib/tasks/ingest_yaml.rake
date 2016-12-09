namespace :pmp do
  desc "Ingest a YAML file"
  task ingest: :environment do
    logger = Logger.new(STDOUT)
    IngestYAMLJob.logger = logger
    file = ARGV[1]
    logger.info "ingesting file: #{file}"
    abort "usage: rake pmp:ingest /path/to/yaml_file" unless file
    if Dir.exists?(file)
      abort "Directory given instead of file: #{file}"
    elsif !File.exists?(file)
      abort "File not found: #{file}"
    else
      begin
        IngestYAMLJob.perform_now(file, user)
      rescue => e
        logger.info "Error: #{e.message}"
        logger.info e.backtrace
        abort "Error encountered"
      end
    end
  end
end
