require 'mighty_fetcher/filter/middleware'
require 'mighty_fetcher/filter/parameter'
require 'mighty_fetcher/filter/parameter_definition'
require 'mighty_fetcher/validation_error'
require 'database_helper'

RSpec.describe MightyFetcher::Filter::Middleware do
  before do
    3.times { |n| Page.create(name: "Page ##{n}") }
  end

  let(:pages) { Page.all }

  def call_middleware(definition, params)
    described_class.new(->(env) { env }, Set.new([definition])).call([pages, params])
  end

  context 'validates parameters' do
    let(:params) { {} }
    let(:definition) do
      MightyFetcher::Filter::ParameterDefinition.new(:name, validates: { presence: true })
    end

    it 'fail with error' do
      expect do
        call_middleware(definition, params)
      end.to raise_error(MightyFetcher::FilterValidationFailed)
    end
  end

  context 'filters scope' do
    let(:page) { pages.first }
    let(:params) { { filter: { 'name_eq' => page.name } } }
    let(:definition) do
      MightyFetcher::Filter::ParameterDefinition.new(:name, validates: { presence: true })
    end

    it 'returns filtered collection and not modified params' do
      scope, parameters = call_middleware(definition, params)
      expect(scope).to contain_exactly(page)
      expect(parameters).to eq(params)
    end
  end
end
