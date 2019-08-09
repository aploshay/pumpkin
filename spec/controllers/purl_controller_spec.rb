require 'rails_helper'

describe PurlController do
  let(:user) { FactoryGirl.create(:user) }
  let(:scanned_resource) {
    FactoryGirl.create(:scanned_resource,
                       user: user,
                       title: ['Dummy Title'],
                       state: 'complete',
                       source_metadata_identifier: 'BHR9405')
  }
  let(:file_set) {
    FactoryGirl.create(:file_set,
                       user: user,
                       title: ['Page 5'],
                       source_metadata_identifier: 'BHR9405-001-0005')
  }
  let(:multi_volume_work) {
    FactoryGirl.create(:multi_volume_work,
                       user: user,
                       title: ['Dummy Title'],
                       state: 'complete',
                       source_metadata_identifier: 'ABE9721')
  }

  describe "formats" do
    before do
      sign_in user
      file_set
    end
    context "when in jp2" do
      before do
        get :formats, id: id, format: format
      end
      let(:id) { file_set.source_metadata_identifier }
      let(:format) { 'jp2' }
      let(:model) { file_set.has_model[0] }

      it "redirects to the correct location" do
        if model && model == 'FileSet'
          iiif_path = IIIFPath.new(file_set.id)
          expect(response).to redirect_to "#{iiif_path}/full/!600,600/0/default.jpg"
        else
          expect(response).to redirect_to target_path
        end
      end
    end
  end

  describe "default" do
    let(:user) { FactoryGirl.create(:admin) }

    before do
      sign_in user
      scanned_resource
      multi_volume_work
    end
    context "with a matching id" do
      shared_examples "responses for matches" do
        before do
          get :default, id: id, format: format
        end
        context "when in html" do
          let(:format) { 'html' }

          it "redirects to the scanned_resource page" do
            expect(response).to redirect_to target_path
          end
        end
        context "when in json" do
          let(:format) { 'json' }

          it 'renders a json response' do
            expect(JSON.parse(response.body)['url']).to match Regexp.escape(target_path)
          end
        end
      end
      context "when for a ScannedResource" do
        let(:id) { scanned_resource.source_metadata_identifier }
        let(:target_path) {
          curation_concerns_scanned_resource_path(scanned_resource)
        }

        include_examples "responses for matches"
      end
      context "when for a MultiVolumeWork" do
        let(:id) { multi_volume_work.source_metadata_identifier }
        let(:target_path) {
          curation_concerns_multi_volume_work_path(multi_volume_work)
        }

        include_examples "responses for matches"
      end
      context "when for a specific page" do
        let(:id) { multi_volume_work.source_metadata_identifier + '-9-0042' }
        let(:target_path) { curation_concerns_multi_volume_work_path(multi_volume_work) + '#?m=8&cv=41' }

        include_examples "responses for matches"
      end
    end
    shared_examples "responses for no matches" do
      let(:target_path) { Plum.config['purl_redirect_url'] % id }
      before do
        get :default, id: id, format: format
      end
      context "when in html" do
        let(:format) { 'html' }

        it "redirects to #{Plum.config['purl_redirect_url']}" do
          expect(response).to redirect_to target_path
        end
      end
      context "when in json" do
        let(:format) { 'json' }

        it 'renders a json response' do
          expect(JSON.parse(response.body)['url']).to match target_path
        end
      end
    end
    context "with an invalid id" do
      let(:id) { 'BHR940' }

      before do
        scanned_resource
      end
      include_examples "responses for no matches"
    end
    context "with an unmatched id" do
      let(:id) { scanned_resource.source_metadata_identifier }

      before do
        id
        scanned_resource.destroy!
      end
      include_examples "responses for no matches"
    end
  end
end
