require 'yaml'

require "piece/version"
require 'piece/rules'

module Piece
  module_function
  def load(rules)
    Rules.new(YAML.load(rules))
  end
end
