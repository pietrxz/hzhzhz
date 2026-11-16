ARCHS = arm64
TARGET = iphone:clang:16.5:14.0

TWEAK_NAME = cops_skin
cops_skin_FILES = tweak.mm
cops_skin_CXXFLAGS = -std=c++17 -O2 -Wno-unused-variable -Wno-unused-function -Wno-error
cops_skin_FRAMEWORKS = Foundation UIKit
cops_skin_LIBRARIES = substrate

BUNDLE_FILTER = com.criticalforceentertainment.criticalops

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk
