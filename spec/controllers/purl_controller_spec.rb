require 'rails_helper'

describe PurlController do
  let(:user) { FactoryGirl.create(:user) }
  let(:scanned_resource) { FactoryGirl.create(:scanned_resource, user: user, title: ['Dummy Title'], state: 'complete', source_metadata_identifier: 'BHR9405') }
  let(:reloaded) { scanned_resource.reload }

  describe "default" do
    let(:user) { FactoryGirl.create(:admin) }
    before do
      sign_in user
    end

    context "with a matching id" do
      before(:each) do
        get :default, id: scanned_resource.source_metadata_identifier
      end
      it "redirects to the scanned_resource page" do
        expect(response).to redirect_to curation_concerns_scanned_resource_path(scanned_resource)
      end
    end
    context "with an unmatching id" do
      before(:each) do
        get :default, id: 'unmatching_id'
      end
      it "returns a 404 response" do
        expect(response.status).to eq(404)
        expect(response).to render_template(file: "#{Rails.root}/public/404.html")
      end
    end
  end
end
