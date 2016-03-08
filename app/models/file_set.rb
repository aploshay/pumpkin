# Generated by curation_concerns:models:install
class FileSet < ActiveFedora::Base
  include ::CurationConcerns::FileSetBehavior
  Hydra::Derivatives.output_file_service = PersistPairtreeDerivatives

  apply_schema IIIFPageSchema, ActiveFedora::SchemaIndexingStrategy.new(
    ActiveFedora::Indexers::GlobalIndexer.new([:stored_searchable, :symbol])
  )

  validates_with ViewingHintValidator

  def self.image_mime_types
    []
  end

  def iiif_path
    IIIFPath.new(id).to_s
  end

  def create_derivatives(filename)
    case original_file.mime_type
    when 'image/tiff'
      Hydra::Derivatives::Jpeg2kImageDerivatives.create(
        filename,
        outputs: [
          label: 'intermediate_file',
          service: {
            datastream: 'intermediate_file',
            recipe: :default
          },
          url: derivative_url('intermediate_file')
        ]
      )
      OCRRunner.new(self).from_file(filename)
    end
    super
  end

  def to_solr(solr_doc = {})
    super.tap do |doc|
      doc["full_text_tesim"] = ocr_text if ocr_text.present?
    end
  end

  private

    def ocr_file
      derivative_url('ocr')
    end

    def ocr_text
      return unless persisted? && File.exist?(ocr_file.gsub("file:", ""))
      file = File.open(ocr_file.gsub("file:", ""))
      ocr_doc = HOCRDocument.new(file)
      ocr_doc.text.strip
    end

    # The destination_name parameter has to match up with the file parameter
    # passed to the DownloadsController
    def derivative_url(destination_name)
      path = PairtreeDerivativePath.derivative_path_for_reference(self, destination_name)
      URI("file://#{path}").to_s
    end
end
