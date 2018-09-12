require "cryloc"

module Cryloc::HeapManager
  @@init = false
  @@heap_start = Pointer(Void).new(0)
  @@heap_current_pos = Pointer(Void).new(0)
  @@heap_end = Pointer(Void).new(0)
  def self.init(heap_start : Void*, heap_end : Void*)
    @@heap_start = heap_start
    @@heap_end = heap_end
    @@init = true
  end

  def self.sbrk(increment : SizeT) : Void*
    if @@init == false
      return Pointer(Void).new(Cryloc::SimpleAllocator::SBRK_ERROR_CODE)
    end
    if @@heap_current_pos.address == 0
      @@heap_current_pos = @@heap_start
    end

    if @@heap_current_pos.address + increment > @@heap_end.address
      # OUT OF MEMORY
      return Pointer(Void).new(Cryloc::SimpleAllocator::SBRK_ERROR_CODE)
    end
    ptr = @@heap_current_pos
    @@heap_current_pos = Pointer(Void).new(@@heap_current_pos.address + increment)
    ptr
  end
end

# :nodoc:
def cryloc_sbrk(increment : SizeT) : Void*
  Cryloc::HeapManager.sbrk(increment)
end