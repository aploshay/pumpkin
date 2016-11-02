# rubocop:disable Metrics/ClassLength
class VariationsDocument
  include PreingestableDocument
  FILE_PATTERN = '*.xml'

  def initialize(source_file)
    @source_file = source_file
    @variations = File.open(@source_file) { |f| Nokogiri::XML(f) }
    @source_title = ['Variations XML']
    parse
  end

  attr_reader :source_file, :source_title
  attr_reader :files, :structure, :volumes, :thumbnail_path

  def yaml_file
    source_file.sub(/\.xml$/, '.yml')
  end

  def multi_volume?
    items.size > 1
  end

  def default_attributes
    { state: state, viewing_direction: viewing_direction,
      visibility: visibility, rights_statement: rights_statement }
  end

  def state
    'final_review'
  end

  def viewing_direction
    'left-to-right'
  end

  def visibility
    if holding_status == 'Publicly available'
      Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    elsif holding_location == 'Personal Collection'
      Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    else
      Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
    end
  end

  # FIXME: write logic to select?
  def rights_statement
    'http://rightsstatements.org/vocab/InC/1.0/'
  end

  def local_attributes
    { source_metadata_identifier: source_metadata_identifier,
      identifier: identifier,
      holding_location: holding_location,
      media: media,
      copyright_holder: copyright_holder
    }
  end

  def source_metadata_identifier
    @variations.xpath('//MediaObject/Label').first&.content.to_s
  end

  def media
    @variations.xpath("//Container/DocumentInfos/DocumentInfo[Type='Score']/Description").first&.content.to_s
  end

  def holding_location
    case location
    when 'IU Music Library'
      'https://libraries.indiana.edu/music'
    # FIXME: handle 'Personal Collection' case
    when 'Personal Collection'
      ''
    # FIXME: abstract to loop through digital_locations?
    else
      ''
    end
  end

  # OTHER METHODS
  def identifier
    purl
  end

  def purl
    'http://purl.dlib.indiana.edu/iudl/variations/score/' + source_metadata_identifier
  end

  def location
    @variations.xpath('//Container/PhysicalID/Location').first&.content.to_s
  end

  # FIXME: pull into related url?
  # FIXME: email librarians about location
  def html_page_status
    @variations.xpath('/ScoreAccessPage/HtmlPageStatus').first&.content.to_s
  end

  # FIXME: [Domain='Item'] check does not work; also, do we want to allow Container? see abe
  def copyright_holder
    # @variations.xpath("//Container/CopyrightDecls/CopyrightDecl[Domain='Item']/Owner").first&.content.to_s
    @variations.xpath("//Container/CopyrightDecls/CopyrightDecl/Owner").first&.content.to_s
  end

  def holding_status
    @variations.xpath('//Container/HoldingStatus').first&.content.to_s
  end

  private

    def items
      @items ||= @variations.xpath('/ScoreAccessPage/RecordSet/Container/Structure/Item')
    end

    def parse
      @files = []
      @variations.xpath('//FileInfos/FileInfo').each do |file|
        file_hash = {}
        file_hash[:id] = file.xpath('FileName').first&.content.to_s
        file_hash[:mime_type] = 'image/tiff'
        file_hash[:path] = '/tmp/ingest/' + file_hash[:id]
        file_hash[:title] = ['TITLE MISSING'] # replaced later
        file_hash[:file_opts] = {}
        @files << file_hash
      end
      @thumbnail_path = @files.first[:path]

      # assign structure hash and update files array with titles
      @file_index = 0
      if multi_volume?
        @volumes = []
        @file_start = 0
        items.each do |item|
          volume = {}
          volume[:title] = [item['label']]
          volume[:structure] = { nodes: structure_to_array(item) }
          volume[:files] = @files[@file_start, @file_index - @file_start]
          @file_start = @file_index
          @volumes << volume
        end
      else
        @structure = { nodes: structure_to_array(items.first) }
      end
    end

    # builds structure hash AND update file list with titles
    def structure_to_array(xml_node)
      array = []
      xml_node.xpath('child::*').each do |child|
        c = {}
        if child.name == 'Div'
          c[:label] = child['label']
          c[:nodes] = structure_to_array(child)
        elsif child.name == 'Chunk'
          c[:label] = child['label']
          c[:proxy] = @files[@file_index][:id]

          @files[@file_index][:title] = [child['label']]
          @file_index += 1
        end
        array << c
      end
      array
    end
end
# rubocop:enable Metrics/ClassLength
