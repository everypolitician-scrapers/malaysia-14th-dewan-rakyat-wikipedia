# frozen_string_literal: true

require 'scraped'

class RemoveBrackets < Scraped::Response::Decorator
  def body
    Nokogiri::HTML(super).tap do |doc|
      doc.xpath('//table[.//th[contains(.,"Coalition")]]//td[3]//*[text()[contains(.,"(")]]').remove
    end.to_s
  end
end
