<!--- -*- mode: markdown; mode: flyspell -*- -->
<!--- LocalWords: Noppoo IOUSBHIDDriverDescriptorOverride -->

IOUSBHIDDriverDescriptorOverride
================================

This OS X kernel extension provides a method for overriding a HID
descriptor and ignoring the descriptor provided by the device. This is
useful when the HID descriptor returned by a HID device is invalid or
incorrect.

Supported Devices
-----------------

 * Noppoo Choc Mini
 * Noppoo Choc Pro

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

	xcodebuild
	sudo cp -r build/Release/IOUSBHIDDriverDescriptorOverride.kext \
	    /System/Library/Extensions
	sudo kextutil \
	    /System/Library/Extensions/IOUSBHIDDriverDescriptorOverride.kext

[downloads]: /thefloweringash/iousbhiddriver-descriptor-override/downloads

<a name="acknowledgements"></a> Acknowledgements
----------------

This project is a fork of the
[Google Code project of the same name][google-code-project], and has
been extended to handle issues with the Noppoo Choc Mini and Noppoo
Choc Pro.

[google-code-project]:
    http://code.google.com/p/iousbhiddriver-descriptor-override/
