require 'open-uri'
require 'rexml'

module OPenn
  class Tei
    attr_reader :document
    def initialize url
      @document = REXML::Document.new URI.open url
    end

    def main_lang
      langs = document.root.get_elements '//textLang[@mainLang]'
      return if langs.empty?
      langs.first['mainLang']
    end
  end
end