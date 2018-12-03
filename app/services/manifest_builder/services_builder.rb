class ManifestBuilder
  class ServicesBuilder
    include Rails.application.routes.url_helpers

    attr_reader :record

    def initialize(record)
      @record = record
    end

    def apply(manifest)
      return if
        record.class == AllCollectionsPresenter ||
        record.class == CollectionShowPresenter ||
        !searchable?
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
        return false if record.full_text_searchable.nil?
        return true if record.full_text_searchable[0] == 'enabled'
        false
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
