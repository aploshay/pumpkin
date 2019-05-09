require 'rails_helper'

RSpec.describe 'ScannedResourcesController', type: :request do
  let(:user) { FactoryGirl.create(:image_editor) }
  let(:scanned_resource) { FactoryGirl.create(:scanned_resource) }

  before do
    login_as(user, scope: :user)
  end

  it 'User creates a new scanned resource',
     vcr: { cassette_name: 'bibdata', allow_playback_repeats: true } do
    get '/concern/scanned_resources/new'

    expect(response) \
      .to render_template('curation_concerns/scanned_resources/new')

    valid_params = {
      title: ['My Resource'],
      source_metadata_identifier: '2028405',
      rights_statement: 'http://rightsstatements.org/vocab/NKC/1.0/'
    }

    post '/concern/scanned_resources', scanned_resource: valid_params

    resource_path =
      curation_concerns_scanned_resource_path(assigns(:curation_concern))
    expect(response).to redirect_to(resource_path)
    follow_redirect!

    expect(response).to render_template(:show)
    expect(response.status).to eq 200
    expect(response.body) \
      .to include('<h1 dir="ltr">The last resort : a novel</h1>')
  end

  describe 'User follows a link with a search highlight term' do
    let(:resource_path) { curation_concerns_scanned_resource_path(scanned_resource.id) }
    let(:search_term_path) { "#{resource_path}/highlight/#{search_term}" }

    context 'with a period (.)' do
      let(:search_term) { CGI.escape('Symphony No. 2') }

      it 'does not raise ActionController::UnknownFormat' do
        expect { get search_term_path }.not_to raise_error
      end
    end
  end
end
