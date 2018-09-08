module IPC
  abstract struct Command
    # Request magic.
    SFCI_MAGIC = 0x49434653_u64
    # Response magic.
    SFCO_MAGIC = 0x4f434653_u64
    @magic : UInt64 = SFCI_MAGIC
    @id : UInt64 = 0xDEAD

    # Return the actual magic.
    def magic
      @magic
    end

    # Checks if the magic is equal to `SFCI_MAGIC`.
    def is_request?
      @magic == SFCI_MAGIC
    end

    # Checks if the magic is equal to `SFCO_MAGIC`.
    def is_response?
      @magic == SFCO_MAGIC
    end
  end

  struct SimpleRawResponse < Command
    def response_code
      @id
    end
  end
end
