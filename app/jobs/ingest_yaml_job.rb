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
      resource = minimal_record(@yaml[:volumes].present? ? MultiVolumeWork : ScannedResource)
      resource.identifier = @yaml[:identifier]
      resource.replaces = @yaml[:replaces]
      resource.source_metadata_identifier = @yaml[:source_metadata_identifier]
      resource.member_of_collections = @collections
      resource.apply_remote_metadata
      resource.save!
      logger.info "Created #{resource.class}: #{resource.id}"

      attach_sources resource

      if @yaml[:volumes].present?
        ingest_volumes(resource)
      else
        ingest_files(resource: resource, files: @yaml[:files])
        if @yaml[:structure].present?
          resource.logical_order.order = map_fileids(@yaml[:structure])
        end
        resource.save!
      end
    end

    def attach_sources(resource)
      attach_source(resource, ['YAML'], @yaml_file)
      return unless @yaml[:source].present?
      attach_source(resource, @yaml[:source][:title], @yaml[:source][:file])
    end

    def attach_source(resource, title, file)
      file_set = FileSet.new
      file_set.title = title
      actor = FileSetActor.new(file_set, @user)
      actor.attach_related_object(resource)
      actor.attach_content(File.open(file, 'r:UTF-8'))
    end

    def minimal_record(klass)
      resource = klass.new
      resource.state = 'final_review'
      resource.viewing_direction = @yaml[:viewing_direction]
      resource.rights_statement = 'http://rightsstatements.org/vocab/NKC/1.0/'
      resource.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      resource.apply_depositor_metadata @user
      resource
    end

    def ingest_volumes(parent)
      @yaml[:volumes].each do |volume|
        r = minimal_record(ScannedResource)
        r.title = volume[:title]
        r.save!
        logger.info "Created ScannedResource: #{r.id}"

        ingest_files(parent: parent, resource: r, files: volume[:files])
        r.logical_order.order = map_fileids(volume[:structure])
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

        next unless f[:path] == @yaml[:thumbnail_path]
        resource.thumbnail_id = file_set.id
        resource.save!
        parent.thumbnail_id = file_set.id if parent
      end
    end

    # unmodified copied methods
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
end
