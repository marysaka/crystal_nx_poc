.SUFFIXES: # disable built-in rules
.SECONDARY: # don't delete intermediate files

# inspired by libtransistor-base makefile

# start llvm programs

# On MacOS, brew refuses to install clang5/llvm5 in a global place. As a result,
# they have to muck around with changing the path, which sucks.
# Let's make their lives easier by asking brew where LLVM_CONFIG is.
ifeq ($(shell uname -s),Darwin)
    ifeq ($(shell brew --prefix llvm),)
        $(error need llvm installed via brew)
    else
        LLVM_CONFIG := $(shell brew --prefix llvm)/bin/llvm-config
    endif
else
    LLVM_CONFIG := llvm-config$(LLVM_POSTFIX)
endif

LLVM_BINDIR := $(shell $(LLVM_CONFIG) --bindir)
ifeq ($(LLVM_BINDIR),)
  $(error llvm-config needs to be installed)
endif

LD := $(LLVM_BINDIR)/ld.lld
CC := $(LLVM_BINDIR)/clang
CXX := $(LLVM_BINDIR)/clang++
AS := $(LLVM_BINDIR)/llvm-mc
AR := $(LLVM_BINDIR)/llvm-ar
RANLIB := $(LLVM_BINDIR)/llvm-ranlib
# end llvm programs

SOURCE_ROOT = .
SRC_DIR = $(SOURCE_ROOT)/src
BUILD_DIR := $(SOURCE_ROOT)/build
LIB_DIR = $(BUILD_DIR)/lib/
TARGET_TRIPLET = aarch64-none-switch
LINK_SCRIPT = link.T

# For compiler-rt, we need some system header
SYS_INCLUDES := -isystem $(realpath $(SOURCE_ROOT))/include/
CC_FLAGS := -g -fPIC -fexceptions -fuse-ld=lld -fstack-protector-strong -mtune=cortex-a53 -nostdlib -nostdlibinc $(SYS_INCLUDES) -Wno-unused-command-line-argument -D__SWITCH__=1
CXX_FLAGS := $(CC_FLAGS) -std=c++17 -stdlib=libc++ -nodefaultlibs -nostdinc++
AR_FLAGS := rcs
AS_FLAGS := -g -fPIC -arch=aarch64 -triple $(TARGET_TRIPLET)

LD_FLAGS := -Bsymbolic \
	--shared \
	--gc-sections \
	--eh-frame-hdr \
	--no-undefined \
	-T link.T \
	-Bstatic \
	-Bdynamic

# for compatiblity
CFLAGS := $(CC_FLAGS)
CXXFLAGS := $(CXX_FLAGS)

# Crystal
CRYSTAL = crystal
CRFLAGS = --cross-compile --prelude=./runtime/nx_prelude --target="$(TARGET_TRIPLET)" --emit llvm-ir
SOURCES := $(shell find src lib -type f -name '*.cr')

# see https://github.com/MegatonHammer/linkle
LINKLE = linkle

# export
export LD
export CC
export CXX
export AS
export AR
export LD_FOR_TARGET = $(LD)
export CC_FOR_TARGET = $(CC)
export AS_FOR_TARGET = $(AS) -arch=aarch64 -mattr=+neon
export AR_FOR_TARGET = $(AR)
export RANLIB_FOR_TARGET = $(RANLIB)
export CFLAGS_FOR_TARGET = $(CC_FLAGS) -Wno-unused-command-line-argument -Wno-error-implicit-function-declaration

NAME = crystal_nx_poc
all: $(BUILD_DIR)/$(NAME).nso $(BUILD_DIR)/$(NAME).nro docs

# start compiler-rt definitions
LIB_COMPILER_RT_BUILTINS := $(BUILD_DIR)/compiler-rt/lib/libclang_rt.builtins-aarch64.a
include mk/compiler-rt.mk
# end compiler-rt definitions

OBJECTS = $(LIB_COMPILER_RT_BUILTINS) $(BUILD_DIR)/$(NAME).o $(BUILD_DIR)/runtime/crt0.o

$(BUILD_DIR)/$(NAME).o: lib $(SOURCES)
	mkdir -p $(@D)
	rm -f $@
	$(CRYSTAL) build src/main.cr -o $(BUILD_DIR)/$(NAME) $(CRFLAGS)

$(BUILD_DIR)/$(NAME).elf: $(OBJECTS)
	$(LD) $(LD_FLAGS) -o $@ $+

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	mkdir -p $(@D)
	rm -f $@
	$(CC) $(CC_FLAGS) -target $(TARGET_TRIPLET) -c -o $@ $< $(LINK_SCRIPT)

%.nso: %.elf
	$(LINKLE) nso $< $@

%.nro: %.elf
	$(LINKLE) nro $< $@

clean: clean_compiler-rt
	rm -rf $(OBJECTS) main.ll $(BUILD_DIR)/$(NAME).elf $(BUILD_DIR)/$(NAME).nso $(BUILD_DIR)/$(NAME).nro docs

docs: $(SOURCES)
	$(CRYSTAL) docs src/main_docs.cr


lib: shard.yml shard.lock
	shards install

.PHONY: lib