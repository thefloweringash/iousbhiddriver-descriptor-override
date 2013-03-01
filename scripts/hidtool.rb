#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'yaml'
require 'pp'

$LOAD_PATH << File.dirname(__FILE__)
require 'hidutil'

def pretty_tagstream(tagstream, ostream)
  tagstream.each do |i|
    data_str = if i[:len] != 0
                 data = pack_num(i[:data]).unpack('C*').inspect
               end
    tag_name = i[:tag].split('_').map(&:capitalize).join('_')
    ostream.puts "\t#{tag_name}#{data_str || ""}"
  end
end

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
  when 'explain-fix'
    in_filename = ARGV[1]
    interfaces = YAML.load_file(in_filename)
    File.open("#{in_filename}-original", "w") do |original|
      File.open("#{in_filename}-modified", "w") do |modified|
        interfaces.each do |intf|
          original.puts "Original Interface: #{intf['bInterfaceNumber']}"
          pretty_tagstream(HIDInfo.tagstream(StringIO.new intf['hidReportDescriptor']),
                           original)

          modified.puts "Modified Interface: #{intf['bInterfaceNumber']}"
          pretty_tagstream(HIDInfo.fixed_tagstream(StringIO.new intf['hidReportDescriptor']),
                           modified)
        end
      end
    end
    puts %x{diff -y #{in_filename}-original #{in_filename}-modified}
  end
end

main
