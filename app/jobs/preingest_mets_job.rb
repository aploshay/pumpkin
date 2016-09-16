class PreingestMETSJob < ActiveJob::Base
  queue_as :preingest

  # @param [String] mets_file Filename of a METS file to ingest
  # @param [String] user User to ingest as
  # @param [Array<String>] collections Collection IDs the resources should be members of
  def perform(mets_file, user, collections = [])
    logger.info "Preingesting METS #{mets_file}"
    @mets = METSDocument.new mets_file
    @user = user
    @collections = collections.map { |col_id| Collection.find(col_id) }

    preingest
  end

  private

    def preingest
      yaml_hash = {}
      { identifier: :ark_id,
        replaces: :pudl_id,
        source_metadata_identifier: :bib_id,
        viewing_direction: :viewing_direction,
        thumbnail_path: :thumbnail_path
      }.each do |att, mets_method|
        yaml_hash[att] = @mets.send(mets_method)
      end
      if @mets.multi_volume?
        yaml_hash[:volumes] = []
        @mets.volume_ids.each do |volume_id|
          volume_hash = {}
          volume_hash[:id] = volume_id
          volume_hash[:title] = [@mets.label_for_volume(volume_id)]
          volume_hash[:structure] = @mets.structure_for_volume(volume_id)
          volume_hash[:files] = add_file_attributes(@mets.files_for_volume(volume_id))
          yaml_hash[:volumes] << volume_hash
        end
      else
        yaml_hash[:structure] = @mets.structure
        yaml_hash[:files] = add_file_attributes(@mets.files)
      end
      yaml_hash[:source] = {}
      yaml_hash[:source][:title] = ['METS XML']
      yaml_hash[:source][:file] = @mets.source_file
      yaml_file = @mets.source_file.sub(/\.mets$/, '.yml')
      File.write(yaml_file, yaml_hash.to_yaml)
      logger.info "Created YAML file #{File.basename(yaml_file)}"
    end

    def add_file_attributes(file_hash_array)
      file_hash_array.each do |f|
        f[:title] = [@mets.file_label(f[:id])]
        f[:replaces] = "#{@mets.pudl_id}/#{File.basename(f[:path], File.extname(f[:path]))}"
        f[:file_opts] = @mets.file_opts(f)
      end
      file_hash_array
    end
end
