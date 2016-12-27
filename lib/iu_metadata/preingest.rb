module IuMetadata
  module Preingest
    class Variations
      include PreingestableDocument

      def initialize(source_file)
        @source_file = source_file
        @files ||= []
        @structure ||= nil
        # determine XML type
        # local: pull if available
        # DONE remote: try pulling, fail to empty
        # files cases: complicated!!!
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
          files_source = 'scores-fixed'
        elsif files_lookup = scores_from_other_sources[lookup_id]
          files_source = 'scores_from_other_sources'
          @structure = {}
        else
          files_lookup = []
          files_source = nil
        end

        case @variations_type
        when 'blank'
          @files = files_lookup
          @structure = {}
          @local = EmptyRecord.new(source_file, @files, @structure)
          @source_title = nil
        when 'AccompanyingMaterials'
          @files = files_lookup
          @local = IuMetadata::VariationsRecord.new(source_uri, open(source_file), files: @files, structure: @structure, variations_type: @variations_type)
          @source_title = ['Variations XML']
        when 'ScoreAccessPage'
          # FIXME: check files
          @local = IuMetadata::VariationsRecord.new(source_uri, open(source_file), files: @files, structure: @structure, variations_type: @variations_type)
          @source_title = ['Variations XML']
        end
        # FIXME: catch case of file list different from provided
        # FIXME: catch case of structure has more keys than files
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

#FIXME: without xml case -- add source_metadata_identifier to default or local atts -- or pull from remote if available?
#FIXME: also add identifier when no remote?
#FIXME: also add title lookup when no remote?
    class EmptyRecord

      def initialize(source_file, files, structure)
        @source_file = source_file
        @files = files
        @structure = structure
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
            path: "/tmp/ingest/#{filename}",
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
        nil
      end

      def attributes
        {}
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
