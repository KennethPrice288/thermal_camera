# Written by dustin richmond at UCSC for CSE x25
REPO_ROOT ?= $(shell git rev-parse --show-toplevel)

PCF_PATH=$(REPO_ROOT)/hdl_source/thermal_camera_vga/icebreaker.pcf

$(info REPO_ROOT = $(REPO_ROOT))
$(info Including $(REPO_ROOT)/hdlsource/frag/simulate.mk)
-include $(REPO_ROOT)/hdl_source/frag/simulate.mk
$(info Including $(REPO_ROOT)/hdlsource/frag/synth.mk)
-include $(REPO_ROOT)/hdl_source/frag/synth.mk
$(info Including $(REPO_ROOT)/hdlsource/frag/fpga.mk)
-include $(REPO_ROOT)/hdl_source/frag/fpga.mk
