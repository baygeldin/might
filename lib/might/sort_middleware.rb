# frozen_string_literal: true
module Might
  # Sort scope using ransack gem
  #
  class SortMiddleware
    # @param app [#call]
    #
    def initialize(app)
      @app = app
    end

    attr_reader :app

    # @param [Array(ActiveRecord::Relation, Hash)] env
    # First argument is a ActiveRecord relation which must be sorted
    # Second argument is a request parameters provided by user
    #
    def call(env)
      scope, = ::Middleware::Builder.new do |b|
        b.use RansackableSortParametersAdapter
        b.use RansackableSort
      end.call(env)

      app.call([scope, env[1]])
    end
  end
end
