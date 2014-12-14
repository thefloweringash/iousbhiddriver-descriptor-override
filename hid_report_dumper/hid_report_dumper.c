#include <curses.h>

#include <CoreFoundation/CoreFoundation.h>

#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDKeys.h>

struct keyboard_handler {
	uint8_t hid_report_buffer[1024];
	int index;
	int report_count;
};

static void got_hid_report(void *context, IOReturn result, void *sender,
                           IOHIDReportType type, uint32_t reportID, uint8_t *report,
                           CFIndex reportLength)
{
	struct keyboard_handler* handler = (struct keyboard_handler*) context;
	handler->report_count++;
	move(handler->index + 1, 0);
	clrtoeol();

	printw("%i [%.5i] context=%p, reportID=%i reportLength=%li ",
	       handler->index, handler->report_count, context, reportID, reportLength);
	int i = 0;
	for (i = 0; i < reportLength; i++) {
		if (report[i]) {
			attron(COLOR_PAIR(1));
		}
		printw(" %.2x", report[i]);
		if (report[i]) {
			attroff(COLOR_PAIR(1));
		}
	}
	/*
	if (report[0] == 0x1 || report[0] == 0x10) {
		endwin();
		exit(0);
	}
	*/

	refresh();
}

static void match_callback(void *context, IOReturn result,
                           void *sender, IOHIDDeviceRef device)
{
	static int captured_devices = 0;
	static int failed_captures = 0;

	// dump instead of capturing
	if (false)
	{
		{
			CFTypeRef o = IOHIDDeviceGetProperty(
				device, CFSTR(kIOHIDDeviceUsagePairsKey));
			printf("\tkIOHIDDeviceUsagePairsKey = %p\n", o);
			CFShow(o);
		}

		{
			CFTypeRef o = IOHIDDeviceGetProperty(
				device, CFSTR(kIOHIDElementKey));
			printf("\tkIOHIDElementKey = %p\n", o);
			CFShow(o);
		}

		return;
	}

	IOReturn r = IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDevice);
	if (r == kIOReturnSuccess) {
		struct keyboard_handler *handler =
			(struct keyboard_handler*) malloc(sizeof(*handler));
		memset(handler, 0x00, sizeof(*handler));
		handler->index = captured_devices++;
		IOHIDDeviceRegisterInputReportCallback(
			device,
			handler->hid_report_buffer,
			sizeof(handler->hid_report_buffer),
			&got_hid_report,
			(void*) handler);

		move(handler->index + 1, 0);
		printw("%i <no reports yet>", handler->index);

	}
	else {
		failed_captures++;
	}

	move(0, 0);
	clrtoeol();
	printw("Seized %i devices", captured_devices);
	if (failed_captures) {
		printw(" (%i failed)", failed_captures);
	}
	refresh();
}

static void match_set(CFMutableDictionaryRef dict, CFStringRef key, int value) {
	CFNumberRef number = CFNumberCreate(
		kCFAllocatorDefault, kCFNumberIntType, &value);
	CFDictionarySetValue(dict, key, number);
	CFRelease(number);
}

static CFDictionaryRef matching_dictionary_create(int vendorID,
                                                  int productID,
                                                  int usagePage,
                                                  int usage)
{
	CFMutableDictionaryRef match = CFDictionaryCreateMutable(
		kCFAllocatorDefault, 0,
		&kCFTypeDictionaryKeyCallBacks,
		&kCFTypeDictionaryValueCallBacks);

	if (vendorID) {
		match_set(match, CFSTR(kIOHIDVendorIDKey), vendorID);
	}
	if (productID) {
		match_set(match, CFSTR(kIOHIDProductIDKey), productID);
	}
	if (usagePage) {
		match_set(match, CFSTR(kIOHIDDeviceUsagePageKey), usagePage);
	}
	if (usage) {
		match_set(match, CFSTR(kIOHIDDeviceUsageKey), usage);
	}

	return match;
}

int main() {
	initscr();
	start_color();
	use_default_colors();
	init_pair(1, COLOR_RED, -1);

	IOHIDManagerRef hidManager = IOHIDManagerCreate(
		kCFAllocatorDefault, kIOHIDOptionsTypeNone);

	IOHIDManagerRegisterDeviceMatchingCallback(
		hidManager, match_callback, NULL);

	IOHIDManagerScheduleWithRunLoop(
		hidManager, CFRunLoopGetMain(), kCFRunLoopCommonModes);

	// all keyboards
	CFDictionaryRef match = matching_dictionary_create(0, 0, 1, 6);

	// kinesis
	/* CFDictionaryRef match = matching_dictionary_create(0x05f3, 0x0007, 0, 0); */

	// noppoo
	/* CFDictionaryRef match = matching_dictionary_create(0x1006, 0x0022, 1, 6); */

	// a4tech
	/* CFDictionaryRef match = matching_dictionary_create(0x1241, 0x1603, 0, 0); */


	IOHIDManagerSetDeviceMatching(hidManager, match);
	CFRelease(match);

	CFRunLoopRun();
}
