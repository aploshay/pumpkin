module IuMetadata
  module Preingest
    class Varaccomp
      include PreingestableDocument

      def initialize(source_file)
        @source_file = source_file
        id = source_file.sub(/.*\//, '').sub(/.xml/, '').upcase
        files = []
        (1..300).each do |i|
          files << { id: "#{id}-1-#{i.to_s.rjust(4, '0')}.tif",
            mime_type: 'image/tiff',
            path: "/tmp/ingest/#{id}-1-#{i.to_s.rjust(4, '0')}.tif",
            attributes: { title: ['FIXME: title missing'],
              source_metadata_identifier: "#{id}-1-#{i.to_s.rjust(4, '0')}".upcase
              }
            }
        end
        @local = IuMetadata::VariationsRecord.new(source_uri, open(source_file), files: files, variations_type: 'AccompanyingMaterials')
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
  end
end
