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
