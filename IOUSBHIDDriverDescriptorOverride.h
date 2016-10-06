#include <IOKit/usb/IOUSBHostHIDDevice.h>

#define REPORT_DESCRIPTOR_OVERRIDE_KEY "ReportDescriptorOverride"

class IOUSBHIDDriverDescriptorOverride : public IOUSBHostHIDDevice {
	
	OSDeclareDefaultStructors(IOUSBHIDDriverDescriptorOverride)
	
public:
    virtual IOReturn newReportDescriptor(IOMemoryDescriptor **descriptor) const;
	
};

