# Generated via
#  `rails generate worthwhile:work ScannedResource`
require 'rails_helper'

describe ScannedResource do
  let(:scanned_resource) {
    FactoryGirl.build(:scanned_resource,
                      source_metadata_identifier: '12345',
                      rights_statement:
                      'http://rightsstatements.org/vocab/NKC/1.0/',
                      workflow_note: ['Note 1'])
  }
  let(:reloaded) { described_class.find(scanned_resource.id) }

  describe 'has note fields' do
    %i[portion_note description].each do |note_type|
      it "should let me set a #{note_type}" do
        note = 'This is note text'
        scanned_resource.send("#{note_type}=", note)
        expect { scanned_resource.save }.not_to raise_error
        expect(reloaded.send(note_type)).to eq note
      end
    end
  end

  describe 'has a repeatable workflow note field' do
    it "allows multiple workflow notes" do
      scanned_resource.workflow_note = ['Note 1', 'Note 2']
      expect { scanned_resource.save }.not_to raise_error
      expect(reloaded.workflow_note).to include 'Note 1', 'Note 2'
    end
    it "allows adding to the workflow notes" do
      scanned_resource.workflow_note << 'Note 2'
      expect { scanned_resource.save }.not_to raise_error
      expect(reloaded.workflow_note).to include 'Note 1', 'Note 2'
    end
  end

  describe 'has source metadata id' do
    it 'allows setting of metadata id' do
      id = '12345'
      scanned_resource.source_metadata_identifier = id
      expect { scanned_resource.save }.not_to raise_error
      expect(reloaded.source_metadata_identifier).to eq id
    end
  end

  context "when validating title and metadata id",
          vcr: { cassette_name: "bibdata", record: :new_episodes } do
    before do
      scanned_resource.source_metadata_identifier = nil
      scanned_resource.title = nil
    end
    context "when neither metadata id nor title is set" do
      it 'fails' do
        scanned_resource.apply_remote_metadata
        expect(scanned_resource.valid?).to eq false
      end
    end
    context "when only metadata id is set" do
      before do
        scanned_resource.source_metadata_identifier = "2028405"
      end
      context 'when it does not return a title' do
        before do
          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(IuMetadata::MarcRecord).to receive(:title).and_return([])
          # enable:disable RSpec/AnyInstance
        end
        it 'fails' do
          scanned_resource.apply_remote_metadata
          expect(scanned_resource.valid?).to eq false
        end
      end
      context 'when it returns a title' do
        it 'passes' do
          scanned_resource.apply_remote_metadata
          expect(scanned_resource.valid?).to eq true
        end
      end
    end
    context "when only title id is set" do
      before do
        scanned_resource.title = ["A Title.."]
      end
      it 'passes' do
        scanned_resource.apply_remote_metadata
        expect(scanned_resource.valid?).to eq true
      end
    end
  end

  describe '#rights_statement' do
    it "sets rights_statement" do
      nkc = 'http://rightsstatements.org/vocab/NKC/1.0/'
      scanned_resource.rights_statement = nkc
      expect { scanned_resource.save }.not_to raise_error
      expect(reloaded.rights_statement).to eq nkc
    end

    it "requires rights_statement" do
      scanned_resource.rights_statement = nil
      expect(scanned_resource).not_to be_valid
    end
  end

  describe 'apply_remote_metadata' do
    context 'when source_metadata_identifier is not set' do
      before { scanned_resource.source_metadata_identifier = nil }
      it 'does nothing' do
        original_attributes = scanned_resource.attributes
        # rubocop:disable RSpec/MessageSpies
        expect(scanned_resource.send(:remote_metadata_factory)).not_to receive(:new)
        # rubocop:enable RSpec/MessageSpies
        scanned_resource.apply_remote_metadata
        expect(scanned_resource.attributes).to eq(original_attributes)
      end
    end

    # FIXME: relabel this section
    context 'With a Voyager ID',
            vcr: { cassette_name: "bibdata", record: :new_episodes } do
      before do
        scanned_resource.source_metadata_identifier = '2028405'
      end

      it 'Extracts Voyager Metadata' do
        scanned_resource.apply_remote_metadata
        expect(scanned_resource.title).to eq(['The last resort : a novel'])
        expect(scanned_resource.resource.get_values(:title, literal: true)) \
          .to eq([RDF::Literal.new('The last resort : a novel')])
        expect(scanned_resource.creator) \
          .to eq(['Johnson, Pamela Hansford, 1912-1981'])
        expect(scanned_resource.publisher.sort) \
          .to eq(["St. Martin's Press", "Macmillan & co., ltd.,"].sort)
      end

      it 'Saves a record with extacted Voyager metadata' do
        scanned_resource.apply_remote_metadata
        scanned_resource.save
        expect { scanned_resource.save }.not_to raise_error
        expect(scanned_resource.id).to be_truthy
      end
    end
  end

  describe 'gets a noid' do
    it 'that conforms to a valid pattern' do
      expect { scanned_resource.save }.not_to raise_error
      noid_service = ActiveFedora::Noid::Service.new
      expect(noid_service).to be_valid(scanned_resource.id)
    end
    it "generates an ID which starts with the environment's first letter" do
      expect { scanned_resource.save }.not_to raise_error
      expect(scanned_resource.id.first).to eq "t"
    end
  end

  describe "#viewing_direction" do
    it "maps to the IIIF predicate" do
      expect(described_class.properties["viewing_direction"].predicate) \
        .to eq RDF::Vocab::IIIF.viewingDirection
    end
  end

  describe "#viewing_hint" do
    it "maps to the IIIF predicate" do
      expect(described_class.properties["viewing_hint"].predicate) \
        .to eq RDF::Vocab::IIIF.viewingHint
    end
  end

  describe "validations" do
    it "validates with the viewing direction validator" do
      expect(scanned_resource._validators[nil].map(&:class)) \
        .to include ViewingDirectionValidator
    end
    it "validates with the viewing hint validator" do
      expect(scanned_resource._validators[nil].map(&:class)) \
        .to include ViewingHintValidator
    end
  end

  describe "#state" do
    it "validates with the state validator" do
      expect(scanned_resource._validators[nil].map(&:class)).to include StateValidator
    end
    it "accepts a valid state" do
      scanned_resource.state = "pending"
      expect(scanned_resource.valid?).to eq true
    end
    it "rejects an invalid state" do
      scanned_resource.state = "blargh"
      expect(scanned_resource.valid?).to eq false
    end
  end

  describe "#check_state" do
    let(:scanned_resource) {
      FactoryGirl.build(:scanned_resource,
                        source_metadata_identifier: '12345',
                        rights_statement:
                        'http://rightsstatements.org/vocab/NKC/1.0/',
                        state: 'final_review')
    }

    let(:complete_reviewer) { FactoryGirl.create(:complete_reviewer) }

    before do
      complete_reviewer.save
      scanned_resource.save
      allow(Ezid::Identifier).to receive(:modify).and_return(true)
    end
    it "completes record when state changes to 'complete'",
       vcr: { cassette_name: "ezid" } do
      allow(scanned_resource).to receive("state_changed?").and_return true
      scanned_resource.state = 'complete'
      expect { scanned_resource.check_state } \
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      if Plum.config['ezid']['mint']
        expect(scanned_resource.identifier).to eq 'ark:/99999/fk4445wg45'
      end
    end
    it "does not complete record when state doesn't change" do
      allow(scanned_resource).to receive("state_changed?").and_return false
      scanned_resource.state = 'complete'
      # rubocop:disable RSpec/MessageSpies
      expect(scanned_resource).not_to receive(:complete_record)
      # rubocop:enable RSpec/MessageSpies
      expect { scanned_resource.check_state } \
        .not_to(change { ActionMailer::Base.deliveries.count })
    end
    it "does not complete record when state isn't 'complete'" do
      scanned_resource.state = 'final_review'
      # rubocop:disable RSpec/MessageSpies
      expect(scanned_resource).not_to receive(:complete_record)
      # rubocop:enable RSpec/MessageSpies
      expect { scanned_resource.check_state } \
        .not_to(change { ActionMailer::Base.deliveries.count })
    end
    it "does not overwrite existing identifier" do
      allow(scanned_resource).to receive("state_changed?").and_return true
      scanned_resource.state = 'complete'
      scanned_resource.identifier = '1234'
      # rubocop:disable RSpec/MessageSpies
      expect(scanned_resource).not_to receive("identifier=")
      # rubocop:enable RSpec/MessageSpies
      expect { scanned_resource.check_state } \
        .to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(scanned_resource.identifier).to eq('1234')
    end
    it "does not complete the record when the state transition is invalid" do
      allow(scanned_resource).to receive("state_changed?").and_return true
      scanned_resource.state = 'pending'
      # rubocop:disable RSpec/MessageSpies
      expect(scanned_resource).not_to receive(:complete_record)
      # rubocop:enable RSpec/MessageSpies
      expect { scanned_resource.check_state } \
        .not_to(change { ActionMailer::Base.deliveries.count })
      expect(scanned_resource.identifier).to eq(nil)
    end
  end

  describe "#pending_uploads" do
    it "returns all pending uploads" do
      scanned_resource.save
      pending_upload = FactoryGirl.create(:pending_upload,
                                          curation_concern_id: scanned_resource.id)

      expect(scanned_resource.pending_uploads).to eq [pending_upload]
    end
    it "doesn't return anything for other resources' pending uploads" do
      scanned_resource.save
      FactoryGirl.create(:pending_upload, curation_concern_id: "banana")

      expect(scanned_resource.pending_uploads).to eq []
    end
    context "when not persisted" do
      it "returns a blank array" do
        expect(described_class.new.pending_uploads).to eq []
      end
    end
  end

  include_examples "structural metadata" do
    let(:curation_concern) { scanned_resource }
  end
  include_examples "common metadata" do
    let(:curation_concern) { scanned_resource }
  end

  describe "collection indexing" do
    let(:scanned_resource) {
      FactoryGirl.create(:scanned_resource_in_collection)
    }
    let(:solr_doc) { scanned_resource.to_solr }

    it "indexes collection" do
      expect(solr_doc['member_of_collections_ssim']) \
        .to eq(['Test Collection'])
      expect(solr_doc['member_of_collection_slugs_ssim']) \
        .to eq(scanned_resource.member_of_collections.map(&:exhibit_id))
    end
  end

  describe "#pdf_type" do
    it "is empty by default" do
      expect(described_class.new.pdf_type).to eq []
    end
    it "can be set" do
      scanned_resource.pdf_type = ["color"]

      expect(scanned_resource.pdf_type).to eq ["color"]
    end
  end

  describe "literal indexing" do
    let(:scanned_resource) {
      FactoryGirl.create(:scanned_resource_in_collection,
                         title: [::RDF::Literal.new("Test", language: :fr)])
    }
    let(:solr_doc) { scanned_resource.to_solr }

    it "indexes literals with tags in a new field" do
      expect(solr_doc['title_tesim']).to eq ['Test']
      expect(solr_doc['title_literals_ssim']) \
        .to eq [JSON.dump("@value" => "Test", "@language" => "fr")]
    end
  end

  describe "number of pages indexing" do
    let(:scanned_resource) {
      FactoryGirl.create(:scanned_resource_with_file)
    }
    let(:solr_doc) { scanned_resource.to_solr }

    it "indexes the number of pages" do
      expect(solr_doc['number_of_pages_isi']).to eq 1
      expect(solr_doc['number_of_pages_ssi']).to eq "0-99 pages"
    end
  end

  describe "date_created indexing" do
    let(:scanned_resource) {
      FactoryGirl.create(:scanned_resource, date_created: ['2016'])
    }
    let(:solr_doc) { scanned_resource.to_solr }

    it "indexes date_created as an integer" do
      expect(solr_doc['date_created_isi']).to eq 2016
    end
  end

  describe "sortable title" do
    let(:scanned_resource) {
      FactoryGirl.create(:scanned_resource, title: ['ABC'])
    }
    let(:solr_doc) { scanned_resource.to_solr }

    it "indexes title as a sortable solr field" do
      expect(solr_doc['sort_title_ssi']).to eq 'ABC'
    end
  end

  describe "#full_text_searchable" do
    it "is true by default" do
      expect(described_class.new.full_text_searchable).to eq nil
    end
    it "can be set" do
      scanned_resource.full_text_searchable = "disabled"

      expect(scanned_resource.full_text_searchable).to eq "disabled"
    end
  end
end
