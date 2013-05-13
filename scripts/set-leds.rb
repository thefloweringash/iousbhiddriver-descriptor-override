#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'libusb'

$LOAD_PATH << File.dirname(__FILE__)
require 'hidutil'
require 'usbutil'

# libusb doesn't appear to provide the HID class constants.
module HID
  SET_REPORT = 0x09
  REPORT_TYPE_OUTPUT = 0x02
  USAGE_PAGE_LED = 0x08
  LED_USAGE_CAPS_LOCK = 0x02
end

class Output
  def initialize(interface)
    @interface = interface
  end

  def to_s
    "Output for #{@interface.device.product} interface #{@interface.bInterfaceNumber}"
  end

  def set(data)
    @interface.device.open do |devh|
      devh.control_transfer(:bmRequestType => SEND_TO_INTERFACE,
                            :bRequest      => HID::SET_REPORT,
                            :wValue        => (HID::REPORT_TYPE_OUTPUT << 8) | 0,
                            :wIndex        => @interface.bInterfaceNumber,
                            :dataOut       => data)
    end
  end

  private

  SEND_TO_INTERFACE =
    LIBUSB::ENDPOINT_OUT |
    LIBUSB::REQUEST_TYPE_CLASS |
    LIBUSB::RECIPIENT_INTERFACE
end


def find_all_caps_locks
  leds = []

  usb = LIBUSB::Context.new
  usb.devices(:bClass => LIBUSB::CLASS_HID).each do |dev|
    USBUtil.hid_interfaces(dev) do |intf|
      items = HIDInfo.parse(StringIO.new(USBUtil.get_hid_report_descriptor(intf)))
      if items.any? &:is_ambiguous?
        leds.concat items.select {
          |x| x.includes_usage?(HID::USAGE_PAGE_LED, HID::LED_USAGE_CAPS_LOCK)
        }.map { |x| Output.new(intf) }
      end
    end
  end

  return leds
end

# We only verify that the interface has a caps lock somewhere in the
# output and take a hasty approach of assuming that this is a common
# single-byte bitfield of 3 indicator leds and set them all. This can
# be overwridden by specifying a value to send as the first argument.
data = (ARGV.first.to_i.chr if ARGV.any?) || (0x1 | 0x2 | 0x4).chr

outputs = find_all_caps_locks
outputs.each do |output|
  puts "Setting output: #{output.to_s} to #{data.inspect}"
  begin
    output.set data
  rescue => e
    puts "Exception while setting output, #{e}"
  end
end

if outputs.empty?
  puts "No Noppoo keyboards detected"
end
