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

TARGET_TRIPLET = aarch64-none-switch
LINK_SCRIPT = link.T

CC_FLAGS := -g -fPIC -fexceptions -fuse-ld=lld -fstack-protector-strong -mtune=cortex-a53 -target $(TARGET_TRIPLET) -nostdlib -nostdlibinc -Wno-unused-command-line-argument
CXX_FLAGS := $(CPP_INCLUDES) $(CC_FLAGS) -std=c++17 -stdlib=libc++ -nodefaultlibs -nostdinc++
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
CRFLAGS = --cross-compile --prelude=./nx_prelude --target="$(TARGET_TRIPLET)" --emit llvm-ir
SOURCES = src/*.cr src/**/*.cr

# see https://github.com/MegatonHammer/linkle
LINKLE = linkle

NAME = crystal_nx_poc

OBJECTS = $(NAME).o src/crt0/crt0.o

all: $(NAME).nso $(NAME).nro

$(NAME).o: $(SOURCES)
	$(CRYSTAL) build src/main.cr -o $(NAME) $(CRFLAGS)

$(NAME).elf: $(OBJECTS)
	$(LD) $(LD_FLAGS) -o $@ $+

src/crt0/crt0.o: src/crt0/crt0.S
	$(CC) $(CC_FLAGS) -c -o $@ $< $(LINK_SCRIPT)

%.nso: %.elf
	$(LINKLE) nso $< $@

%.nro: %.elf
	$(LINKLE) nro $< $@

clean:
	rm -rf $(OBJECTS) main.ll $(NAME).elf $(NAME).nso $(NAME).nro

re: clean all
