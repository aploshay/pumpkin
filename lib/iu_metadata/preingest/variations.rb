module IuMetadata
  module Preingest
    class Variations
      include PreingestableDocument

      def initialize(source_file, logger: nil)
        @source_file = source_file
        @files ||= []
        @structure ||= nil
        # local: pull title
        # add logging

        variations_content = File.read(source_file)
        if variations_content.blank?
          @variations_type = 'blank'
        elsif Nokogiri::XML(variations_content).xpath('//ScoreAccessPage').size.zero?
          @variations_type = 'AccompanyingMaterials'
        else
          @variations_type = 'ScoreAccessPage'
        end

        lookup_id = source_file.sub(/.*\//, '').sub(/.xml/, '').downcase
        scores_fixed = YAML.load_file(Rails.root.join('config/scores-fixed.yml'))
        scores_from_other_sources = YAML.load_file(Rails.root.join('config/scores_from_other_sources.yml'))
        if files_lookup = scores_fixed[lookup_id]
          suffix = '_accmat' if @variations_type == 'AccompanyingMaterials'
          suffix = '_booklet' if lookup_id == 'vab7222'
          suffix ||= ''
          files_source = "/N/beryllium/srv/variations/scores-fixed/#{lookup_id}#{suffix}/"
        elsif files_lookup = scores_from_other_sources[lookup_id]
          files_source = "/N/beryllium/srv/variations/scores_from_other_sources/digitize/image/#{lookup_id}/"
          @structure = {}
        else
          files_lookup = []
          files_source = nil
          @structure = {}
        end

        case @variations_type
        when 'blank'
          @files = files_lookup
          @structure = {}
          @local = EmptyRecord.new(source_file, @files, @structure, logger: logger, files_source: files_source)
          @source_title = nil
        when 'AccompanyingMaterials'
          @files = files_lookup
          @local = IuMetadata::VariationsRecord.new(source_uri, open(source_file), files: @files, structure: @structure, variations_type: @variations_type, logger: logger, files_source: files_source)
          @source_title = ['Variations XML']
        when 'ScoreAccessPage'
          # FIXME: check files
          @files = files_lookup
          @local = IuMetadata::VariationsRecord.new(source_uri, open(source_file), files: @files, structure: @structure, variations_type: @variations_type, logger: logger, files_source: files_source)
          @source_title = ['Variations XML']
        end

        if logger
          logger.info("#{@local.source_metadata_identifier}: Variations XML type: #{@variations_type}")
          logger.info("#{@local.source_metadata_identifier}: Image files source: #{files_source || '(none)'}")
          logger.info("#{@local.source_metadata_identifier}: Specifying empty structure due to lack of image files") if files_lookup.empty?
          logger.info("#{@local.source_metadata_identifier}: Specifying empty structure due to files coming from scores_from_other_sources folder") if files_source.to_s.match /other/
          logger.info("#{@local.source_metadata_identifier}: Specifying empty structure for XML type: blank") if @variations_type == 'blank'
        end
        # FIXME: catch case of structure has FEWER Keys than files
      end
      attr_reader :source_file, :source_title, :local

      def default_attributes
        super.merge(local.default_attributes)
      end

      delegate :source_metadata_identifier, to: :local
      delegate :multi_volume?, :collections, to: :local
      delegate :files, :structure, :volumes, :thumbnail_path, to: :local
    end

    class EmptyRecord

      def initialize(source_file, files, structure, logger: nil, files_source: '/tmp/ingest/')
        @source_file = source_file
        @files = files
        @structure = structure
        @logger = logger
        @files_source = files_source
      end

      def source_metadata_identifier
        @source_file.sub(/.*\//, '').sub(/.xml/, '').upcase[0...7]
      end

      def multi_volume?
        false
      end

      def collections
        []
      end

      def files
        index = 0
        @files.map do |filename|
          { id: filename,
            mime_type: 'image/tiff',
            path: @files_source + filename,
            file_opts: {},
            attributes: { title: (index += 1).to_s, source_metadata_identifier: filename.sub(/\.tif.*$/, '').upcase }
          }
        end
      end

      def structure
        @structure
      end

      def volumes
        []
      end

      def thumbnail_path
        @thumbnail_path ||= @files.any? ? files.first[:path] : nil
      end

      def attributes
        { source_metadata_identifier: source_metadata_identifier }
      end

      def default_attributes
        {
          state: 'final_review',
          viewing_direction: 'left-to-right',
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
          visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
        }
      end
    end
  end
end
