require 'mighty_fetcher/sort_middleware'
require 'mighty_fetcher/sort_parameter_definition'
require 'database_helper'

RSpec.describe MightyFetcher::SortMiddleware do
  let(:pages) { Page.all }

  let(:parameters_definition) do
    [MightyFetcher::SortParameterDefinition.new('name')]
  end

  def call_middleware(parameters_definition, params)
    described_class.new(->(env) { env }, parameters_definition).call([pages, params])
  end

  context 'when not allowed sorting given' do
    let(:params) { { sort: '-not_allowed1,name,not_allowed2' } }

    it 'raise SortingNotAllowed error' do
      expect do
        call_middleware(parameters_definition, params)
      end.to raise_error(MightyFetcher::SortOrderValidationFailed)
    end
  end

  context 'when one of sorting given' do
    let(:params) { { sort: 'name' } }

    it 'returns sorted collection and not modified params' do
      scope, parameters = call_middleware(parameters_definition, params)
      expect(scope.map(&:name)).to eq(['Page #0', 'Page #1', 'Page #2'])
      expect(parameters).to eq(params)
    end
  end
end