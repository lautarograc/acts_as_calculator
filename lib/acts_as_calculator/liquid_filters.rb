# frozen_string_literal: true

require "bigdecimal"
require "date"

module ActsAsCalculator
  module LiquidFilters
    DELIMITER = ","
    ISO_DATE = "%Y-%m-%d"

    def currency(input, unit = "", precision = 2)
      return "" if blank_input?(input)

      places = Integer(precision)
      "#{unit}#{delimited(FunctionRegistry::ROUND_CURRENCY.(numeric(input), places), places)}"
    end

    def percentage(input, precision = 2)
      return "" if blank_input?(input)

      places = Integer(precision)
      "#{delimited(FunctionRegistry::ROUND_CURRENCY.(numeric(input) * 100, places), places)}%"
    end

    def date(input, format = ISO_DATE)
      point = time_like(input)

      point.nil? ? "" : point.strftime(format.to_s)
    end

    private

    def blank_input?(input)
      input.nil? || input == ""
    end

    def numeric(input)
      CastDecimal.(input.is_a?(ResultDrop) ? input.value : input)
    end

    def delimited(decimal, places)
      whole, fraction = decimal.abs.to_s("F").split(".")
      grouped = whole.reverse.scan(/\d{1,3}/).join(DELIMITER).reverse
      sign = decimal.negative? ? "-" : ""

      places.positive? ? "#{sign}#{grouped}.#{fraction.to_s.ljust(places, "0")[0, places]}" : "#{sign}#{grouped}"
    end

    def time_like(input)
      case input
      when nil, "" then nil
      when ::Date, ::Time then input
      when ::Integer then ::Time.at(input)
      when ::String then parsed_date(input)
      else input if input.respond_to?(:strftime)
      end
    end

    def parsed_date(input)
      ::Date.parse(input)
    rescue ::Date::Error
      nil
    end
  end
end
