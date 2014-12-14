# hid\_report\_dumper

Simple ncurses based utility to capture HID devices using IOKit and
display the raw input.

**This utility takes exclusive control of all keyboards. While it is
  running you will not be able to Ctrl-C it. Open Activity Monitor
  before running this device.**

## Usage

Build with

    make

Run as `root`

    sudo ./hid_report_dumper


## Customisation

By default all keyboards are captured. The body of `main` can be
customised to match a particular device by changing the arguments of
`matching_dictionary_create`.
