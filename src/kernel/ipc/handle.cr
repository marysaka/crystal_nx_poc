module IPC
  # Represent the packed form of `::Handle` in the [handle descriptor](http://switchbrew.org/index.php?title=IPC_Marshalling#Handle_descriptor).
  struct Handle
    enum Type
      Move,
      Copy
    end

    def initialize(@handle : ::Handle, @type : IPC::Handle::Type)
    end

    def value : ::Handle
      @handle
    end

    def type
      @type
    end
  end
end
