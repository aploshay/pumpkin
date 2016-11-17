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

  def attributes
    attribute_sources.map { |k, v| [k, v.raw_attributes] }.to_h
  end

  def attribute_sources
    { default: default_data,
      local: local_data,
      remote: remote_data
    }
  end

  def default_attributes
    DEFAULT_ATTRIBUTES
  end

  def local_attributes
    self.class.const_get(:LOCAL_ATTRIBUTES).map { |att| [att, send(att)] }.to_h
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

    def local_data
      @local_data ||= AttributeIngester.new(id, local_attributes, factory: resource_class)
    end

    def default_data
      @default_data ||= AttributeIngester.new(id, default_attributes, factory: resource_class)
    end
end
