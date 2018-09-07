require "primitives"
require "./internal/external_types"

class String
  def bytesize
    @bytesize
  end

  def to_unsafe : UInt8*
    pointerof(@c)
  end
end

lib Elf
  union ValueOrPointer
    value : UInt64
    pointer : Void*
  end

  struct Dyn
    tag : Int64
    un : ValueOrPointer # useless but well
  end

  struct Rel
    offset : UInt64
    reloc_type, symbol : UInt32
  end

  struct RelA
    offset : UInt64
    reloc_type, symbol : UInt32
    addend : UInt64
  end
end

alias Handle = UInt32
alias Result = UInt32

struct SizedStaticArray(T, N)
  @buffer : StaticArray(T, N)
  @size = 0u64

  def initialize
    @buffer = uninitialized StaticArray(T, N)
  end

  @[AlwaysInline]
  def [](index : Int)
    @buffer[index]
  end

  @[AlwaysInline]
  def []=(index : Int, value : T)
    @buffer[index] = value
  end

  def update(index : Int)
    @buffer.update(index)
  end

  def size
    @size
  end

  def push(value : T)
    # FIXME: SIZE CHECK
    @buffer[@size] = value
    @size += 1
    self
  end

  def []=(value : T)
    @buffer[] = value
  end
end
