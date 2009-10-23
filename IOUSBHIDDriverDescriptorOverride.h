#include <IOKit/usb/IOUSBHIDDriver.h>

#define REPORT_DESCRIPTOR_OVERRIDE_KEY "ReportDescriptorOverride"

class IOUSBHIDDriverDescriptorOverride : public IOUSBHIDDriver {
	
	OSDeclareDefaultStructors(IOUSBHIDDriverDescriptorOverride)
	
public:
    virtual IOReturn newReportDescriptor(IOMemoryDescriptor **descriptor) const;
	
};

