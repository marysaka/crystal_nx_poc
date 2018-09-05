require "primitives"
require "./types"

# TODO: remove this
fun svcFakePrintNumber(error_code : UInt64)
  asm("svc 0x79" :: "x0"(error_code))
end

lib LibCrystalMain
  @[Raises]
  fun __crystal_main(argc : Int32, argv : UInt8**)
end

def clean_bss(start_bss, end_bss)
  until start_bss.address == end_bss.address
    start_bss.value = 0
    start_bss += 1
  end
end

# TODO: support all sort of relocation
def relocate(base, dynamic_section) : UInt64
  rela_offset = 0_u64
  rela_size = 0_u64
  rela_ent = 0_u64
  rela_count = 0_u64
  until dynamic_section.value.tag == 0_u64
    case dynamic_section.value.tag
    when 0x7_u64 # DT_RELA
      rela_offset = dynamic_section.value.un.value
    when 0x8_u64 # DT_RELASZ
      rela_size = dynamic_section.value.un.value
    when 0x9_u64 # DT_RELAENT
      rela_ent = dynamic_section.value.un.value
    when 0x6ffffff9_u64 # DT_RELACOUNT
      rela_count = dynamic_section.value.un.value
    end
    dynamic_section += 1
  end

  if rela_ent != 0x18 || rela_size != rela_ent * rela_count
    return 0xBEEF_u64
  end

  rela = Pointer(Elf::RelA).new(base + rela_offset)

  i = 0_i64
  while (i != rela_count)
    rela += i
    case rela.value.reloc_type
    when 0x403_u32 # R_AARCH64_RELATIVE
      # TODO: supports symbol
      if rela.value.symbol != 0
        return 0x4243_u64
      end
      Pointer(UInt64).new(base + rela.value.offset).value = base + rela.value.addend
    else
      svcFakePrintNumber(rela.value.reloc_type.to_u64)
      return 0x4242_u64
    end
    i += 1
  end
  0_u64
end

def nx_init(loader_config, main_thread_handle, base, dynamic_section) : UInt64
  res = relocate(base, dynamic_section)
  if res != 0
    return res
  end
  # TODO: memory allocation, kernel version detection, HBABI and argument parsing
  0_u64
end

fun __crystal_nx_entrypoint(loader_config : Void*, main_thread_handle : Handle, base : UInt64, dynamic_section : Elf::Dyn*, bss_start : UInt64*, bss_end : UInt64*) : UInt64
  clean_bss(bss_start, bss_end)
  res = nx_init(loader_config, main_thread_handle, base, dynamic_section)
  if res != 0
    return res
  end
  LibCrystalMain.__crystal_main(0, nil)
  0_u64
end