require 'mighty_fetcher/sort/parameter'
require 'mighty_fetcher/sort/parameter_definition'

RSpec.describe MightyFetcher::Sort::Parameter do
  context '#direction' do
    subject(:parameter) { described_class.new(:asc, definition) }
    subject(:direction) { parameter.direction }

    context 'when reversed direction defined' do
      let(:definition) { MightyFetcher::Sort::ParameterDefinition.new(:relevance, reverse_direction: true) }

      it 'returns opposite direction' do
        is_expected.to eq('desc')
      end
    end

    context 'when no reversed direction defined' do
      let(:definition) { MightyFetcher::Sort::ParameterDefinition.new(:relevance) }

      it 'returns the same direction' do
        is_expected.to eq('asc')
      end
    end
  end
end
