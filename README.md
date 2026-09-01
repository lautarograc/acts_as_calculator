# ActsAsCalculator

A calculation engine for pricing, payroll, tax, and insurance domains. Built on [Dentaku](https://github.com/rubysolo/dentaku).

Add formula-based calculations to any model with `Calculable`. Formulas are versioned, effective-dated, can call other formulas, and render to Liquid templates.

## Install

```ruby
bundle add acts_as_calculator
rails generate acts_as_calculator:install
rails db:migrate
```

## Quick Start

Mix `Calculable` into your model:

```ruby
class Employee < ApplicationRecord
  include ActsAsCalculator::Calculable
end
```

Create a formula:

```ruby
ActsAsCalculator::Formula.create!(key: "net_pay", scope: "payroll")
formula = ActsAsCalculator::Formula.find_by(key: "net_pay")

formula.versions.create!(
  expression: "gross - tax - deductions",
  effective_from: Date.new(2026, 1, 1),
  effective_to: nil,
  status: "active",
  variables: [
    { name: "gross", source_type: "attribute" },
    { name: "tax", source_type: "context" },
    { name: "deductions", source_type: "context" }
  ]
)
```

Calculate:

```ruby
employee = Employee.find(1)

result = employee.calculate(
  :net_pay,
  as_of: Date.new(2026, 3, 15),
  tax: BigDecimal("500"),
  deductions: BigDecimal("200")
)

result.value          # => #<BigDecimal "2300.00">
result.breakdown      # => { expression: "...", inputs: {...}, calls: [...] }
```

## Formulas Calling Formulas

Use `@formula_key` syntax to call other formulas:

```ruby
formula = ActsAsCalculator::Formula.create!(key: "total_deductions", scope: "payroll")

formula.versions.create!(
  expression: "@tax + @insurance + @retirement",
  effective_from: Date.new(2026, 1, 1),
  status: "active",
  variables: [
    { name: "salary", source_type: "attribute" }
  ],
  formula_calls: [
    { key: "tax" },
    { key: "insurance" },
    { key: "retirement" }
  ]
)
```

Each called formula resolves independently at the calculation date. Pin a specific version:

```ruby
formula_calls: [
  { key: "tax", version_id: 2 }  # Always use version 2, ignore as_of
]
```

## Lookup Tables

Use lookup tables for tiered calculations:

```ruby
table = ActsAsCalculator::LookupTable.create!(key: "tax_brackets", scope: "payroll")

table.entries.create!([
  { from: 0, to: 20000, value: BigDecimal("0.10") },
  { from: 20000, to: 50000, value: BigDecimal("0.22") },
  { from: 50000, to: nil, value: BigDecimal("0.32") }
])
```

Reference in formulas:

```ruby
formula.versions.create!(
  expression: "salary * bracket",
  variables: [
    { name: "salary", source_type: "attribute" },
    { name: "bracket", source_type: "lookup",
      source_config: { table: "tax_brackets", using: "salary" } }
  ]
)
```

## Templates

Render results to Liquid templates:

```ruby
ActsAsCalculator::Template.create!(
  key: "payslip",
  scope: "payroll",
  format: "text",
  body: "Net: {{ result.value | currency }}"
)

rendered = employee.render(:payslip, as_of: Date.today, net_pay: result.value)
```

Available filters: `currency`, `percentage`, `date`.

## JSON Import

Define formulas, lookup tables, and templates in JSON:

```json
{
  "lookup_tables": [
    { "key": "tax_brackets", "scope": "payroll",
      "entries": [{ "from": 0, "to": 20000, "value": 0.1 }] }
  ],
  "formulas": [
    { "key": "net_pay", "scope": "payroll",
      "expression": "salary - tax",
      "effective_from": "2026-01-01",
      "status": "active",
      "variables": [{ "name": "salary", "source_type": "attribute" }] }
  ],
  "templates": [
    { "key": "payslip", "scope": "payroll", "format": "text",
      "body": "Net: {{ result.value | currency }}" }
  ]
}
```

Import once or repeatedly:

```bash
rails generate acts_as_calculator:import config/payroll.json
rake acts_as_calculator:import[config/payroll.json]
```

Both run the same logic and report created/updated/skipped counts. Importing is idempotent — unchanged content is skipped, changed content creates a new version.

## API

Enable the REST/JSON API (disabled by default):

```ruby
# config/initializers/acts_as_calculator.rb
ActsAsCalculator.configure { |c| c.enable_api = true }

# config/routes.rb
mount ActsAsCalculator::Engine => "/calculator"
```

Endpoints: `GET/POST /formulas`, `GET/PATCH/DELETE /formulas/:id`, `GET/POST /formulas/:id/versions`, `GET/POST /templates`, `GET/DELETE /templates/:id`, `POST /templates/:id/preview`, `POST /import`.

## Contributing

Issues and PRs welcome at https://github.com/lautarograc/acts_as_calculator.

## License

MIT
