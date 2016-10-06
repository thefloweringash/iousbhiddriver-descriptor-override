#include <IOKit/IOBufferMemoryDescriptor.h>
#include "IOUSBHIDDriverDescriptorOverride.h"

OSDefineMetaClassAndStructors(IOUSBHIDDriverDescriptorOverride, IOUSBHostHIDDevice)

IOReturn IOUSBHIDDriverDescriptorOverride::newReportDescriptor(IOMemoryDescriptor **desc) const {
	
	OSData *reportDescriptor = OSDynamicCast(OSData, getProperty(REPORT_DESCRIPTOR_OVERRIDE_KEY));
	
	if(reportDescriptor) {		
		IOBufferMemoryDescriptor *bufferDesc = IOBufferMemoryDescriptor::withBytes(reportDescriptor->getBytesNoCopy(),
																				   reportDescriptor->getLength(),
																				   kIODirectionOutIn);
		if(bufferDesc) {
			*desc = bufferDesc;
			return kIOReturnSuccess;
		} else {
			bufferDesc->release();
			*desc = NULL;
			return kIOReturnNoMemory;
		}
	} else {
		//IOLog("IOUSBHIDDriverDescriptorOverride(%s)[%p]::newReportDescriptor - "
		//	  "No %s data in personality, calling IOUSBHIDDriver::newReportDescriptor\n",
		//	  getName(), this, REPORT_DESCRIPTOR_OVERRIDE_KEY);
		return IOUSBHostHIDDevice::newReportDescriptor(desc);
	}
}
