#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'libusb'
require 'optparse'

$LOAD_PATH << File.dirname(__FILE__)
require 'hidutil'
require 'usbutil'

# libusb doesn't appear to provide the HID class constants.
module HID
  BOOT_PROTOCOL = 0
  REPORT_PROTOCOL = 1

  SET_PROTOCOL = 0x0B
end

SEND_TO_INTERFACE =
  LIBUSB::ENDPOINT_OUT |
  LIBUSB::REQUEST_TYPE_CLASS |
  LIBUSB::RECIPIENT_INTERFACE

raise "Request Type invalid" unless SEND_TO_INTERFACE == 0b00100001

options = {:protocol => 1}
OptionParser.new do |opts|
  opts.on('-v', '--vendor VENDOR', Integer, "Vendor ID") do |x|
    options[:vendor] = x
  end
  opts.on('-p', '--product PRODUCT', Integer, "Product ID") do |x|
    options[:product]  = x
  end
  opts.on('-P', '--protocol PROTOCOL', Integer,  "Protocol") do |x|
    options[:protocol] = x
  end
end.parse(ARGV)

match = {:bClass => LIBUSB::CLASS_HID}
match[:idVendor] = options[:vendor] if options.member? :vendor
match[:idProduct] = options[:product] if options.member? :product
STDERR.puts match.inspect

usb = LIBUSB::Context.new
usb.devices(match).each do |dev|
  STDERR.puts "Setting report on device: #{dev.inspect}"
  dev.open do |devh|
    dev.interfaces.each do |intf|
      STDERR.puts "\tinterface: #{intf.inspect}"
      devh.control_transfer(:bmRequestType => SEND_TO_INTERFACE,
                            :bRequest => HID::SET_PROTOCOL,
                            :wValue => options[:protocol],
                            :wIndex => intf.bInterfaceNumber)
    end
  end
end
