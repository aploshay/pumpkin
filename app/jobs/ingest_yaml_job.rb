class IngestYAMLJob < ActiveJob::Base
  queue_as :ingest

  # @param [String] yaml_file Filename of a YAML file to ingest
  # @param [String] user User to ingest as
  # @param [Array<String>] collections Collection IDs the resources should be members of
  def perform(yaml_file, user, collections = [])
    logger.info "Ingesting YAML #{yaml_file}"
    @yaml_file = yaml_file
    @yaml = File.open(yaml_file) { |f| Psych.load(f) }
    @user = user
    @collections = collections.map { |col_id| Collection.find(col_id) }

    ingest
  end

  private

    def ingest
      resource = (@yaml[:volumes].present? ? MultiVolumeWork : ScannedResource).new
      if @yaml[:attributes].present?
        @yaml[:attributes].each { |_set_name, attributes| resource.attributes = attributes }
      end
      resource.source_metadata = @yaml[:source_metadata] if @yaml[:source_metadata].present?

      resource.apply_depositor_metadata @user
      resource.member_of_collections = @collections

      resource.save!
      logger.info "Created #{resource.class}: #{resource.id}"

      attach_sources resource

      if @yaml[:volumes].present?
        ingest_volumes(resource)
      else
        ingest_files(resource: resource, files: @yaml[:files]) if @yaml[:files].present?
        resource.logical_order.order = map_fileids(@yaml[:structure]) if @yaml[:structure].present?
        resource.save!
      end
    end

    def attach_sources(resource)
      return unless @yaml[:sources].present?
      @yaml[:sources].each do |source|
        attach_source(resource, source[:title], source[:file])
      end
    end

    def attach_source(resource, title, file)
      file_set = FileSet.new
      file_set.title = title
      actor = FileSetActor.new(file_set, @user)
      actor.attach_related_object(resource)
      actor.attach_content(File.open(file, 'r:UTF-8'))
    end

    def ingest_volumes(parent)
      @yaml[:volumes].each do |volume|
        r = ScannedResource.new
        r.attributes = @yaml[:attributes][:default] if @yaml[:attributes].present? && @yaml[:attributes][:default].present?
        r.viewing_direction = parent.viewing_direction
        r.title = volume[:title]
        r.apply_depositor_metadata @user
        r.save!
        logger.info "Created ScannedResource: #{r.id}"

        ingest_files(parent: parent, resource: r, files: volume[:files]) if volume[:files].present?
        r.logical_order.order = map_fileids(volume[:structure]) if volume[:structure].present?
        r.save!

        parent.ordered_members << r
        parent.save!
      end
    end

    def ingest_files(parent: nil, resource: nil, files: [])
      files.each do |f|
        logger.info "Ingesting file #{f[:path]}"
        file_set = FileSet.new
        file_set.title = f[:title]
        file_set.replaces = f[:replaces]
        actor = FileSetActor.new(file_set, @user)
        actor.create_metadata(resource, f[:file_opts])
        actor.create_content(decorated_file(f))

        mets_to_repo_map[f[:id]] = file_set.id

        next unless f[:path] == thumbnail_path
        resource.thumbnail_id = file_set.id
        resource.save!
        parent.thumbnail_id = file_set.id if parent
      end
    end

    def decorated_file(f)
      IoDecorator.new(File.open(f[:path]), f[:mime_type], File.basename(f[:path]))
    end

    def map_fileids(hsh)
      hsh.each do |k, v|
        hsh[k] = v.each { |node| map_fileids(node) } if k == :nodes
        hsh[k] = mets_to_repo_map[v] if k == :proxy
      end
    end

    def mets_to_repo_map
      @mets_to_repo_map ||= {}
    end

    def thumbnail_path
      @thumbnail_path ||= @yaml[:thumbnail_path]
    end
end
