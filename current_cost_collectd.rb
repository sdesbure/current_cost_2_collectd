#! /usr/bin/env ruby

require 'em-serialport'
require 'collectd'
require 'nokogiri'

# Names and values to output
@data = {
# src:         '//src',
# dsb:         '//dsb',
# time:        '//time',
  sensor:      '//sensor',
# id:          '//id',
# type:        '//type',
  temperature: '//tmpr',
  power:       '//ch1/watts',
}

@debug = !ENV['DEBUG].nil?

def parse_data data, stats
  xml = Nokogiri::XML data
  begin
    sensor = xml.at_xpath(@data[:sensor])
    unless sensor.nil?
      id = sensor.children.to_s
      stats[id] ||= {}
      temp_xpath = xml.at_xpath(@data[:temperature])
      stats[id][:temperature] = temp_xpath.children.to_s.to_f unless temp_xpath.nil?
      power_xpath = xml.at_xpath(@data[:power])
      stats[id][:power] = power_xpath.children.to_s.to_f unless power_xpath.nil?
      if @debug
        puts "[#{Time.now}]: retrieved temperature #{stats[id][:temperature]} and power #{stats[id][:power]} for sensor #{id}" unless temp_xpath.nil? && power_xpath.nil?
        puts "[#{Time.now}]: retrieved no temperature and power #{stats[id][:power]} for sensor #{id}" if temp_xpath.nil? && !power_xpath.nil?
        puts "[#{Time.now}]: retrieved temperature #{stats[id][:temperature]} and no power for sensor #{id}" if !temp_xpath.nil? && power_xpath.nil?
        puts "[#{Time.now}]: retrieved no temperature and no power for sensor #{id}" if temp_xpath.nil? && power_xpath.nil?
      end
    else
      puts "[#{Time.now}]: Problem grabbing XML info: no sensor id found"
      puts xml.to_s
    end
  rescue
    puts "[#{Time.now}]: Problem grabbing XML info"
    puts data
  end
  stats
end

EM.run do
  @line = ""
  @stats = { "0" => {temperature: 0.0, power: 0.0}, "2" => {temperature: 0.0, power: 0.0}}
  Collectd::use_eventmachine = true
  Collectd.add_server(interval=10, addr="192.168.1.6")
  stats_main = Collectd.current_cost(:main)
  stats_pac = Collectd.current_cost(:pac)
  stats_main.with_full_proc_stats
  stats_pac.with_full_proc_stats
  serial = EventMachine.open_serial('/dev/ttyUSB0', 57600, 8, 1, 0)
  serial.on_data do |data|
    @line += data
    if @line.include? "</msg>"
      @stats = parse_data @line, @data
      @line = ""
    end
  end
  stats_main.temperature(:temperature).polled_gauge do
    puts "[#{Time.now}]: sending temperature #{@stats["0"][:temperature]} for main" if @debug
    @stats["0"][:temperature]
  end
  stats_pac.temperature(:temperature).polled_gauge do
    puts "[#{Time.now}]: sending temperature #{@stats["2"][:temperature]} for pac" if @debug
    @stats["2"][:temperature]
  end
  stats_main.power(:power).polled_gauge do
    puts "[#{Time.now}]: sending power #{@stats["0"][:power]} for main" if @debug
    @stats["0"][:power]
  end
  stats_pac.power(:power).polled_gauge do
    puts "[#{Time.now}]: sending power #{@stats["2"][:power]} for pac" if @debug
    @stats["2"][:power]
  end
end
