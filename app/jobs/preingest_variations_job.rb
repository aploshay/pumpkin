class PreingestVariationsJob < ActiveJob::Base
  queue_as :preingest

  # @param [String] variations_file Filename of a Variations file to ingest
  # @param [String] user User to ingest as
  # @param [Array<String>] collections Collection IDs the resources should be members of
  def perform(variations_file, user, collections = [])
    logger.info "Preingesting Variations score #{variations_file}"
    @variations_file = variations_file
    @variations = Nokogiri::XML(File.read(variations_file))
    @user = user
    @collections = collections.map { |col_id| Collection.find(col_id) }

    preingest
  end

  private

    def preingest
      yaml_hash = {}
      # get simple attributes
      yaml_hash[:identifier] = 'identifier'
      yaml_hash[:replaces] = 'replaces'
      yaml_hash[:source_metadata_identifier] = @variations.xpath('//MediaObject/Label').first.content.to_s
      yaml_hash[:viewing_direction] = 'right-to-left'
      yaml_hash[:thumbnail_path] = ''

      # get files list
      @files = []
      @variations.xpath('//FileInfos/FileInfo').each do |file|
        file_hash = {}
        file_hash[:id] = file.xpath('FileName').first&.content.to_s
        file_hash[:checksum] = file.xpath('Checksum').first&.content.to_s
        file_hash[:mime_type] = 'image/tiff'
        file_hash[:path] = '/tmp/MS-METS/bhr9405/' + file_hash[:id]
        file_hash[:title] = ['TITLE MISSING'] # replaced later
        file_hash[:replaces] = 'replaces'
        file_hash[:file_opts] = {}
        @files << file_hash
      end
      yaml_hash[:thumbnail_path] = @files.first[:path]

      # assign structure hash and files array
      @file_index = 0
      items = @variations.xpath('/ScoreAccessPage/RecordSet/Container/Structure/Item')
      if items.size < 2
        s_root = @variations.xpath('/ScoreAccessPage/RecordSet/Container/Structure/Item').first
        yaml_hash[:structure] = {}
        yaml_hash[:structure][:nodes] = structure_to_array(s_root)
        yaml_hash[:files] = @files
      else
        yaml_hash[:volumes] = []
        @file_start = 0
        items.each do |item|
          volume = {}
          volume[:id] = 'ID GOES HERE'
          volume[:title] = [item['label']]
          volume[:nodes] = structure_to_array(item)
          volume[:files] = @files[@file_start, @file_index - @file_start]
          @file_start = @file_index
          yaml_hash[:volumes] << volume
        end
      end

      yaml_hash[:source] = {}
      yaml_hash[:source][:title] = ['Variations XML']
      yaml_hash[:source][:file] = @variations_file

      yaml_file = @variations_file.sub(/\.xml$/, '.yml')
      File.write(yaml_file, yaml_hash.to_yaml)
      logger.info "Created YAML file #{File.basename(yaml_file)}"
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
