require 'rails_helper'

RSpec.describe 'MultiVolumeWorksController', type: :request do
  let(:user) { FactoryGirl.create(:image_editor) }
  let(:multi_volume_work) { FactoryGirl.create(:multi_volume_work) }

  describe 'User follows a link with a search highlight term' do
    let(:resource_path) { curation_concerns_multi_volume_work_path(multi_volume_work.id) }
    let(:search_term_path) { "#{resource_path}/highlight/#{search_term}" }

    context 'with a period (.)' do
      let(:search_term) { CGI.escape('Symphony No. 2') }

      it 'does not raise ActionController::UnknownFormat' do
        expect { get search_term_path }.not_to raise_error
      end
    end
  end
end
