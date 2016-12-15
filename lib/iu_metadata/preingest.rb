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
  end
end
