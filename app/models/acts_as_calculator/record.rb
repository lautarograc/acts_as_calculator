# frozen_string_literal: true

module ActsAsCalculator
  class Record < ::ActiveRecord::Base
    self.abstract_class = true

    self.belongs_to_required_by_default = true
  end
end
