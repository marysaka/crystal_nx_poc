require "../kernel/svc"

struct ServiceManager
  def initialize(@session : Handle)
  end

  # :nodoc:
  struct InitRequest < IPC::Command
    @id = 0
    @reserved = 42u64

    def initialize
    end
  end

  def init : Result
    req = IPC::Message.new
    req.send_pid
    req.pack(InitRequest.new)
    SVC.send_sync_request(@session)
  end

  # :nodoc:
  struct GetServiceRequest < IPC::Command
    @id = 1

    def initialize(@service_name : StaticArray(UInt8, 8))
    end
  end

  def get_service(handle : Handle*, service_name : String) : Result
    req = IPC::Message.new
    raw_service_name = StaticArray(UInt8, 8).new
    service_name_size = if service_name.bytesize.to_u64 > 8
                          8u64
                        else
                          service_name.bytesize.to_u64
                        end
    memcpy(raw_service_name.to_unsafe, service_name.to_unsafe, service_name_size)
    req.pack(GetServiceRequest.new(raw_service_name))
    res = SVC.send_sync_request(@session)
    if res == 0u32
      raw_response = req.unpack.as(IPC::SimpleRawResponse*).value
      response_code = raw_response.response_code.to_u32
      if response_code == 0
        handle.value = req.handles[0].value
      end
      response_code
    else
      res
    end
  end

  def self.open : ServiceManager | Result
    session = uninitialized Handle
    res = SVC.connect_to_named_port(pointerof(session), "sm:")
    if res == 0
      sm = ServiceManager.new(session)
      tmp_session = uninitialized Handle
      # [3.0.1+] Checks if we have to init SM
      if (sm.get_service(pointerof(tmp_session), "") == 0x415)
        res = sm.init
        if res == 0
          sm
        else
          res
        end
      else
        sm
      end
    else
      res
    end
  end
end
