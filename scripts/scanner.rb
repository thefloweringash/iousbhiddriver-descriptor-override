#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'libusb'
require 'pp'
require 'yaml'

$LOAD_PATH << File.dirname(__FILE__)
require 'hidutil'
require 'usbutil'

usb = LIBUSB::Context.new
usb.devices(:bClass => LIBUSB::CLASS_HID).each do |dev|
  STDERR.puts "Checking device: #{dev.inspect}"
  safe_filename = dev.product.gsub(/[^A-Za-z]/, '_')
  filename = File.join('descriptors',
                       sprintf("%04x-%04x-%s.yaml", dev.idVendor, dev.idProduct, safe_filename))
  ambiguous_descriptors = []

  USBUtil.hid_interfaces(dev) do |intf|
    begin
      report_descriptor = USBUtil.get_hid_report_descriptor(intf)
      items = HIDInfo.parse(StringIO.new report_descriptor)

      if items.any? &:is_ambiguous?
        STDERR.puts "Found ambiguity!"
        ambiguous_descriptors << {
          'idVendor' => dev.idVendor,
          'idProduct' => dev.idProduct,
          'bcdDevice' => dev.bcdDevice,
          'bConfigurationValue' => intf.settings.first.configuration.bConfigurationValue,
          'bInterfaceNumber' => intf.bInterfaceNumber,
          'hidReportDescriptor' => report_descriptor,
        }
      end
    rescue => e
      STDERR.puts "Ignoring exception \"#{e}\" processing #{intf.inspect}"
    end
  end

  if !ambiguous_descriptors.empty?
    STDERR.puts "Writing details to #{filename}"
    File.open(filename, 'w') do |f|
      f.write YAML.dump_stream(ambiguous_descriptors)
    end
  end
end
