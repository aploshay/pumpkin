require 'rails_helper'

RSpec.describe HoldingLocationAuthority do
  let(:hl_authority) { described_class.new }
  let(:id) { 'https://libraries.indiana.edu/music' }
  let(:obj) {
    {
      "label" => "William & Gayle Cook Music Library",
      "address" => "200 South Jordan Ave, Bloomington IN, 47405",
      "phone_number" => "(812) 855-2970",
      "contact_email" => "libmus@indiana.edu",
      "gfa_pickup" => "PW",
      "staff_only" => false,
      "pickup_location" => true,
      "digital_location" => true,
      "url" => "https://libraries.indiana.edu/music",
      "library" => {
        "label" => "William & Gayle Gook Music Library",
        "code" => "libmus"
      },
      "id" => "https://libraries.indiana.edu/music"
    }
  }

  context "with data" do
    it "finds a holding location by id" do
      expect(hl_authority.find(id)).to eq(obj.stringify_keys)
    end

    it "lists all of the holding locations" do
      expect(hl_authority.all.length).to be_positive
      expect(hl_authority.all).to include(obj.stringify_keys)
    end
  end
end
