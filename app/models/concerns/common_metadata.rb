require 'vocab/f3_access'
require 'vocab/opaque_mods'
require 'vocab/pul_terms'

module CommonMetadata
  extend ActiveSupport::Concern

  included do
    before_update :check_state

    # Plum
    apply_schema PlumSchema,
                 ActiveFedora::SchemaIndexingStrategy \
      .new(ActiveFedora::Indexers::GlobalIndexer.new(%i[stored_searchable
                                                        facetable
                                                        symbol]))

    # Displayable fields (stored in solr but not indexed)
    apply_schema DisplayableSchema, ActiveFedora::SchemaIndexingStrategy.new(
      ActiveFedora::Indexers::GlobalIndexer.new(%i[displayable])
    )

    # IIIF
    apply_schema IIIFBookSchema, ActiveFedora::SchemaIndexingStrategy.new(
      ActiveFedora::Indexers::GlobalIndexer.new(%i[stored_searchable symbol])
    )

    validates :title, presence: { message: 'Your work must provide a title directly or through remote metadata lookup' }
    validates_with RightsStatementValidator
    validates_with StateValidator
    validates_with ViewingDirectionValidator
    validates_with ViewingHintValidator

    def apply_remote_metadata
      if remote_data.source
        self.source_metadata = remote_data.source.dup.try(:force_encoding,
                                                          'utf-8')
      end
      self.attributes = remote_data.attributes
      update_ezid if state == 'complete' && identifier
    end

    def check_state
      return unless state_changed?
      complete_record if state == 'complete'
      ReviewerMailer.notify(id, state).deliver_later
    end

    # override to address issue with @delegated_attributes being in
    # disagreement with attributes overriden by Schema inclusion.
    def self.multiple?(field)
      properties[field.to_s].try(:multiple?)
    end

    private

      def remote_data
        @remote_data ||=
          remote_metadata_factory.retrieve(source_metadata_identifier)
      end

      def remote_metadata_factory
        if RemoteRecord.bibdata?(source_metadata_identifier)
          JSONLDRecord::Factory.new(self.class)
        elsif source_metadata_identifier.blank?
          RemoteRecord
        else
          raise RemoteRecord::BibdataError, RemoteRecord.bibdata_error_message
        end
      end

      def complete_record
        if identifier
          update_ezid
        elsif Plum.config['ezid']['mint']
          self.identifier = Ezid::Identifier.mint(ezid_metadata).id
        end
      end

      def ezid_metadata
        {
          dc_publisher: I18n.t('ezid.dc_publisher'),
          dc_title: title.join('; '),
          dc_type: I18n.t('ezid.dc_type'),
          target: ManifestBuilder::ManifestHelper.new.polymorphic_url(self)
        }
      end

      def update_ezid
        return unless Plum.config['ezid']['update']
        Ezid::Identifier.modify(identifier, ezid_metadata)
      end
  end
end
