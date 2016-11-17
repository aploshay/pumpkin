# multi_volume?, id must be defined
module PreingestableDocument
  DEFAULT_ATTRIBUTES = {
    state: 'final_review',
    viewing_direction: 'left-to-right',
    rights_statement: 'http://rightsstatements.org/vocab/NKC/1.0/',
    visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
  }

  def yaml_file
    source_file.sub(/\..{3,4}$/, '.yml')
  end

  def id
    'file://' + source_file
  end

  def attributes
    attribute_sources.map { |k, v| [k, v.raw_attributes] }.to_h
  end

  def attribute_sources
    { default: AttributeIngester.new(id, default_attributes, factory: resource_class),
      local: AttributeIngester.new(id, local_attributes, factory: resource_class),
      remote: remote_data
    }
  end

  def default_attributes
    DEFAULT_ATTRIBUTES
  end

  def local_attributes
    self.class.const_get(:LOCAL_ATTRIBUTES).map { |att| [att, send(att)] }.to_h
  end

  def remote_attributes
    remotes = {}
    remote_data.attributes.each do |k, v|
      if v.class.in? [Array, ActiveTriples::Relation]
        remotes[k] = v.map(&:value)
      else
        remotes[k] = v.value
      end
    end
    # remotes
    # FIXME: choose whether to use attributes above, or raw_attributes below
    remote_data.raw_attributes
  end

  def source_metadata
    return unless remote_data.source
    remote_data.source.dup.try(:force_encoding, 'utf-8')
  end

  def resource_class
    multi_volume? ? MultiVolumeWork : ScannedResource
  end

  private

    def remote_data
      @remote_data ||= remote_metadata_factory.retrieve(source_metadata_identifier)
    end

    def remote_metadata_factory
      if RemoteRecord.bibdata?(source_metadata_identifier)
        JSONLDRecord::Factory.new(resource_class)
      else
        RemoteRecord::Null
      end
    end
end
