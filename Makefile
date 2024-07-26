THEOS_DEVICE_IP = 192.168.1.19
GO_EASY_ON_ME = 1
include $(THEOS)/makefiles/common.mk
ARCHS = armv7

TWEAK_NAME = Panel
Panel_FILES = Tweak.xm UIImage+LiveBlur.m UIImage+StackBlur.m UIImage+Resize.m NSData+Base64.m
Panel_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics Security

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += panel
include $(THEOS_MAKE_PATH)/aggregate.mk
