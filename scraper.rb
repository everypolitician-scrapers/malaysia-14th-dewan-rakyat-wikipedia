#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_brackets'
require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator RemoveNotes
  decorator RemoveBrackets

  field :members do
    members_tables.xpath('.//tr[td[2]]').map { |tr| data = fragment(tr => MemberRow).to_h }
  end

  private

  def members_tables
    noko.xpath('//table[.//th[contains(.,"Coalition")]]')
  end
end

class MemberRow < Scraped::HTML
  field :name do
    tds[2].text.sub(/\(.*/, '').tidy
  end

  field :id do
    tds[2].css('a/@wikidata').map(&:text).first
  end

  field :coalition do
    tds[3].text.sub(/\(.*/, '').tidy
  end

  field :coalition_id do
    party_summary_row.css('a').select { |a| a.text.tidy == coalition }.map { |a| a.attr('wikidata') }.first
  end

  field :area do
    tds[1].text.tidy
  end

  field :area_id do
    tds[1].css('a/@wikidata').map(&:text).first
  end

  private

  def tds
    noko.css('td')
  end

  def party_summary_row
    noko.xpath('preceding::tr[td[@colspan]]').last
  end
end

url = 'https://en.wikipedia.org/wiki/Members_of_the_Dewan_Rakyat,_14th_Malaysian_Parliament'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name area coalition])
