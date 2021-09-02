import "package:system_info/system_info.dart";
import 'package:logging/logging.dart';
import "package:collection/collection.dart";
import 'package:universal_io/io.dart' as io;

Logger log = Logger("Hardware");

class Hardware {
  String _os = "";
  String get os => _os;

  List<CPU> cpus = [];

  List<Memory> memories = [];

  Memory recentMemory = Memory(0, 0, 0, 0);

  Map<String, dynamic> toJson() {
    return {
      "os": os,
      "cpus": cpus,
      if (!io.Platform.isMacOS) "memories": memories
    };
  }

  Hardware.fromJson(dynamic json) {
    if (json['os'] != null) _os = json['os'];

    if (json['cpus'] != null)
      for (var cpu in json['cpus']) cpus.add(CPU.fromJson(cpu));

    if (json['memories'] != null) {
      for (var memory in json['memories'])
        memories.add(Memory.fromJson(memory));

      if (memories.length > 0) {
        memories.sort((m1, m2) => m1.timestamp.compareTo(m2.timestamp));
        recentMemory = memories.last;
      }
    }
  }

  Hardware([List<Memory> pastMemories = const []]) {
    memories.addAll(pastMemories);

    try {
      _os = "${SysInfo.operatingSystemName} ${SysInfo.operatingSystemVersion}";

      //groups threads in sockets and then counts them
      var sysProcessors =
          SysInfo.processors.groupListsBy((element) => element.socket);

      for (var cpu in sysProcessors.entries) {
        int socket = cpu.key;
        List<ProcessorInfo> info = cpu.value;

        cpus.add(CPU(socket, info.first.name, info.length,
            info.first.architecture.toString()));
      }

      //gets current memory values
      Memory currentMemory = Memory(
          SysInfo.getTotalPhysicalMemory(),
          SysInfo.getFreePhysicalMemory(),
          SysInfo.getTotalVirtualMemory(),
          SysInfo.getFreeVirtualMemory());

      //checks if any memory in the list shares same timestamp (up to 10 minutes precision)
      if (!memories
          .any((memory) => memory.timestamp == currentMemory.timestamp))
        memories.add(currentMemory);
    } catch (error) {
      log.warning("Failed to get hardware info");
      log.info(error.toString());
    }
  }
}

class Memory {
  int _timestamp = 0;
  int get timestamp => _timestamp;

  //info about RAM in bytes (PHYSICAL MEMORY)
  int _totalMemory = 0;
  int get totalMemory => _totalMemory;
  int _freeMemory = 0;
  int get freeMemory => _freeMemory;
  int get usedMemory => totalMemory - freeMemory;

  //info about RAM + SWAP file in bytes
  int _totalVirtualMemory = 0;
  int get totalVirtualMemory => _totalVirtualMemory;
  int _freeVirtualMemory = 0;
  int get freeVirtualMemory => _freeVirtualMemory;
  int get usedVirtualMemory => totalVirtualMemory - freeVirtualMemory;

  //Swap only
  int get totalSwapMemory => _totalVirtualMemory - _totalMemory;
  int get freeSwapMemory => _freeVirtualMemory - _freeMemory;
  int get usedSwapMemory => usedVirtualMemory - usedMemory;

  Memory(this._totalMemory, this._freeMemory, this._totalVirtualMemory,
      this._freeVirtualMemory) {
    //divides timestamp in segments of 10 minutes
    _timestamp =
        (DateTime.now().millisecondsSinceEpoch / 1000 / 60 / 10).round() *
            1000 *
            60 *
            10;
  }

  //sums two memories together
  Memory operator +(Memory memory) {
    return Memory(
        _totalMemory + memory.totalMemory,
        _freeMemory + memory._freeMemory,
        _totalVirtualMemory + memory.totalVirtualMemory,
        _freeVirtualMemory + memory.freeVirtualMemory);
  }

  Map<String, dynamic> toJson() => {
        "timestamp": timestamp,
        "total": totalMemory,
        "free": freeMemory,
        "totalVirtual": totalVirtualMemory,
        "freeVirtual": freeVirtualMemory
      };

  Memory.fromJson(dynamic json) {
    if (json['timestamp'] != null) _timestamp = json['timestamp'];
    if (json['total'] != null) _totalMemory = json['total'];
    if (json['free'] != null) _freeMemory = json['free'];
    if (json['totalVirtual'] != null)
      _totalVirtualMemory = json['totalVirtual'];
    if (json['freeVirtual'] != null) _freeVirtualMemory = json['freeVirtual'];
  }
}

class CPU {
  int _socket = 0;
  int get socket => _socket;

  int _threads = 0;
  int get threads => _threads;

  String _name = "N/A";
  String get name => _name;

  String _arch = "N/A";
  String get arch => _arch;

  CPU(this._socket, this._name, this._threads, this._arch);

  toJson() =>
      {"socket": socket, "threads": threads, "name": name, "arch": arch};

  CPU.fromJson(dynamic json) {
    if (json['socket'] != null) _socket = json['socket'];
    if (json['threads'] != null) _threads = json['threads'];
    if (json['name'] != null) _name = json['name'];
    if (json['arch'] != null) _arch = json['arch'];
  }
}
