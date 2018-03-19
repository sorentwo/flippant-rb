require "support/examples/adapter"

RSpec.describe Flippant::Adapter::Memory do
  before(:all) do
    Flippant.configure do |config|
      config.adapter = Flippant::Adapter::Memory.new
    end
  end

  before do
    Flippant.clear
  end

  it_behaves_like "Adapter"
end
