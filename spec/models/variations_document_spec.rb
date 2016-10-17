require 'rails_helper'

RSpec.describe VariationsDocument do
  let(:variations_file) { Rails.root.join("spec", "fixtures", "bhr9405.xml") }
  metadata_fields = {
    visibility: 'open',
    rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
    media: '1 score (64 p.) ; 32 cm',
    holding_location: 'https://libraries.indiana.edu/music'
  }
  subject { described_class.new variations_file }

  describe "metadata fields" do
    metadata_fields.each do |field, value|
      it "has a #{field}" do
        expect(subject.send(field)).to eq value
      end
    end
  end
  describe "additional methods" do
    additional_methods = {
      location: 'IU Music Library',
      html_page_status: 'None',
      holding_status: 'Publicly available',
      copyright_owner: 'G. Ricordi & Co.'
    }
    additional_methods.each do |method, value|
      specify "#{method} returns expected value" do
        expect(subject.send(method)).to eq value
      end
    end
  end
  # FIXME: add?
  # copyright_claimant, copyright_holder
  # rights, rights_note, rights_statement
end
