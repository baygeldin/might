require 'mighty_fetcher/filter/ransackable/filter'
require 'mighty_fetcher/filter/parameter'
require 'mighty_fetcher/filter/parameter_definition'
require 'database_helper'

RSpec.describe MightyFetcher::Filter::Ransackable::Filter do
  let(:definition) do
    MightyFetcher::Filter::ParameterDefinition.new(:name)
  end

  before do
    3.times { |n| Page.create!(name: "Foobar #{n}") }
  end

  let!(:pages) { Page.all }
  let(:page) { pages.first }

  subject do
    described_class
      .new(->(env) { env[0].all })
      .call([pages, filters])
  end

  context 'and no filters given' do
    let(:filters) { {} }

    it 'return all objects' do
      is_expected.to contain_exactly(*pages)
    end
  end

  context 'and filter given' do
    let(:filters) { { 'name_eq' => page.name } }

    it 'return found objects' do
      is_expected.to contain_exactly(page)
    end
  end

  context 'and no matching filter given' do
    let(:filters) { { 'name_eq' => 'invalid' } }

    it 'return no objects' do
      is_expected.to be_empty
    end
  end
end
