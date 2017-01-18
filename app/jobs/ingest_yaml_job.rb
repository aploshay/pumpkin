class IngestYAMLJob < ActiveJob::Base
  include CollectionHelper
  include CurationConcerns::Lockable

  queue_as :ingest

  # @param [String] yaml_file Filename of a YAML file to ingest
  # @param [String] user User to ingest as
  def perform(yaml_file, user, file_association_method: 'individual')
    logger.info "Ingesting YAML #{yaml_file}"
    @yaml_file = yaml_file
    @yaml = File.open(yaml_file) { |f| Psych.load(f) }
    @user = user
    @file_association_method = file_association_method
    ingest
  end

  private

    def ingest
      @counter = IngestCounter.new
      resource = (@yaml[:volumes].present? ? MultiVolumeWork : ScannedResource).new
      if @yaml[:attributes].present?
        @yaml[:attributes].each { |_set_name, attributes| resource.attributes = attributes }
      end
      resource.source_metadata = @yaml[:source_metadata] if @yaml[:source_metadata].present?

      resource.apply_depositor_metadata @user
      resource.member_of_collections = find_or_create_collections(@yaml[:collections])

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

      resource.state = 'complete'
      resource.save!
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
      @volumes = []
      @yaml[:volumes].each do |volume|
        r = ScannedResource.new
        r.attributes = @yaml[:attributes][:default] if @yaml[:attributes].present? && @yaml[:attributes][:default].present?
        r.viewing_direction = parent.viewing_direction
        r.title = volume[:title]
        r.apply_depositor_metadata @user
        r.save!
        logger.info "Created ScannedResource: #{r.id}"

        ingest_files(parent: parent, resource: r, files: volume[:files])
        r.logical_order.order = map_fileids(volume[:structure])
        r.save!
      end
      parent.ordered_members << @volumes
      parent.save!
    end

    def ingest_files(parent: nil, resource: nil, files: [])
      @file_sets = []
      files.each do |f|
        logger.info "Ingesting file #{f[:path]}"
        @counter.increment
        file_set = FileSet.new
        file_set.attributes = f[:attributes]
        copy_visibility(resource, file_set) unless assign_visibility?(f[:attributes])
        actor = FileSetActor.new(file_set, @user)
        if @file_association_method.in? ['batch', 'none']
          actor.create_metadata(nil, f[:file_opts])
        else
          actor.create_metadata(resource, f[:file_opts])
        end
        actor.create_content(decorated_file(f))

        yaml_to_repo_map[f[:id]] = file_set.id
        @file_sets << file_set

        next unless thumbnail_path.present? && f[:path] == thumbnail_path
        resource.thumbnail_id = file_set.id
        resource.representative_id = file_set.id
        resource.save!
        if parent
          parent.thumbnail_id = file_set.id
          parent.representative_id = file_set.id
        end
      end
      if @file_association_method == 'batch'
        logger.info "Starting batch file_set association"
        attach_files_to_work(resource, @file_sets)
        logger.info "Completed batch file_set association"
      end
    end

    def decorated_file(f)
      IoDecorator.new(open(f[:path]), f[:mime_type], File.basename(f[:path]))
    end

    def map_fileids(hsh)
      hsh.each do |k, v|
        hsh[k] = v.each { |node| map_fileids(node) } if k == :nodes
        hsh[k] = yaml_to_repo_map[v] if k == :proxy
      end
    end

    def yaml_to_repo_map
      @yaml_to_repo_map ||= {}
    end

    def thumbnail_path
      @thumbnail_path ||= @yaml[:thumbnail_path]
    end

    # All below copied, modified from FileSetActor
        def attach_files_to_work(work, file_sets)
          acquire_lock_for(work.id) do
            set_representative(work, file_sets.first)
            set_thumbnail(work, file_sets.first)
            # Ensure we have an up-to-date copy of the members association, so
            # that we append to the end of the list.
            work.reload unless work.new_record?
            work.ordered_members << file_sets

            # Save the work so the association between the work and the file_set is persisted (head_id)
            work.save!
          end
        end

        def assign_visibility?(file_set_params = {})
          !((file_set_params || {}).keys & %w(visibility embargo_release_date lease_expiration_date)).empty?
        end

        # copy visibility from source_concern to destination_concern
        def copy_visibility(source_concern, destination_concern)
          destination_concern.visibility = source_concern.visibility
        end

        def set_representative(work, file_set)
          return unless work.representative_id.blank?
          work.representative = file_set
        end

        def set_thumbnail(work, file_set)
          return unless work.thumbnail_id.blank?
          work.thumbnail = file_set
        end

end
