# rubocop:disable Metrics/ClassLength
module IuMetadata
  class VariationsRecord
    # files: array of filenames, if providing directly
    def initialize(id, source, files: [], structure: nil, variations_type: 'ScoreAccessPage', logger: nil, files_source: '/tmp/ingest/')
      @id = id
      @source = source
      @variations = Nokogiri::XML(source)
      @files = files
      @structure = structure
      @variations_type = variations_type
      @logger = logger
      @files_source = (files_source || '/tmp/ingest/')
      parse
    end
    attr_reader :id, :source

    # standard metadata
    ATTRIBUTES = [:source_metadata_identifier, :holding_location, :physical_description, :copyright_holder]
    def attributes
      Hash[ATTRIBUTES.map { |att| [att, send(att)] }]
    end

    def source_metadata_identifier
      @variations.xpath('//MediaObject/Label').first.content.to_s[0...7].upcase
    end

    def holding_location
      case location
      when 'IU Music Library'
        'https://libraries.indiana.edu/music'
      when 'Personal Collection'
        ''
      # FIXME: abstract to loop through digital_locations?
      else
        ''
      end
    end

    def physical_description
      @variations.xpath("//Container/DocumentInfos/DocumentInfo[Type='Score']/Description").first&.content.to_s
    end

    def copyright_holder
      @variations.xpath("//Container/CopyrightDecls/CopyrightDecl/Owner").map(&:content)
    end

    # default metadata
    DEFAULT_ATTRIBUTES = [:visibility, :rights_statement, :viewing_hint]
    def default_attributes
      Hash[DEFAULT_ATTRIBUTES.map { |att| [att, send(att)] }]
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

    def rights_statement
      'http://rightsstatements.org/vocab/InC/1.0/'
    end

    def viewing_hint
      'paged'
    end

    # ingest metadata
    attr_reader :files, :structure, :volumes, :thumbnail_path

    def multi_volume?
      items.size > 1
    end

    def collections
      return ['libmus_personal'] if location == 'Personal Collection'
      []
    end

    private

      def holding_status
        @variations.xpath('//Container/HoldingStatus').first&.content.to_s
      end

      def location
        @variations.xpath('//Container/PhysicalID/Location').first&.content.to_s
      end

      def items
        @items ||= @variations.xpath("//#{@variations_type}/RecordSet/Container/Structure/Item")
      end

      def variations_files
        @variations_files ||= @variations.xpath('//FileInfos/FileInfo').map { |file| file_hash(filename(file)) }
      end

      def parse
        # use array of filenames, if provided
        if @files.any?
          @files = @files.map { |filename| file_hash(filename) }
          if @variations_type == 'ScoreAccessPage' && @logger
            case @files.size <=> variations_files.size
            when 1
              #FIXME: log
              @logger.info "More files found on server (#{@files.size}) than specified in XML (#{variations_files.size})"
              @logger.info "Retaining structure, but there will be extra unused images"
            when 0
              if @files == variations_files
                @logger.info "Files found on server match specifiction in XML"
                # FIXME: log
              else
                @logger.info "Files found on server don't match those specified in XML"
                @logger.info "Retaining structure, but it should undergo review"
                # FIXME: log
              end
            when -1
              #FIXME: log
              @logger.info "Fewer files found on server (#{@files.size}) than specified in XML (#{variations_files.size})"
              @logger.info "Abandoning structure"
              @structure = {}
            end
          end
        end
        # FIXME: crosscheck expected, actual files
        @thumbnail_path = (@files.any? ? @files.first[:path] : nil)

        # assign structure hash and update files array with titles
        @file_index = 0
        if multi_volume?
          @volumes = []
          @file_start = 0
          items.each do |item|
            volume = {}
            volume[:title] = [item['label']]
            volume[:structure] = begin
              if files.none?
                {}
              elsif @structure
                @structure
              else
                { nodes: structure_to_array(item) }
              end
            end
            volume[:files] = @files[@file_start, @file_index - @file_start]
            if @structure
              volume[:files].each_with_index { |file, i| [:attributes][:title] = [(i + 1).to_s] }
            end
            @file_start = @file_index
            @volumes << volume
          end
        else
          if @files.none?
            @structure = {}
            # FIXME: log structure drop
          elsif @structure
            @files.each_with_index { |file, i| file[:attributes][:title] = [(i + 1).to_s] }
          else
            @structure = { nodes: structure_to_array(items.first) }
          end
        end
      end

      # builds structure hash AND update file list with titles
      def structure_to_array(xml_node)
        # FIXME: try/rescue block with logging
        array = []
        xml_node.xpath('child::*').each do |child|
          c = {}
          if child.name == 'Div'
            c[:label] = child['label']
            c[:nodes] = structure_to_array(child)
          elsif child.name == 'Chunk'
            c[:label] = child['label']
            c[:proxy] = @files[@file_index][:id]

            @files[@file_index][:attributes][:title] = [child['label']]
            @file_index += 1
          end
          array << c
        end
        array
      end

      def file_hash(id)
        fixed_id = id.sub('_accmat', '').sub('_booklet', '')
        values_hash = {}
        values_hash[:id] = fixed_id
        values_hash[:mime_type] = 'image/tiff'
        values_hash[:path] = @files_source + id
        values_hash[:file_opts] = {}
        values_hash[:attributes] = file_attributes(fixed_id)
        values_hash
      end

      def filename(file_node)
        normalized = file_node.xpath('FileName').first&.content.to_s.downcase.sub(/\.\w{3,4}/, '')
        if normalized.match(/^\d+$/)
          root = source_metadata_identifier.downcase
          volume = 1
          page = normalized
        else
          root, volume, page = normalized.split('-')
        end
        "#{root}-#{volume.to_i}-#{page.rjust(4, '0')}.tif"
      end

      def file_attributes(id)
        att_hash = {}
        att_hash[:title] = ['TITLE MISSING'] # replaced later
        att_hash[:source_metadata_identifier] = id.gsub(/\.\w{3,4}$/, '').upcase
        att_hash
      end
  end
end
# rubocop:enable RSpec/DescribeClass
