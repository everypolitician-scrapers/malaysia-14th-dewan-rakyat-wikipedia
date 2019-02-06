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

class String
  def to_date
    return if tidy.empty?
    Date.parse self
  end
end

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator RemoveNotes
  decorator RemoveBrackets
  decorator UnspanAllTables

  field :members do
    members_tables.xpath('.//tr[td[1][starts-with(.,"P")]]').map { |tr| data = fragment(tr => MemberRow).to_h }
  end

  private

  def members_tables
    noko.xpath('//table[.//th[contains(.,"Constituency")]]')
  end
end

class MemberRow < Scraped::HTML
  field :name do
    name_cell_parts.first.text.sub(/\(.*/, '').tidy
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

  field :area_number do
    tds[0].text.tidy
  end

  field :area_id do
    tds[1].css('a/@wikidata').map(&:text).first
  end

  field :start_date do
    name_cell_parts.drop(1).map(&:text).find { |n| n.include? 'from' }&.to_date
  end

  field :end_date do
    name_cell_parts.drop(1).map(&:text).find { |n| n.include? 'until' }&.to_date
  end

  field :term do
    url[/(\d+)/, 1].to_i
  end

  private

  def tds
    noko.css('td')
  end

  def party_summary_row
    noko.xpath('..//tr[td]').first
  end

  def name_cell_parts
    parts = tds[2].xpath('*')
    parts.any? ? parts : [tds[2]]
  end
end

def data_for(url)
  Scraped::Scraper.new(url => MembersPage).scraper.members
end

data = data_for('https://en.wikipedia.org/wiki/Members_of_the_Dewan_Rakyat,_12th_Malaysian_Parliament') +
       data_for('https://en.wikipedia.org/wiki/Members_of_the_Dewan_Rakyat,_13th_Malaysian_Parliament') +
       data_for('https://en.wikipedia.org/wiki/Members_of_the_Dewan_Rakyat,_14th_Malaysian_Parliament')

data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[term name area coalition], data)
