class ManifestBuilder
  class ServicesBuilder
    include Rails.application.routes.url_helpers

    attr_reader :record

    def initialize(record)
      @record = record
      # @searchable = record.full_text_searchable[0] unless record.full_text_searchable.nil?
    end

    def apply(manifest)
      return if
        record.class == AllCollectionsPresenter ||
        record.class == CollectionShowPresenter ||
        searchable? == 'disabled'
      service_array = {
        "@context"  => "http://iiif.io/api/search/0/context.json",
        "@id"       => "#{root_url(protocol: protocol)}search/#{record.id}",
        "profile"   => "http://iiif.io/api/search/0/search",
        "label"     => "Search within item."
      }
      manifest["service"] = [service_array]
    end

    private

      def searchable?
        record.full_text_searchable[0] unless record.full_text_searchable.nil?
      end

      def protocol
        if Rails.application.config.force_ssl
          :https
        else
          :http
        end
      end
  end
end
