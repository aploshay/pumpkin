class PreingestableMETS
  include PreingestableDocument
  FILE_PATTERN = '*.mets'

  def initialize(source_file)
    @source_file = source_file
    @local = IuMetadata::METSRecord.new('file://' + source_file, open(source_file))
    @source_title = ['METS XML']
  end
  attr_reader :source_file, :source_title, :local

  def local_attributes
    local.attributes
  end

  delegate :id, to: :local
  delegate :source_metadata_identifier, to: :local
  delegate :multi_volume?, :collections, to: :local
  delegate :files, :structure, :volumes, :thumbnail_path, to: :local
end
