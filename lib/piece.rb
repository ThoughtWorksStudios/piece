require 'yaml'

require "piece/version"
require 'piece/pieces'

module Piece
  module_function
  def load(pieces)
    Pieces.new(YAML.load(pieces))
  end
end
