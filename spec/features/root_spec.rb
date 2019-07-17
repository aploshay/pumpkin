require 'rails_helper'

RSpec.describe 'Home Page', type: :feature do
  describe 'a logged in user' do
    let(:user) { FactoryGirl.create(:image_editor) }

    before do
      sign_in user
    end

    it 'Logged in users see see search results with logout controls' do
      visit root_path
      expect(page).to have_content('Log Out')
      page.assert_selector('div.search', count: 1)
    end
  end

  describe 'an anonymous user' do
    it 'Anonymous users see search results but no logout controls' do
      visit root_path
      expect(page).not_to have_content('Log Out')
      page.assert_selector('div.search', count: 1)
    end
  end
end
