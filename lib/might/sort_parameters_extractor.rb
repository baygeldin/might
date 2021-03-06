# frozen_string_literal: true
module Might
  # User provided sorting syntax:
  #   * `name` - sort by name
  #   * `-name` - sort by name in reversed order
  #   * `-name,created_at` - sort by name in reversed order, and then sort by created_at
  #
  # This middleware parses sorting string and builds Parameter array
  # @see Might::Sort::Parameter
  #
  # If user passes not defined sort order, it yields to `UndefinedParameter`, so you may
  # validate it.
  #
  class SortParametersExtractor
    # @param app [#call]
    # @param parameters_definition [Set<Might::SortParameterDefinition>]
    def initialize(app, parameters_definition)
      @app = app
      @parameters_definition = parameters_definition
    end

    # @param env [<String, []>]
    #   * first element is a scope to be sorted
    #   * second is a String with user provided sortings
    # @return [<<Might::RansackableSort::SortParameter, []>]
    #
    def call(env)
      params, errors = env

      sort_params = sort_order(params[:sort]).map do |(attribute, direction)|
        extract_parameter(attribute, direction)
      end

      app.call([params.merge(sort: sort_params), errors])
    end

    private

    attr_reader :parameters_definition, :app

    def extract_parameter(name, direction)
      definition = parameters_definition.detect { |d| d.as == name } || SortUndefinedParameter.new(name)
      SortParameter.new(direction, definition)
    end

    def sort_order(params)
      String(params).split(',').map do |attribute|
        sorting_for(attribute)
      end
    end

    def sorting_for(field)
      if field.start_with?('-')
        [field.delete('-'), 'desc']
      else
        [field, 'asc']
      end
    end
  end
end
