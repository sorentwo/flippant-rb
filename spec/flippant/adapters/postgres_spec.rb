require "support/examples/adapter"

RSpec.describe Flippant::Adapter::Postgres do
  before(:all) do
    Flippant.configure do |config|
      ActiveRecord::Base.establish_connection("postgres:///flippant_test")

      config.adapter = Flippant::Adapter::Postgres.new
    end

    Flippant.setup
  end

  before do
    Flippant.clear
  end

  it_behaves_like "Adapter"
end
