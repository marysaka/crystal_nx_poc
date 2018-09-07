fun get_tls : Void*
  addr = 0_u64
  asm("mrs $0, tpidrro_el0" : "=r"(addr))
  Pointer(Void).new(addr)
end
