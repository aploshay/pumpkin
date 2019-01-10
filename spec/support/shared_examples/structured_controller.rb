RSpec.shared_examples "structure persister" \
do |resource_symbol, presenter_factory|
  describe "#structure" do
    let(:user) { FactoryGirl.create(:user) }
    let(:solr) { ActiveFedora.solr.conn }
    let(:resource) do
      r = FactoryGirl.build(resource_symbol)
      allow(r).to receive(:id).and_return("1")
      allow(r.list_source).to receive(:id).and_return("3")
      r
    end
    let(:file_set) do
      f = FactoryGirl.build(:file_set)
      allow(f).to receive(:id).and_return("2")
      f
    end

    before do
      sign_in user
      resource.ordered_members << file_set
      solr.add file_set.to_solr.merge(ordered_by_ssim: [resource.id])
      solr.add resource.to_solr
      solr.add resource.list_source.to_solr
      solr.commit
    end

    it "sets @members" do
      get :structure, id: "1"

      expect(assigns(:members).map(&:id)).to eq ["2"]
    end
    it "sets @logical_order" do
      obj = instance_double("logical order object")
      my_presenter_factory = instance_double(presenter_factory)
      allow(presenter_factory).to receive(:new).and_return(my_presenter_factory)
      allow(my_presenter_factory).to receive(:member_presenters)
      allow(my_presenter_factory) \
        .to receive(:logical_order_object).and_return(obj)
      get :structure, id: "1"

      expect(assigns(:logical_order)).to eq obj
    end
  end

  describe "#save_structure" do
    let(:resource) { FactoryGirl.create(resource_symbol, user: user) }
    let(:file_set) { FactoryGirl.create(:file_set, user: user) }
    let(:user) { FactoryGirl.create(:admin) }
    let(:nodes) do
      [
        {
          "label": "Chapter 1",
          "nodes": [
            {
              "proxy": file_set.id
            }
          ]
        }
      ]
    end

    before do
      sign_in user
      resource.ordered_members << file_set
      resource.save
    end

    it "persists order" do
      post :save_structure, nodes: nodes, id: resource.id, label: "TOP!"

      expect(response.status).to eq 200
      expect(resource.reload.logical_order.order) \
        .to eq({ "label": "TOP!", "nodes": nodes }.with_indifferent_access)
    end

    it 'returns Locked status for a locked resource' do
      lock_info = resource.lock
      post :save_structure, nodes: nodes, id: resource.id, label: 'TOP!'
      expect(response.status).to eq 423
      resource.unlock(lock_info)
    end
  end
end
