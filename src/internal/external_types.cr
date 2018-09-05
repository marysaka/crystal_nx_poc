# TODO: get ride of everything here later on

class Object
  def ===(other)
    self == other
  end
end

struct Pointer(T)
  def [](offset)
    (self + offset).value
  end

  def []=(offset, value : T)
    (self + offset).value = value
  end

  def +(other : Int)
    self + other.to_i64
  end

  def +(other : Nil)
    self
  end
end

struct Int8
  MIN = -128_i8
  MAX =  127_i8
end

struct Int16
  MIN = -32768_i16
  MAX =  32767_i16
end

struct Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32
end

struct Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64
end

struct UInt8
  MIN =   0_u8
  MAX = 255_u8

  def abs
    self
  end
end

struct UInt16
  MIN =     0_u16
  MAX = 65535_u16

  def abs
    self
  end
end

struct UInt32
  MIN =          0_u32
  MAX = 4294967295_u32

  def abs
    self
  end
end

struct UInt64
  MIN =                    0_u64
  MAX = 18446744073709551615_u64

  def abs
    self
  end
end

struct Int
  private DIGITS_DOWNCASE = "0123456789abcdefghijklmnopqrstuvwxyz"
  private DIGITS_UPCASE   = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  private DIGITS_BASE62   = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def times(&block : self ->) : Nil
    i = self ^ self
    while i < self
      yield i
      i += 1
    end
  end

  def abs
    self >= 0 ? self : 0 - self
  end

  def remainder(other : Int)
    if other == 0
      SVC.return_from_exception(0xDABE_u64)
    else
      unsafe_mod other
    end
  end

  private def check_div_argument(other)
    if other == 0
      SVC.return_from_exception(0xDABE_u64)
    end

    {% begin %}
        if self < 0 && self == {{@type}}::MIN && other == -1
          SVC.output_debug_string("Overflow")
          SVC.return_from_exception(0xDABE_u64)
        end
      {% end %}
  end

  def tdiv(other : Int)
    check_div_argument other

    unsafe_div other
  end

  def internal_to_s(base, upcase = false)
    # Given sizeof(self) <= 128 bits, we need at most 128 bytes for a base 2
    # representation, plus one byte for the trailing 0.
    chars = uninitialized UInt8[129]
    ptr_end = chars.to_unsafe + 128
    ptr = ptr_end
    num = self

    neg = num < 0

    digits = (base == 62 ? DIGITS_BASE62 : (upcase ? DIGITS_UPCASE : DIGITS_DOWNCASE)).to_unsafe

    while num != 0
      ptr += -1
      ptr.value = digits[num.remainder(base).abs]
      num = num.tdiv(base)
    end

    if neg
      ptr += -1
      ptr.value = '-'.ord.to_u8
    end

    count = (ptr_end - ptr).to_i32
    yield ptr, count
  end
end

struct StaticArray(T, N)
  def to_unsafe : Pointer(T)
    pointerof(@buffer)
  end
end
