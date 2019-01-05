# :nodoc:
# TODO: setup TLS
struct ThreadLocalStorage
  @ipc: StaticArray(UInt8, 0x100)
  @unknown: StaticArray(UInt8, 0xF8)
  @thread_context: Void*

  def initialize
    @ipc = uninitialized StaticArray(UInt8, 0x100)
    @unknown = uninitialized StaticArray(UInt8, 0xF8)
    @thread_context = uninitialized Void*
  end

  def ipc : UInt8*
    @ipc.to_unsafe()
  end

  def thread_context : Void*
    @thread_context
  end

  def self.get : ThreadLocalStorage*
    addr = 0_u64
    asm("mrs $0, tpidrro_el0" : "=r"(addr))
    Pointer(ThreadLocalStorage).new(addr)
  end
end
