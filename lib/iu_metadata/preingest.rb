module IuMetadata
  module Preingest
    class Variations
      include PreingestableDocument

      def initialize(source_file)
        @source_file = source_file
        @files ||= []
        @structure ||= nil
        @variations_type ||= 'ScoreAccessPage'
        @local = IuMetadata::VariationsRecord.new(source_uri, open(source_file), files: @files, structure: @structure, variations_type: @variations_type)
        @source_title = ['Variations XML']
      end
      attr_reader :source_file, :source_title, :local

      def default_attributes
        super.merge(local.default_attributes)
      end

      delegate :source_metadata_identifier, to: :local
      delegate :multi_volume?, :collections, to: :local
      delegate :files, :structure, :volumes, :thumbnail_path, to: :local
    end

    class VariationsAccompanying < Variations
      def initialize(source_file)
        id = source_file.sub(/.*\//, '').sub(/.xml/, '').downcase
        images_by_id = YAML.load_file(Rails.root.join('config/images_by_id.yml'))
        @files = images_by_id[id]
        @variations_type = 'AccompanyingMaterials'
        super
      end
    end

    class VariationsWithoutRemote < Variations
      def attribute_sources
        result = super
        result.delete(:remote)
        result
      end
      def remote_data
        nil
      end
    end

    class VariationsWithoutStructure < Variations
      def initialize(source_file)
        @structure = {}
        super
      end
    end

    class VariationsAccompanyingWithoutStructure < VariationsAccompanying
      def initialize(source_file)
        @structure = {}
        super
      end
    end

#FIXME: without xml case -- add source_metadata_identifier to default or local atts -- or pull from remote if available?
#FIXME: also add identifier when no remote?
#FIXME: also add title lookup when no remote?
    class VariationsWithoutXml
      include PreingestableDocument

      def initialize(source_file)
        @source_file = source_file
        @files ||= []
        @structure ||= nil
        @variations_type ||= 'ScoreAccessPage'
        @local = nil
        @source_title = nil

        id = source_file.sub(/.*\//, '').sub(/.xml/, '').downcase
        images_by_id = YAML.load_file(Rails.root.join('config/images_by_id.yml'))
        @files = images_by_id[id]
        # FIXME: catch for missing images
        @files ||= []
        @structure = {}
      end
      attr_reader :source_file, :source_title, :local

      def source_metadata_identifier
        source_file.sub(/.*\//, '').sub(/.xml/, '').upcase
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
      def attribute_sources
        { default: default_data,
          remote: remote_data
        }
      end
    end
    class VariationsWithoutXmlWithoutRemote < VariationsWithoutXml
      def attribute_sources
        { default: default_data }
      end
      def remote_data
        nil
      end
    end

  end
end
