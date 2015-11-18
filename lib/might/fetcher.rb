require 'might/filter_middleware'
require 'might/sort_middleware'
require 'might/result'
require 'uber/inheritable_attr'
require 'middleware'

#
module Might
  # Configure your own fetcher
  #
  #     PagesFetcher < Might::Fetcher
  #       self.resource_class = Page
  #     end
  #
  # You can configure filterable attributes for model
  #
  #     filter :id, validates: { presence: true }
  #     filter :name
  #     filter :start_at, validates: { presence: true }
  #
  # If your property name doesn't match the name in the query string, use the :as option:
  #
  #     filter :kind, as: :type
  #
  # So the Movie#kind property would be exposed to API as :type
  #
  # You may specify allowed sorting order:
  #
  #     sort :id
  #     sort :name
  #
  # If your property name doesn't match the name in the query string, use the :as option:
  #
  #     sort :position, as: :relevance
  #
  # So client should pass +?sort=relevance+ in order to sort by position
  #
  # It's also possible to reverse meaning of the order direction. For example it's not
  # make sense to order by position from lower value to higher.
  # The meaning default for that sorting is reversed order by default, so more relevant elenents
  # would be the first.
  #
  #     sort :position, as: :relevance, reverse_direction: true
  #
  class Fetcher
    extend Uber::InheritableAttr

    inheritable_attr :resource_class
    inheritable_attr :filter_parameters_definition
    inheritable_attr :sort_parameters_definition
    inheritable_attr :middleware_changes

    self.filter_parameters_definition = Set.new
    self.sort_parameters_definition = Set.new
    self.middleware_changes = []

    # @return [Hash]
    attr_reader :params

    # @param params [Hash]
    def initialize(params)
      @params = params
    end

    # @return [ActiveRecord::Result] filtered and sorted collection
    # @yieldparam collection [Result] if a block given
    #
    # @example
    #   PagesFetcher.new(params).call #=> Result
    #
    # @example block syntax
    #   PagesFetcher.new(params) do |result|
    #     if result.success?
    #       result.get
    #     else
    #       result.errors
    #     end
    #   end
    #
    def call
      processed_params, errors = process_params(params)
      result = if errors.any?
                 Failure.new(errors)
               else
                 processed_collection, = middleware.call([collection, processed_params])
                 Success.new(processed_collection)
               end

      if block_given?
        yield result
      else
        result
      end
    end

    private

    # @return [ActiveRecord::Relation]
    def collection
      self.class.resource_class.all
    end

    # Library middleware stack
    # @return [Middleware::Builder]
    def default_middleware
      Middleware::Builder.new do |b|
        b.use FilterMiddleware
        b.use SortMiddleware
      end
    end

    # User modified middleware stack
    # @return [Middleware::Builder]
    def middleware
      default_middleware.tap do |builder|
        self.class.middleware_changes.each do |change|
          builder.instance_eval(&change)
        end
      end
    end

    # @return [Hash, Array] tuple of parameters and processing errors
    #   this errors may be shown to front-end developer
    def process_params(params)
      Middleware::Builder.new do |b|
        b.use FilterParametersExtractor, self.class.filter_parameters_definition
        b.use FilterParametersValidator
        b.use SortParametersExtractor, self.class.sort_parameters_definition
        b.use SortParametersValidator
      end.call([params, []])
    end

    class << self
      # Alter middleware chain with the given block
      # @param [Proc] change
      # @return [Might]
      #
      # @example
      #   class ChannelsFetcher
      #     middleware do
      #       use CustomMiddleware
      #     end
      #   end
      #
      def middleware(&change)
        fail ArgumentError unless block_given?
        middleware_changes << change
        self
      end

      # Register collection sorting by its name
      # @param name [Symbol] of the field
      # @return [void]
      # @see +RansackableSort+ for details
      #
      def sort(name, options = {})
        definition = SortParameterDefinition.new(name, options)
        sort_parameters_definition.add(definition)
      end

      # Register collection filter by its name
      # @see +Might::Filter+ for details
      #
      # @overload filter(filter_name, options)
      #   @param [Symbol] filter_name
      #   @param [Hash] options
      #   @return [void]
      # @example
      #   filter :genre_name, on: :resource
      #
      # @overload filter(filter_name: predicates, **options)
      #   @param [Symbol] filter_name
      #   @param [<Symbol>] predicates
      #   @param [Hash] other options options
      #   @return [void]
      # @example
      #   filter genre_name: [:eq, :in], on: :resource
      #
      def filter(*args)
        options = args.extract_options!
        if args.empty?
          filter_name = options.keys.first
          predicates = options.values.first
          options = options.except(filter_name).merge(predicates: predicates)
        else
          filter_name = args.first
        end

        definition = FilterParameterDefinition.new(filter_name, options)
        filter_parameters_definition.add(definition)
      end

      # @param params [Hash] user provided input
      # @yieldparam collection [ActiveRecord::Relation]
      def run(params, &block)
        new(params).call(&block)
      end

      # Add middleware to the end of middleware chane
      # When only one argument given, it is treated as scope. So the lambda must
      # return modified scope:
      #
      #   class MovieFetcher
      #     after do |scope|
      #       # do something with scope
      #       scope.map(&:resource)
      #     end
      #   end
      #
      # When two arguments given, they are treated as scope and params. So the lambda must
      # return tuple:
      #
      #   class MovieFetcher
      #     after do |scope, params|
      #       # do something with scope and params
      #       [scope.map(&:resource), params]
      #     end
      #   end
      #
      def after(&block)
        alter_middleware(:use, &block)
      end

      # Add middleware to the beginning of middleware chane
      # When only one argument given, it is treated as scope. So the lambda must
      # return modified scope:
      #
      #   class MovieFetcher
      #     before do |scope|
      #       # do something with scope
      #       scope.map(&:resource)
      #     end
      #   end
      #
      # When two arguments given, they are treated as scope and params. So the lambda must
      # return tuple:
      #
      #   class MovieFetcher
      #     before do |scope, params|
      #       # do something with scope and params
      #       [scope.map(&:resource), params]
      #     end
      #   end
      #
      def before(middleware_or_index = 0, &block)
        alter_middleware(:insert_before, middleware_or_index, &block)
      end

      private

      def alter_middleware(method_name, *args, &block)
        fail ArgumentError unless block_given?
        middleware_changes.push lambda { |builder|
          builder.send method_name, *args, lambda { |env|
            scope, params = env
            case block.arity
            when 1
              [block.call(scope), params]
            when 2
              block.call(scope, params).tap do |r|
                if !r.is_a?(Array) || r.size != 2
                  fail 'After block must return tuple of scope and params'
                end
              end
            else
              fail "Wrong number of arguments (#{block.arity} for 0..2)"
            end
          }
        }
      end
    end
  end
end