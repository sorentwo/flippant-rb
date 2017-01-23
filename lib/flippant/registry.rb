module Flippant
  class Registry
    def initialize
      clear
    end

    def register(group, fun)
      table[group.to_s] = fun
    end

    def registered
      table
    end

    def clear
      @table = {}
    end

    private

    attr_reader :table
  end
end
