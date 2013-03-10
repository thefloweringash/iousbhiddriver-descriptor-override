#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'libusb'
require 'pp'
require 'yaml'

$LOAD_PATH << File.dirname(__FILE__)
require 'hidutil'

def get_hid_report_descriptor(devh, intf)
  hid_descriptor = devh.control_transfer(:bmRequestType =>  LIBUSB::ENDPOINT_IN | LIBUSB::RECIPIENT_INTERFACE,
                                         :bRequest => LIBUSB::REQUEST_GET_DESCRIPTOR,
                                         :wValue => (LIBUSB::DT_HID << 8) | 0,
                                         :wIndex => intf.bInterfaceNumber,
                                         :dataIn => 9)
  report_descriptor_length = hid_descriptor[7..9].unpack('v').first
  devh.control_transfer(:bmRequestType =>  LIBUSB::ENDPOINT_IN | LIBUSB::RECIPIENT_INTERFACE,
                        :bRequest => LIBUSB::REQUEST_GET_DESCRIPTOR,
                        :wValue => (LIBUSB::DT_REPORT << 8) | 0,
                        :wIndex => intf.bInterfaceNumber,
                        :dataIn => report_descriptor_length)
end
usb = LIBUSB::Context.new
usb.devices(:bClass => LIBUSB::CLASS_HID).each do |dev|
  dev.open do |devh|
    STDERR.puts "Checking device: #{dev.inspect}"
    safe_filename = dev.product.gsub(/[^A-Za-z]/, '_')
    filename = File.join('descriptors',
                         sprintf("%04x-%04x-%s.yaml", dev.idVendor, dev.idProduct, safe_filename))
    ambiguous_descriptors = []

    dev.interfaces.each do |intf|
      begin
        default_settings = intf.settings.first
        next if default_settings.bInterfaceClass != LIBUSB::CLASS_HID
        report_descriptor = get_hid_report_descriptor(devh, intf)
        items = HIDInfo.parse(StringIO.new report_descriptor)

        if items.any? &:is_ambiguous?
          STDERR.puts "Found ambiguity!"
          ambiguous_descriptors << {
            'idVendor' => dev.idVendor,
            'idProduct' => dev.idProduct,
            'bcdDevice' => dev.bcdDevice,
            'bConfigurationValue' => default_settings.configuration.bConfigurationValue,
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
end
