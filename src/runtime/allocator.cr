require "cryloc"

module Cryloc::HeapManager
  @@init = false
  @@heap_start = Pointer(Void).new(0)
  @@heap_current_pos = Pointer(Void).new(0)
  @@heap_end = Pointer(Void).new(0)

  # Permite to override default NSO/KIP behaviour when allocating memory
  def self.heap_size
    0u64
  end

  def self.init : Result
    if Environment.hb_loader? && Environment.override_heap?
      @@heap_start = Environment.heap_start
      @@heap_end = Pointer(Void).new(@@heap_start.address + Environment.heap_size)
      @@init = true
      0u32
    else
      size = heap_size
      if size == 0
        # use all memory that we can.
        memory_availaible = uninitialized UInt64
        memory_usage = uninitialized UInt64
        SVC.get_info(pointerof(memory_availaible), 6u64, Handle::CURRENT_PROCESS, 0u64)
        SVC.get_info(pointerof(memory_usage), 7u64, Handle::CURRENT_PROCESS, 0u64)
        if memory_availaible > memory_usage + 0x2000000
          size = (memory_availaible - memory_usage - 0x200000) & ~0x1FFFFF
        else
          size = 0x2000000u64 * 16
        end
      end

      out = uninitialized Void*
      res = SVC.set_heap_size(pointerof(out), size)
      if res != 0
        return res
      end

      @@heap_start = out
      @@heap_end = Pointer(Void).new(@@heap_start.address + size)
      @@init = true
      0u32
    end
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
