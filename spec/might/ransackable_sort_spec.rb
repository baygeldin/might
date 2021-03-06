# frozen_string_literal: true
require 'database_helper'

RSpec.describe Might::RansackableSort, database: true do
  let(:pages) { Page.all }

  def call_middleware(params)
    described_class.new(->(env) { env }).call([pages, params])
  end

  it 'sort using ransack' do
    scope, = call_middleware(sort: ['name asc'])
    expect(scope.map(&:name)).to eq(['Page #0', 'Page #1', 'Page #2'])
  end
end
