require "primitives"

class Object
    def ===(other)
        self == other
    end
end

class String
    def bytesize
        @bytesize
    end
    def to_unsafe : UInt8*
        pointerof(@c)
    end
end

# TODO: remove this
fun svcFakePrintNumber(error_code : UInt64)
    asm("svc 0x79" : : "x0"(error_code));
end

lib Elf
    
    union ValueOrPointer
        value: UInt64
        pointer: Void*
    end

    struct Dyn
        tag: Int64
        un: ValueOrPointer # useless but well
    end

    struct Rel
        offset: UInt64
        reloc_type, symbol: UInt32    
    end

    struct RelA
        offset: UInt64
        reloc_type, symbol: UInt32
        addend: UInt64
    end
end

alias Handle = UInt32;
alias Result = UInt32;


lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

# TODO: support all sort of relocation
fun relocate(base: UInt64, dynamic_section: Elf::Dyn*): UInt64
    relaOffset = 0_u64
    relaSize = 0_u64
    relaEnt = 0_u64
    relaCount = 0_u64
    until dynamic_section.value.tag == 0_u64
        case dynamic_section.value.tag
        when 0x7_u64 # DT_RELA
            relaOffset = dynamic_section.value.un.value
        when 0x8_u64 # DT_RELASZ
            relaSize = dynamic_section.value.un.value
        when 0x9_u64 # DT_RELAENT
            relaEnt = dynamic_section.value.un.value
        when 0x6ffffff9_u64 # DT_RELACOUNT
            relaCount = dynamic_section.value.un.value
        end
        dynamic_section += 1;

    end
    if relaEnt != 0x18 || relaSize != relaEnt * relaCount
        0xBEEF_u64
    else
        0_u64
    end
    rela = Pointer(Elf::RelA).new(base + relaOffset)
    svcFakePrintNumber(base + relaOffset)

    
    i = 0_i64
    while (i != relaCount)
        rela += i
        case rela.value.reloc_type
        when 0x403_u32 # R_AARCH64_RELATIVE
            if rela.value.symbol != 0
                return 0x4243_u64; # TODO: supports symbol
            end
            Pointer(UInt64).new(base + rela.value.offset).value = base + rela.value.addend
        else
            svcFakePrintNumber(rela.value.reloc_type.to_u64)
            return 0x4242_u64;
        end
        i += 1
    end
    0_u64
end

fun __crystal_nx_init(loader_config: Void*, main_thread_handle: Handle, base: UInt64, dynamic_section: Elf::Dyn*) : UInt64
    res = relocate(base, dynamic_section)
    if res != 0
        return res
    end
    0_u64
end

fun main(argc : Int32, argv : UInt8**) : Int32
  LibCrystalMain.__crystal_main(argc, argv)
  0
end