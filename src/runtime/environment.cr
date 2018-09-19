struct LoaderConfigEntry
  @key : LoaderConfigKey = LoaderConfigKey::EndOfList
  @flags : UInt32 = 0
  @value1 : UInt64 = 0
  @value2 : UInt64 = 0

  def key
    @key
  end

  def flags
    @flags
  end

  def value1
    @value1
  end

  def value2
    @value2
  end
end

enum LoaderConfigKey : UInt32
  EndOfList,
  MainThreadHandle,
  NextLoadPath,
  OverrideHeap,
  OverrideService,
  Argv,
  SyscallAvailableHint,
  AppletType,
  AppletWorkaround,
  Reserved9,
  ProcessHandle,
  LastLoadResult,
  AllocPages,
  LockRegion,
end

enum LoaderConfigAppletType : UInt32
  Application,
  SystemApplet,
  LibraryApplet,
  OverlayApplet,
  SystemApplication
end

# [HB ABI](https://switchbrew.org/index.php?title=Homebrew_ABI) compliancy module
module Environment
  @@loader_configuration = Pointer(LoaderConfigEntry).new(0)
  @@main_thread_handle : Handle = 0
  @@no_hb_abi = false

  # NextLoadPath
  @@next_load_path : UInt8* = Pointer(UInt8).new(0)
  @@app_path : UInt8* = Pointer(UInt8).new(0)

  # OverrideHeap
  @@override_heap = false
  @@heap_start = Pointer(Void).new(0)
  @@heap_size = 0u64

  # Argv
  @@argv : UInt8* = Pointer(UInt8).new(0)

  # AppletType
  @@applet_type : LoaderConfigAppletType = LoaderConfigAppletType::Application

  # AppletWorkaround
  @@applet_workaround = false
  @@applet_resource_user_id : UInt32 = 0

  # ProcessHandle
  @@process_handle : Handle = 0

  # LastLoadResult
  @@last_load_result : Int32 = 0

  def self.hb_loader?
    @@no_hb_abi == false
  end

  def self.override_heap?
    @@override_heap
  end

  def self.heap_start
    @@heap_start
  end

  def self.heap_size
    @@heap_size
  end

  def self.init(loader_configuration, main_thread_handle) : UInt64
    @@loader_configuration = loader_configuration
    if loader_configuration.address == 0
      @@no_hb_abi = true
      @@main_thread_handle = main_thread_handle
      return 0u64
    end

    until loader_configuration.value.key == LoaderConfigKey::EndOfList
      config_entry = loader_configuration.value
      case loader_configuration.value.key
      when LoaderConfigKey::MainThreadHandle
        @@main_thread_handle = config_entry.value1.to_u32
      when LoaderConfigKey::NextLoadPath
        @@next_load_path = Pointer(UInt8).new(config_entry.value1)
        @@app_path = Pointer(UInt8).new(config_entry.value2)
      when LoaderConfigKey::OverrideHeap
        @@override_heap = true
        @@heap_start = Pointer(Void).new(config_entry.value1)
        @@heap_size = config_entry.value2
      when LoaderConfigKey::Argv
        @@argv = Pointer(UInt8).new(config_entry.value2)
      when LoaderConfigKey::AppletType
        @@applet_type = LoaderConfigAppletType.new(config_entry.value1.to_u32)
      when LoaderConfigKey::AppletWorkaround
        @@applet_workaround = true
        @@applet_resource_user_id = config_entry.value1.to_u32
      when LoaderConfigKey::ProcessHandle
        @@process_handle = config_entry.value1.to_u32
      when LoaderConfigKey::LastLoadResult
        @@last_load_result = config_entry.value1.to_i32
      when LoaderConfigKey::OverrideService
      when LoaderConfigKey::SyscallAvailableHint
      when LoaderConfigKey::Reserved9
      when LoaderConfigKey::AllocPages
        # config key ignored
      else
        # unknown config key, returns the same error as the ABI wants.
        return 346u64 | ((100 + loader_configuration.value.key.value) << 9)
      end
      loader_configuration += 1
    end
    0u64
  end
end
