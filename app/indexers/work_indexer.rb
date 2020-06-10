# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
class WorkIndexer < CurationConcerns::WorkIndexer
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def generate_solr_document
    super.tap do |solr_doc|
      solr_doc[Solrizer.solr_name('member_of_collection_slugs', :symbol)] = object.member_of_collections.map(&:exhibit_id)

      (PlumSchema.display_fields + [:title]).each do |field|
        objects = object.get_values(field, literal: true)
        statements = objects.map do |obj|
          ::RDF::Statement.from([object.rdf_subject, ::RDF::URI(""), obj])
        end
        output = JSON::LD::API.fromRdf(statements)
        next if output.empty?
        output = output[0][""]
        output.map! do |object|
          if object.is_a?(Hash) && object["@value"] && object.keys.length == 1
            object["@value"]
          else
            object.to_json
          end
        end
        solr_doc[Solrizer.solr_name("#{field}_literals", :symbol)] = output
      end

      solr_doc[Solrizer.solr_name('sort_title', :stored_sortable)] =
        object.title.first

      pages = object.member_ids.size
      if object.is_a? MultiVolumeWork
        pages = object.member_ids.map do |id|
          ScannedResource.search_with_conditions({ id: id }, rows: 1) \
                         .first&.dig('number_of_pages_isi').to_i
        end.reduce(:+)
      end
      solr_doc[Solrizer.solr_name('number_of_pages',
                                  :stored_sortable,
                                  type: :integer)] = pages
      solr_doc[Solrizer.solr_name('number_of_pages',
                                  :stored_sortable,
                                  type: :string)] = pages_bucket(pages, 100)

      if object.date_created.present?
        solr_doc[Solrizer.solr_name('date_created',
                                    :stored_sortable,
                                    type: :integer)] =
          object.date_created.first.to_i
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

    def pages_bucket(pages, size)
      n = (pages.to_i / size) * size
      "#{n}-#{n + size - 1} pages"
    end
end
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/PerceivedComplexity
