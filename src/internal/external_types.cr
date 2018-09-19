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

  def self.new(value)
    value.to_i8
  end
end

struct Int16
  MIN = -32768_i16
  MAX =  32767_i16

  def self.new(value)
    value.to_i16
  end
end

struct Int32
  MIN = -2147483648_i32
  MAX =  2147483647_i32

  def self.new(value)
    value.to_i32
  end
end

struct Int64
  MIN = -9223372036854775808_i64
  MAX =  9223372036854775807_i64

  def self.new(value)
    value.to_i64
  end
end

struct UInt8
  MIN =   0_u8
  MAX = 255_u8

  def abs
    self
  end

  def self.new(value)
    value.to_u8
  end
end

struct UInt16
  MIN =     0_u16
  MAX = 65535_u16

  def abs
    self
  end

  def self.new(value)
    value.to_u16
  end
end

struct UInt32
  MIN =          0_u32
  MAX = 4294967295_u32

  def abs
    self
  end

  def self.new(value)
    value.to_u32
  end
end

struct UInt64
  MIN =                    0_u64
  MAX = 18446744073709551615_u64

  def abs
    self
  end

  def self.new(value)
    value.to_u64
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

  def self.zero : self
    new(0)
  end

  def abs
    self >= 0 ? self : 0 - self
  end

  def >>(count : Int)
    if count < 0
      self << count.abs
    elsif count < sizeof(self) * 8
      self.unsafe_shr(count)
    else
      self.class.zero
    end
  end

  def <<(count : Int)
    if count < 0
      self >> count.abs
    elsif count < sizeof(self) * 8
      self.unsafe_shl(count)
    else
      self.class.zero
    end
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

  def /(other : Int)
    check_div_argument other

    div = unsafe_div other
    mod = unsafe_mod other
    div -= 1 if other > 0 ? mod < 0 : mod > 0
    div
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

  def ~
    self ^ -1
  end
end

struct StaticArray(T, N)
  private def check_index_out_of_bounds(index)
    check_index_out_of_bounds(index) {
      SVC.return_from_exception(0xDEED_u64)
    }
  end

  private def check_index_out_of_bounds(index)
    index += size if index < 0
    if 0 <= index < size
      index
    else
      yield
    end
  end

  @[AlwaysInline]
  def [](index : Int)
    index = check_index_out_of_bounds index
    to_unsafe[index]
  end

  @[AlwaysInline]
  def []=(index : Int, value : T)
    index = check_index_out_of_bounds index
    to_unsafe[index] = value
  end

  def update(index : Int)
    index = check_index_out_of_bounds index
    to_unsafe[index] = yield to_unsafe[index]
  end

  def size
    N
  end

  def []=(value : T)
    size.times do |i|
      to_unsafe[i] = value
    end
  end

  def to_unsafe : Pointer(T)
    pointerof(@buffer)
  end
end

struct Enum
  def ==(other)
    false
  end

  def ==(other : self)
    value == other.value
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


struct Proc
  def pointer
    internal_representation[0]
  end

  def closure_data
    internal_representation[1]
  end

  private def internal_representation
    func = self
    ptr = pointerof(func).as({Void*, Void*}*)
    ptr.value
  end
end