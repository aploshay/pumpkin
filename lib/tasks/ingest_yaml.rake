namespace :pmp do
  desc "Ingest one or more YAML files"
  task ingest_yaml: :environment do
    logger = Logger.new(STDOUT)
    IngestYAMLJob.logger = logger
    logger.info "ingesting .yml files from: #{ARGV[1]}"
    abort "usage: rake ingest_yaml /path/to/yaml/files" unless ARGV[1] && Dir.exist?(ARGV[1])
    Dir["#{ARGV[1]}/**/*.yml"].each do |file|
      begin
        IngestYAMLJob.perform_now(file, user)
      rescue => e
        puts "Error: #{e.message}"
        puts e.backtrace
      end
    end
  end
end
