# inspired by libtransistor-base makefile

# llvm programs

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

NAME = testing

LD := $(LLVM_BINDIR)/ld.lld
CC := $(LLVM_BINDIR)/clang
CXX := $(LLVM_BINDIR)/clang++
AS := $(LLVM_BINDIR)/llvm-mc
AR := $(LLVM_BINDIR)/llvm-ar
RANLIB := $(LLVM_BINDIR)/llvm-ranlib
LINK_SCRIPT = link.T

LD_FLAGS := --verbose \
	--gc-sections \
	--eh-frame-hdr \
	-T link.T

CC_FLAGS := -v -g -fPIC -fexceptions -fuse-ld=lld -fstack-protector-strong -mtune=cortex-a53 -target aarch64-none-linux-gnu -nostdlib -nostdlibinc $(SYS_INCLUDES) -D__SWITCH__=1 -Wno-unused-command-line-argument
CXX_FLAGS := $(CPP_INCLUDES) $(CC_FLAGS) -std=c++17 -stdlib=libc++ -nodefaultlibs -nostdinc++
AR_FLAGS := rcs
AS_FLAGS := -g -fPIC -arch=aarch64 -triple aarch64-none-linux-gnu

# for compatiblity
CFLAGS := $(CC_FLAGS)
CXXFLAGS := $(CXX_FLAGS)

CR_SRCS = src/*.cr src/**/*.cr
OBJECTS = src/crt0/crt0.o main.o

all: $(NAME).nso $(NAME).nro

main.o: $(CR_SRCS)
	crystal build src/main.cr --cross-compile --prelude=empty --target="aarch64-unknown-linux-gnu" --emit llvm-ir

$(NAME).elf: $(OBJECTS)
	mkdir -p $(@D)
	rm -f $@
	$(LD) $(LD_FLAGS) -o $@ $+

src/crt0/crt0.o: src/crt0/crt0.S
	$(CC) $(CC_FLAGS) -c -o $@ $< $(LINK_SCRIPT)

%.nso: %.elf
	linkle nso $< $@

%.nro: %.elf
	linkle nro $< $@

clean:
	rm -rf $(OBJECTS) main.ll $(NAME).elf $(NAME).nso $(NAME).nro

re: clean all
