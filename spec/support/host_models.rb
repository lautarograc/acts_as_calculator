# frozen_string_literal: true

class SpecDepartment < ActiveRecord::Base
  self.table_name = "spec_departments"
end

class SpecEmployee < ActiveRecord::Base
  self.table_name = "spec_employees"

  include ActsAsCalculator::Calculable

  calculator_scope :payroll

  belongs_to :spec_department, optional: true

  def annual_salary
    salary * 12
  end
end

class SpecTenantEmployee < SpecEmployee
  def calculator_owner
    spec_department
  end
end

class SpecOrder < ActiveRecord::Base
  self.table_name = "spec_orders"

  include ActsAsCalculator::Calculable
end
