class PreingestJob < ActiveJob::Base
  queue_as :preingest

  # @param [Class] document_class Class of preingestable document wrapper
  # @param [String] preingest_file Filename of a preingest file to preingest
  # @param [String] user User to ingest as
  # @param [Array<String>] collections Collection slugs the resources should be members of
  def perform(document_class, preingest_file, user, collections = [])
    logger.info "Preingesting #{document_class} #{preingest_file}"
    @document = document_class.new preingest_file
    @user = user
    @collections = collections

    preingest
  end

  private

    def preingest
      yaml_hash = {}
      yaml_hash[:resource] = @document.resource_class.to_s
      yaml_hash[:attributes] = @document.attributes
      yaml_hash[:source_metadata] = @document.source_metadata
      yaml_hash[:thumbnail_path] = @document.thumbnail_path
      yaml_hash[:sources] = [{ title: @document.source_title, file: @document.source_file }]
      yaml_hash[:collection_slugs] = @document.collection_slugs(@collections)

      if @document.multi_volume?
        yaml_hash[:volumes] = @document.volumes
      else
        yaml_hash[:structure] = @document.structure
        yaml_hash[:files] = @document.files
      end


      File.write(@document.yaml_file, yaml_hash.to_yaml)
      logger.info "Created YAML file #{File.basename(@document.yaml_file)}"
    end
end
