# frozen_string_literal: true

RSpec.describe ActsAsCalculator::RenderLiquid do
  def render(source, assigns = {})
    described_class.(source:, assigns:)
  end

  it "interpolates assigned primitives" do
    expect(render("Hello {{ name }}", { "name" => "Ada" })).to eq("Hello Ada")
  end

  it "runs the tags a template author actually needs" do
    source = "{% for line in lines %}{{ line }};{% endfor %}{% if total %}={{ total }}{% endif %}"

    expect(render(source, { "lines" => %w[a b], "total" => 2 })).to eq("a;b;=2")
  end

  describe "the sandbox" do
    let(:sensitive) do
      Class.new do
        attr_reader :destroyed, :secret

        def initialize
          @destroyed = false
          @secret = "s3cret"
        end

        def destroy
          @destroyed = true
        end
      end.new
    end

    let(:drop) do
      Class.new(Liquid::Drop) do
        def initialize(target)
          super()
          @target = target
        end

        def label
          "safe"
        end

        private

        attr_reader :target
      end.new(sensitive)
    end

    it "exposes only the methods the drop declares" do
      expect(render("{{ record.label }}", { "record" => drop })).to eq("safe")
    end

    it "renders nothing for a method the drop did not declare, and never calls it" do
      expect(render("[{{ record.destroy }}]", { "record" => drop })).to eq("[]")
      expect(sensitive.destroyed).to be(false)
    end

    it "closes bracket lookup as well as dot access" do
      expect(render('[{{ record["destroy"] }}]', { "record" => drop })).to eq("[]")
      expect(sensitive.destroyed).to be(false)
    end

    it "refuses a bang method at parse time — strict mode will not even tokenise it" do
      expect { render("{{ record.destroy! }}", { "record" => drop }) }
        .to raise_error(ActsAsCalculator::TemplateRenderError, /Unexpected character/)
    end

    it "cannot reach the object a drop wraps" do
      expect(render("[{{ record.target.secret }}][{{ record.secret }}]", { "record" => drop })).to eq("[][]")
    end

    it "cannot reach Ruby's own dispatch and reflection methods" do
      source = "[{{ record.send }}][{{ record.class }}][{{ record.instance_variable_get }}][{{ record.public_send }}]"

      expect(render(source, { "record" => drop })).to eq("[][][][]")
    end

    it "has no tag that reads from a file system" do
      %w[include render].each do |tag|
        expect { render("{% #{tag} 'config/secrets' %}") }
          .to raise_error(ActsAsCalculator::TemplateRenderError, /Unknown tag '#{tag}'/)
      end
    end

    it "renders in its own Liquid environment, not the process-global default" do
      expect(described_class::SANDBOX).not_to be(Liquid::Environment.default)
      expect(described_class::SANDBOX.file_system).to be_a(Liquid::BlankFileSystem)
    end

    it "keeps its filters out of the host app's own Liquid usage" do
      expect(Liquid::Environment.default.filter_method_names).not_to include("percentage")
      expect(described_class::SANDBOX.filter_method_names).to include("currency", "percentage", "date")
    end

    it "bounds how much output one template may produce" do
      expect(described_class::RESOURCE_LIMITS[:render_length_limit]).to be_a(Integer)

      source = "{% assign row = 'x' %}{% for n in (1..5000) %}#{"y" * 1000}{% endfor %}"

      expect { render(source) }.to raise_error(ActsAsCalculator::TemplateRenderError, /Memory limits/)
    end

    describe "bounding iteration" do
      it "refuses a large empty-bodied loop, which emits nothing and so scores nothing" do
        expect { render("{% for i in (1..30000000) %}{% endfor %}ok") }
          .to raise_error(ActsAsCalculator::TemplateRenderError, /exceeded #{described_class::MAX_ITERATIONS}/)
      end

      it "refuses the loop before Liquid materialises the range with Range#to_a" do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        expect { render("{% for i in (1..2000000000) %}{% endfor %}") }
          .to raise_error(ActsAsCalculator::TemplateRenderError)

        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
      end

      it "still refuses when a limit: would have sliced the range down" do
        expect { render("{% for i in (1..50000000) limit: 10 %}x{% endfor %}") }
          .to raise_error(ActsAsCalculator::TemplateRenderError, /exceeded/)
      end

      it "refuses an oversized collection that arrived through the assigns" do
        expect { render("{% for l in lines %}{% endfor %}", { "lines" => (1..500_000).to_a }) }
          .to raise_error(ActsAsCalculator::TemplateRenderError, /exceeded/)
      end

      it "counts nested loops against one budget" do
        expect { render("{% for a in (1..1000) %}{% for b in (1..1000) %}{% endfor %}{% endfor %}") }
          .to raise_error(ActsAsCalculator::TemplateRenderError, /exceeded/)
      end

      it "counts sequential loops against one budget" do
        source = "{% for a in (1..9000) %}{% endfor %}{% for b in (1..9000) %}{% endfor %}"

        expect { render(source) }.to raise_error(ActsAsCalculator::TemplateRenderError, /exceeded/)
      end

      it "starts each render with a fresh budget" do
        source = "{% for i in (1..9000) %}{% endfor %}ok"

        expect(render(source)).to eq("ok")
        expect(render(source)).to eq("ok")
      end

      it "leaves a template that loops over a realistic number of line items alone" do
        rendered = render("{% for l in lines %}{{ l }};{% endfor %}", { "lines" => (1..50).to_a })

        expect(rendered).to eq((1..50).map { |n| "#{n};" }.join)
      end

      it "allows a loop right up to the cap" do
        expect(render("{% for i in (1..#{described_class::MAX_ITERATIONS}) %}{% endfor %}done")).to eq("done")
      end

      it "has no tag that iterates outside the bounded one" do
        expect { render("{% tablerow i in (1..3) %}x{% endtablerow %}") }
          .to raise_error(ActsAsCalculator::TemplateRenderError, /Unknown tag 'tablerow'/)
      end
    end

    it "rejects a misspelled filter instead of silently rendering the unfiltered value" do
      expect { render("{{ amount | currancy }}", { "amount" => 5 }) }
        .to raise_error(ActsAsCalculator::TemplateRenderError, /undefined filter/)
    end

    it "reports a malformed template as a render error rather than emitting it verbatim" do
      expect { render("{% if %}{% endif %}") }.to raise_error(ActsAsCalculator::TemplateRenderError)
    end

    it "leaves an unknown variable blank rather than raising" do
      expect(render("[{{ nowhere.at.all }}]")).to eq("[]")
    end
  end
end
