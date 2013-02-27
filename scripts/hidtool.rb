#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'yaml'
require 'pp'

require_relative 'hidutil'

def main
  command = ARGV[0]
  case command
  when 'parse'
    pp HIDInfo.parse(STDIN)
  when 'parse-fix'
    pp HIDInfo.fix(HIDInfo.parse(STDIN))
  when 'tagstream'
    puts HIDInfo.tagstream(STDIN).to_yaml
  when 'parse-tagstream'
    print HIDInfo.items_to_tag_stream(HIDInfo.parse(STDIN)).to_yaml
  when 'parse-fix-tagstream'
    print HIDInfo.items_to_tag_stream(HIDInfo.fix(HIDInfo.parse(STDIN))).to_yaml
  when 'encode'
    print HIDInfo.encode(YAML.load(STDIN))
  end
end

main
