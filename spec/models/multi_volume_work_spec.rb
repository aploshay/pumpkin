# Generated via
#  `rails generate curation_concerns:work MultiVolumeWork`
require 'rails_helper'

describe MultiVolumeWork do
  let(:nkc) { 'http://rightsstatements.org/vocab/NKC/1.0/' }
  let(:multi_volume_work) {
    FactoryGirl.build(:multi_volume_work,
                      source_metadata_identifier: '12345',
                      rights_statement: nkc)
  }
  let(:scanned_resource1) {
    FactoryGirl.build(:scanned_resource,
                      title: ['Volume 1'],
                      rights_statement: nkc)
  }
  let(:scanned_resource2) {
    FactoryGirl.build(:scanned_resource,
                      title: ['Volume 2'],
                      rights_statement: nkc)
  }
  let(:reloaded) { described_class.find(multi_volume_work.id) }

  describe 'has note fields' do
    %i[portion_note description].each do |note_type|
      it "should let me set a #{note_type}" do
        note = 'This is note text'
        multi_volume_work.send("#{note_type}=", note)
        expect { multi_volume_work.save }.not_to raise_error
        expect(reloaded.send(note_type)).to eq note
      end
    end
  end

  describe 'has source metadata id' do
    it 'allows setting of metadata id' do
      id = '12345'
      multi_volume_work.source_metadata_identifier = id
      expect { multi_volume_work.save }.not_to raise_error
      expect(reloaded.source_metadata_identifier).to eq id
    end
  end

  context "when validating title and metadata id",
          vcr: { cassette_name: "bibdata", record: :new_episodes } do
    before do
      multi_volume_work.source_metadata_identifier = nil
      multi_volume_work.title = nil
    end
    context "when neither metadata id nor title is set" do
      it 'fails' do
        multi_volume_work.apply_remote_metadata
        expect(multi_volume_work.valid?).to eq false
      end
    end
    context "when only metadata id is set" do
      before do
        multi_volume_work.source_metadata_identifier = "2028405"
      end
      context 'when it does not return a title' do
        before do
          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(IuMetadata::MarcRecord).to receive(:title).and_return([])
          # enable:disable RSpec/AnyInstance
        end
        it 'fails' do
          multi_volume_work.apply_remote_metadata
          expect(multi_volume_work.valid?).to eq false
        end
      end
      context 'when it returns a title' do
        it 'passes' do
          multi_volume_work.apply_remote_metadata
          expect(multi_volume_work.valid?).to eq true
        end
      end
    end
    context "when only title id is set" do
      before do
        multi_volume_work.title = ["A Title.."]
      end
      it 'passes' do
        multi_volume_work.apply_remote_metadata
        expect(multi_volume_work.valid?).to eq true
      end
    end
  end

  describe 'has scanned resource members' do
    before do
      multi_volume_work.ordered_members = [scanned_resource1, scanned_resource2]
    end
    it "has scanned resources" do
      expect(multi_volume_work.ordered_members).to eq \
        [scanned_resource1, scanned_resource2]
    end
    it "can persist when it has a thumbnail set to scanned resource" do
      multi_volume_work.thumbnail = scanned_resource1
      expect(multi_volume_work.save).to eq true
    end
  end

  describe "#pending_uploads" do
    it "returns all pending uploads" do
      multi_volume_work.save
      pending_upload = FactoryGirl.create(:pending_upload,
                                          curation_concern_id: multi_volume_work.id)

      expect(multi_volume_work.pending_uploads).to eq [pending_upload]
    end
    it "doesn't return anything for other resources' pending uploads" do
      multi_volume_work.save
      FactoryGirl.create(:pending_upload, curation_concern_id: "banana")

      expect(multi_volume_work.pending_uploads).to eq []
    end
    context "when not persisted" do
      it "returns a blank array" do
        expect(described_class.new.pending_uploads).to eq []
      end
    end
  end

  include_examples "structural metadata" do
    let(:curation_concern) { multi_volume_work }
  end
  include_examples "common metadata" do
    let(:curation_concern) { multi_volume_work }
  end

  describe "solr indexing" do
    it "sets number_of_pages by sum of child volumes' pages" do
      scanned_resource1.members = [FactoryGirl.create(:file_set)]
      scanned_resource1.save
      scanned_resource2.members = [
        FactoryGirl.create(:file_set),
        FactoryGirl.create(:file_set)
      ]
      scanned_resource2.save
      multi_volume_work.ordered_members = [scanned_resource1, scanned_resource2]
      multi_volume_work.save
      expect(multi_volume_work.to_solr['number_of_pages_isi']).to eq 3
    end
  end
end
