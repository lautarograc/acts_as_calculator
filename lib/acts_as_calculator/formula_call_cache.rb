# frozen_string_literal: true

module ActsAsCalculator
  class FormulaCallCache
    STORE_KEY = :acts_as_calculator_formula_call_cache

    def self.current
      Thread.current[STORE_KEY]
    end

    # Opens a chain, or joins the one already open, and yields the cache.
    def self.around
      return yield(current) if current

      Thread.current[STORE_KEY] = new
      begin
        yield(current)
      ensure
        Thread.current[STORE_KEY] = nil
      end
    end

    def initialize
      @results = {}
      @path = []
    end

    def path
      @path.dup
    end

    def fetch(formula_version_id, as_of)
      cache_key = [formula_version_id, as_of]
      return @results[cache_key] if @results.key?(cache_key)

      @results[cache_key] = yield
    end

    def enter(key)
      raise_cycle(key) if @path.include?(key)

      @path.push(key)
      begin
        yield
      ensure
        @path.pop
      end
    end

    private

    def raise_cycle(key)
      raise FormulaCallCycleError, "formula calls form a cycle: #{(@path + [key]).join(" -> ")}"
    end
  end
end
