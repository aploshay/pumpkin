require 'rails_helper'

RSpec.describe IuMetadata::VariationsRecord do
  let(:fixture_path) { File.expand_path('../../fixtures', __FILE__) }
  let(:record1) {
    pth = File.join(fixture_path, 'variations_xml/bhr9405.xml')
    described_class.new('file://' + pth, open(pth))
  }
  describe "parses attributes" do
    { source_metadata_identifier: 'BHR9405',
      identifier: 'http://purl.dlib.indiana.edu/iudl/variations/score/BHR9405',
      viewing_hint: 'paged',
      location: 'IU Music Library',
      holding_location: 'https://libraries.indiana.edu/music',
      media: '1 score (64 p.) ; 32 cm',
      copyright_holder: ['G. Ricordi & Co.'],
      visibility: 'open',
      rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
      collections: []
    }.each do |att, val|
      describe "##{att}" do
        it "retrieves the correct value" do
          expect(record1.send(att)).to eq val
        end
      end
    end
  end
end
