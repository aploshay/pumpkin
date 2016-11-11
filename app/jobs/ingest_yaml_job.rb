# rubocop:disable Metrics/ClassLength
class IngestYAMLJob < ActiveJob::Base
  queue_as :ingest

  # @param [String] yaml_file Filename of a YAML file to ingest
  # @param [String] user User to ingest as
  def perform(yaml_file, user)
    logger.info "Ingesting YAML #{yaml_file}"
    @yaml_file = yaml_file
    @yaml = File.open(yaml_file) { |f| Psych.load(f) }
    @user = user

    ingest
  end

  private

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def ingest
      resource = (@yaml[:volumes].present? ? MultiVolumeWork : ScannedResource).new
      if @yaml[:attributes].present?
        @yaml[:attributes].each { |_set_name, attributes| resource.attributes = attributes }
      end
      resource.source_metadata = @yaml[:source_metadata] if @yaml[:source_metadata].present?

      resource.apply_depositor_metadata @user
      resource.member_of_collections = @yaml[:collections].map { |slug| find_or_create_collection(slug) } if @yaml[:collections]

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
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def find_or_create_collection(slug)
      existing = Collection.where exhibit_id_ssim: slug
      return existing.first if existing.first
      col = Collection.new metadata_for_collection(slug)
      col.apply_depositor_metadata @user
      col.save!
      col
    end

    def metadata_for_collection(slug)
      collection_metadata.each do |c|
        return { exhibit_id: slug, title: [c['title']], description: [c['blurb']] } if c['slug'] == slug
      end
    end

    def collection_metadata
      @collection_metadata ||= JSON.parse(File.read(File.join(Rails.root, 'config', 'pudl_collections.json')))
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
        file_set.attributes = f[:attributes]
        actor = FileSetActor.new(file_set, @user)
        actor.create_metadata(resource, f[:file_opts])
        actor.create_content(decorated_file(f))

        yaml_to_repo_map[f[:id]] = file_set.id

        next unless f[:path] == thumbnail_path
        resource.thumbnail_id = file_set.id
        resource.save!
        parent.thumbnail_id = file_set.id if parent
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
end
# rubocop:enable Metrics/ClassLength
