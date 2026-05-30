# ActsAsCalculator

[![Gem Version](https://badge.fury.io/rb/acts_as_calculator.svg)](https://badge.fury.io/rb/acts_as_calculator)

A pricing and calculation engine built on [Dentaku](https://github.com/rubysolo/dentaku). Mix `Calculable` into any model to get effective-dated, versioned formulas; apportionment and aggregation helpers; and Liquid-rendered output — reusable across payroll, e-commerce, and insurance domains.

## Installation

    $ bundle add acts_as_calculator

or add to your Gemfile:

    gem "acts_as_calculator"

Then run the install generator:

    $ rails generate acts_as_calculator:install
    $ rails db:migrate

## Usage

Mix `Calculable` into any model:

```ruby
class Employee < ApplicationRecord
  include ActsAsCalculator::Calculable
end
```

Calculate using an effective-dated formula:

```ruby
employee = Employee.find(1)

result = employee.calculate(
  :monthly_tax,
  as_of: Date.new(2026, 3, 15),
  base_salary: 60_000,
  dependents: 2
)

puts result.value      # => #<BigDecimal "2500.00">
puts result.breakdown  # => { expression: "...", inputs: {...} }
```

Store formulas with effective dates:

```ruby
formula = Calculator::Formula.create!(
  key: "monthly_tax",
  scope: "payroll"
)

formula.versions.create!(
  expression: "salary * 0.22",
  effective_from: Date.new(2026, 1, 1),
  effective_to: Date.new(2026, 6, 30),
  variables: [
    { name: "salary", source_type: "attribute" }
  ]
)
```

Render results into templates:

```ruby
template = Calculator::Template.create!(
  key: "payslip",
  scope: "payroll",
  format: "text",
  body: "Gross: {{ result.value | currency }}\nTax: {{ tax_result.value | currency }}"
)

rendered = employee.render(:payslip, calculate: :monthly_tax, as_of: Date.today)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lautarograc/acts_as_calculator. This project follows the [code of conduct](https://github.com/lautarograc/acts_as_calculator/blob/main/CODE_OF_CONDUCT.md).

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
