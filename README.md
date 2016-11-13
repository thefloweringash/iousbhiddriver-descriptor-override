<!--- -*- mode: markdown; mode: flyspell -*- -->
<!--- LocalWords: Noppoo IOUSBHIDDriverDescriptorOverride -->

IOUSBHIDDriverDescriptorOverride
================================

[![Build Status](https://travis-ci.org/thefloweringash/iousbhiddriver-descriptor-override.svg?branch=master)](https://travis-ci.org/thefloweringash/iousbhiddriver-descriptor-override)

This OS X kernel extension provides a method for overriding a HID
descriptor and ignoring the descriptor provided by the device. This is
useful when the HID descriptor returned by a HID device is invalid or
incorrect.

Supported Devices
-----------------

 * Noppoo Choc Mini (1006:0022, 1007:8400)
 * Noppoo Choc Mid (04d9:1829)
 * Noppoo Choc Pro (04f3:5a5a, 06fe:104e)
 * Tt eSPORTS Poseidon Z (0566:3067)
 * Tt eSPORTS Poseidon ZX (0566:3063)
 * Ozone StrikeBattle (04d9:a096)
 * Patech JP-PC35B (04d9:a0cd) (untested)

Including the support from the [original project](#acknowledgements)
for

 * Griffin PowerMate
 * Macally iShock

Noppoo
------

There are two problems when using a Noppoo keyboard on OS X

 * duplicate keypresses
 * modifier keys only working with some keys

The descriptors have an overlap by specifying both an immediate list
of usages, and a range of usages. This causes OS X to send _both_
usages when a key in the overlapping range is pressed. The solution
used here is to split the item into two separate items: one for the
immediate list and the other for the range. For the specifics of the
descriptors and the changes to make them work, see the
[unencoded versions][descriptor-source].

OS X has modifier state local to each keyboard; The Noppoo implements
NKRO with two keyboard interfaces but only of which has the modifier
state. This makes it impossible to use modifiers with any key on the
non-modifier keyboard.

This project only fixes the problems caused by the descriptor. However
installing [KeyRemap4MacBook][] has the side effect of making modifier
state global.

The combination of this extension and KeyRemap4MacBook should make the
Noppoo keyboards behave as expected.

[descriptor-source]: https://gist.github.com/1442127
[keyremap4macbook]: http://pqrs.org/macosx/keyremap4macbook/

Installation
------------

The [Downloads][] section contains installer packages.

To build and install from source

	# dependencies
	gem install bundler
	bundle install --without scan
	
	# build
	xcodebuild
	sudo cp -r build/Release/IOUSBHIDDriverDescriptorOverride.kext \
	    /Library/Extensions
	sudo kextutil \
	    /Library/Extensions/IOUSBHIDDriverDescriptorOverride.kext

[downloads]: https://thefloweringash.com/iousbhiddriver-descriptor-override/downloads/

Unsupported Devices
-------------------

The Noppoo devices have a range of identifiers and descriptors. If a
device is not supported, there is an experimental feature that will
generate the Info.plist section for any connected device that has the
Noppoo-style overlapping descriptors.

	# dependencies
	brew install libusb
	bundle install --without ""
	
	# build
	rake scan

A file for your keyboard will be generated in the `descriptors`
directory. Follow the instructions in the previous section to install
the resulting module.

This feature is experimental, but works for limited test cases. If the
resulting .kext works with your keyboard, submit a pull request with
the new descriptors, otherwise open an issue with the new descriptors.

Troubleshooting
---------------

### Ensure the kext is loaded

Use [kextstat][] to list currently loaded modules. The module named
`IOUSBHIDDriverDescriptorOverride` must be present.

	$ kextstat | grep IOUSBHIDDriverDescriptorOverride
	   59    0 0xffffff7f80bc6000 0x2000     0x2000
	   ryangoulden.driver.IOUSBHIDDriverDescriptorOverride (1) <58 25 4 3>

If the driver is not loaded, use [kextutil][] on the kext.

	$ sudo kextutil -v /Library/Extensions/IOUSBHIDDriverDescriptorOverride.kext

### Ensure the kext is being used

Use [ioreg][] to list system resources. For the Noppoo keyboards,
there should be two instances of `IOUSBHIDDriverDescriptorOverride`.

	$ ioreg -b -f | grep IOUSBHIDDriverDescriptorOverride
	    | |   |   | | +-o IOUSBHIDDriverDescriptorOverride  <class IOUSBHIDDriverDescriptorOverride, id 0x100000273, registered, matched, active, busy 0 (125 ms), retain 10>
	    | |   |   | | +-o IOUSBHIDDriverDescriptorOverride  <class IOUSBHIDDriverDescriptorOverride, id 0x10000027b, registered, matched, active, busy 0 (101 ms), retain 10>

If the driver is not being used, make sure your device was inserted
after the driver was loaded. The kext should be loaded early during
boot, so rebooting should be sufficient for the driver to be selected
for the device. Otherwise, check if your device is supported.

For a list of supported devices examine `Info.plist`

	$ plutil -p /Library/Extensions/IOUSBHIDDriverDescriptorOverride.kext/Contents/Info.plist
	...
	    "Noppoo Choc Mini (primary)" => {
	      "bInterfaceNumber" => 0
	      "CFBundleIdentifier" => "ryangoulden.driver.IOUSBHIDDriverDescriptorOverride"
	      "IOProviderClass" => "IOUSBInterface"
	      "HIDDefaultBehavior" => ""
	      "IOClass" => "IOUSBHIDDriverDescriptorOverride"
	      "ReportDescriptorOverride" => <05010906 a1010508 19012903 15002501 75019503 91029505 91010507 19e029e7 95088102 19042928 95258102 094f0950 092b092c 09510952 09539507 81021959 2964950c 8102c0>
	      "bConfigurationValue" => 1
	      "idProduct" => 34
	      "bcdDevice" => 320
	      "idVendor" => 4102
	    }
	...

To see the properties attached USB devices, use [ioreg][]

	$ ioreg -p IOUSB -c IOUSBDevice | grep -e class -e idVendor -e idProduct -e bcdDevice
	...
	      +-o USB Keyboard @1d120000  <class IOUSBDevice, id 0x10000026d, registered, matched, active, busy 0 (312 ms), retain 16>
	      |     "idProduct" = 34
	      |     "bcdDevice" = 320
	      |     "idVendor" = 4102
	...

Devices not in the `Info.plist` are not supported by this project. If
you think a device can be fixed by overriding the HID descriptor,
please open a ticket with information about the device.

### Other

If the driver is loaded and being used for your device, but the device
is not behaving correctly, please open a ticket.

[kextstat]:
    http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man8/kextstat.8.html
[kextutil]:
    http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man8/kextutil.8.html
[ioreg]:
    http://developer.apple.com/library/mac/#documentation/Darwin/Reference/ManPages/man8/ioreg.8.html


<a name="acknowledgements"></a> Acknowledgements
------------------------------------------------

This project is a fork of the
[Google Code project of the same name][google-code-project], and has
been extended to handle issues with the Noppoo Choc Mini and Noppoo
Choc Pro.

[google-code-project]:
    http://code.google.com/p/iousbhiddriver-descriptor-override/
