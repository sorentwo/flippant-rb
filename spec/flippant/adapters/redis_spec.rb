require "support/examples/adapter"

RSpec.describe Flippant::Adapter::Redis do
  before(:all) do
    Flippant.configure do |config|
      config.adapter = Flippant::Adapter::Redis.new
    end
  end

  before do
    Flippant.clear
  end

  it_behaves_like "Adapter"
end
