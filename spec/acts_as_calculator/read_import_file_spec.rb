# frozen_string_literal: true

require "tmpdir"

RSpec.describe ActsAsCalculator::ReadImportFile do
  def write(contents)
    path = File.join(@tmpdir, "import.json")
    File.write(path, contents)
    path
  end

  around do |example|
    Dir.mktmpdir("acts_as_calculator_read") do |tmpdir|
      @tmpdir = tmpdir
      example.run
    end
  end

  it "parses a JSON object" do
    expect(described_class.(write('{"formulas": []}'))).to eq({ "formulas" => [] })
  end

  it "raises when the file does not exist" do
    expect { described_class.(File.join(@tmpdir, "missing.json")) }
      .to raise_error(ActsAsCalculator::ImportError, /no import file at/)
  end

  it "raises with the parser's complaint when the JSON is malformed" do
    expect { described_class.(write("{ nope")) }
      .to raise_error(ActsAsCalculator::ImportError, /is not valid JSON/)
  end

  it "raises when the document is not an object" do
    expect { described_class.(write("[1, 2]")) }
      .to raise_error(ActsAsCalculator::ImportError, /must contain a JSON object/)
  end
end
