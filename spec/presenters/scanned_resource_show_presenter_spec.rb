require 'rails_helper'

RSpec.describe ScannedResourceShowPresenter do
  let(:srs_presenter) { described_class.new(solr_document, ability) }

  let(:date_created) { "2015-09-02" }
  let(:state) { "pending" }
  let(:title) { "test title" }
  let(:solr_document) do
    instance_double(SolrDocument,
                    date_created: date_created,
                    state: state,
                    id: "test",
                    title: title)
  end
  let(:ability) { nil }

  describe "#date_created" do
    it "delegates to solr document" do
      expect(srs_presenter.date_created).to eq date_created
    end
  end
  describe "#state" do
    it "delegates to solr document" do
      expect(srs_presenter.state).to eq state
    end
  end

  describe "#pending_uploads" do
    it "finds all pending uploads" do
      pending_upload =
        FactoryGirl.create(:pending_upload,
                           curation_concern_id: solr_document.id)
      expect(srs_presenter.pending_uploads).to eq [pending_upload]
    end
  end

  describe "#logical_order_object" do
    before do
      allow(solr_document).to receive(:logical_order) \
        .and_return("nodes": [{ label: "Chapter 1", proxy: "test" }])
    end
    context "with nodes for live objects" do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(WithProxyForObject).to \
          receive(:proxy_for_object).and_return('something')
        # rubocop:enable RSpec/AnyInstance
      end
      it "returns nodes" do
        expect(srs_presenter.logical_order_object.nodes.length).to eq 1
      end
    end
    context "with nodes for deleted objects" do
      it "returns a logical order object with nodes rejected" do
        expect(srs_presenter.logical_order_object.nodes).to be_empty
      end
      it "returns decorated logical order object" do
        expect(srs_presenter.logical_order_object) \
          .to respond_to :proxy_for_object
      end
    end
  end

  describe "attribute_to_html" do
    context "when given an arabic string" do
      let(:title) { "حكاية" }

      it "marks it as rtl" do
        expect(srs_presenter.attribute_to_html(:title)).to include "dir=rtl"
      end
    end
    context "when given a bad field" do
      it "logs it" do
        allow(Rails.logger).to receive(:warn)

        expect(srs_presenter.attribute_to_html(:bad_field)).to eq nil

        expect(Rails.logger).to have_received :warn
      end
    end
  end
end
