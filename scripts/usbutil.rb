class USBUtil
  def self.get_hid_report_descriptor(intf)
    intf.device.open do |devh|
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
  end

  def self.hid_interfaces(dev)
    dev.interfaces.each do |intf|
      default_settings = intf.settings.first
      next if default_settings.bInterfaceClass != LIBUSB::CLASS_HID
      yield intf
    end
  end
end
