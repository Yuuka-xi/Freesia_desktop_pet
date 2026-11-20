# 桌宠活动检测助手：由 Godot 启动，每秒输出一行 JSON
# 参数 ParentPid：桌宠进程 ID，桌宠退出后助手自动结束
# 字段：
#   idle = 距离上次键盘/鼠标操作的秒数
#   keys = 过去约 1 秒按下了几次键（只计数，不记录按了哪个键）
#   undos = 过去约 1 秒按了几次 Ctrl+Z（唯一单独识别的组合键，用于判断画画时“疯狂撤销”）
#   app  = 前台程序的进程名（小写、不带 .exe；只读进程名，不读窗口标题）
#   sound = 正在出声的程序进程名列表（只看音量电平，不录音、不读歌名）
#   path = 前台程序 exe 的完整路径（小写）
#   fullscreen = 是否处于 D3D 独占全屏（基本只有游戏会这样）
#   shots = 距上一行，剪贴板里出现了几次新图片（截屏）；只看有没有图片，不读图片内容
#   battery = 电量百分比（没有电池的台式机为 -1）
#   charging = 是否插着电源
param([int]$ParentPid = 0)

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

// 空闲时间：系统记录的最后一次输入时刻
public static class PetIdle {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
    public static double Seconds() {
        var info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        GetLastInputInfo(ref info);
        return ((uint)Environment.TickCount - info.dwTime) / 1000.0;
    }
}

// 前台程序：当前激活窗口所属进程的名字、exe 路径，以及是否独占全屏
public static class PetForeground {
    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("kernel32.dll")]
    static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool QueryFullProcessImageName(IntPtr process, int flags, System.Text.StringBuilder path, ref int size);
    [DllImport("shell32.dll")]
    static extern int SHQueryUserNotificationState(out int state);

    // 返回 [进程名, exe 路径]，都为小写；读不到就是空字符串
    public static string[] Info() {
        string name = "", path = "";
        try {
            uint pid;
            GetWindowThreadProcessId(GetForegroundWindow(), out pid);
            name = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant();
            IntPtr h = OpenProcess(0x1000, false, pid);  // 只申请“查询有限信息”权限
            if (h != IntPtr.Zero) {
                var sb = new System.Text.StringBuilder(1024);
                int size = sb.Capacity;
                if (QueryFullProcessImageName(h, 0, sb, ref size)) path = sb.ToString().ToLowerInvariant();
                CloseHandle(h);
            }
        } catch { }
        return new string[] { name, path };
    }

    // 3 = QUNS_RUNNING_D3D_FULL_SCREEN
    public static bool Fullscreen() {
        int state;
        return SHQueryUserNotificationState(out state) == 0 && state == 3;
    }
}

// 发声检测：读取音量合成器里每个程序的实时电平（Windows Core Audio）
// 下面的接口按 Windows 定义的方法顺序声明，占位方法（Skip*）不会被调用
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumerator { }

[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int Skip1();
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
}

[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr param, [MarshalAs(UnmanagedType.IUnknown)] out object obj);
}

[ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 {
    int Skip1(); int Skip2();
    [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessions);
}

[ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator {
    [PreserveSig] int GetCount(out int count);
    [PreserveSig] int GetSession(int index, [MarshalAs(UnmanagedType.IUnknown)] out object session);
}

[ComImport, Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
    int Skip1(); int Skip2(); int Skip3(); int Skip4(); int Skip5();
    int Skip6(); int Skip7(); int Skip8(); int Skip9(); int Skip10(); int Skip11();
    [PreserveSig] int GetProcessId(out uint pid);
}

[ComImport, Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioMeterInformation {
    [PreserveSig] int GetPeakValue(out float peak);
}

public static class PetSound {
    // 返回当前电平大于阈值的程序名（去重，逗号分隔）
    public static string Playing() {
        var names = new System.Collections.Generic.HashSet<string>();
        try {
            var devices = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            IMMDevice speaker;
            if (devices.GetDefaultAudioEndpoint(0, 1, out speaker) != 0) return "";  // 默认播放设备
            var iid = typeof(IAudioSessionManager2).GUID;
            object obj;
            speaker.Activate(ref iid, 23, IntPtr.Zero, out obj);
            IAudioSessionEnumerator sessions;
            ((IAudioSessionManager2)obj).GetSessionEnumerator(out sessions);
            int count;
            sessions.GetCount(out count);
            for (int i = 0; i < count; i++) {
                object s;
                sessions.GetSession(i, out s);
                float peak;
                ((IAudioMeterInformation)s).GetPeakValue(out peak);
                if (peak < 0.001f) continue;
                uint pid;
                ((IAudioSessionControl2)s).GetProcessId(out pid);
                if (pid == 0) continue;  // 系统提示音
                try {
                    names.Add(System.Diagnostics.Process.GetProcessById((int)pid).ProcessName.ToLowerInvariant());
                } catch { }
            }
        } catch { }
        return string.Join(",", names);
    }
}

// 电量：系统电源状态
public static class PetPower {
    [StructLayout(LayoutKind.Sequential)]
    struct SYSTEM_POWER_STATUS {
        public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
        public int BatteryLifeTime, BatteryFullLifeTime;
    }
    [DllImport("kernel32.dll")]
    static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS status);

    // 电量百分比；没有电池或读不到时返回 -1
    public static int Percent() {
        SYSTEM_POWER_STATUS s;
        if (!GetSystemPowerStatus(out s) || (s.BatteryFlag & 128) != 0 || s.BatteryLifePercent > 100) return -1;
        return s.BatteryLifePercent;
    }

    // 是否插着电源
    public static bool Charging() {
        SYSTEM_POWER_STATUS s;
        return GetSystemPowerStatus(out s) && s.ACLineStatus == 1;
    }
}

// 截屏检测：剪贴板内容变了，并且现在是图片，就算一次截屏
public static class PetClipboard {
    [DllImport("user32.dll")]
    static extern uint GetClipboardSequenceNumber();
    [DllImport("user32.dll")]
    static extern bool IsClipboardFormatAvailable(uint format);

    static uint last = GetClipboardSequenceNumber();  // 启动时的状态不算

    public static int NewImages() {
        uint seq = GetClipboardSequenceNumber();
        if (seq == last) return 0;
        last = seq;
        return (IsClipboardFormatAvailable(2) || IsClipboardFormatAvailable(8)) ? 1 : 0;  // 2 = CF_BITMAP, 8 = CF_DIB
    }
}

// 按键计数：全局低级键盘钩子，在独立线程里运行
public static class PetKeys {
    delegate IntPtr HookProc(int code, IntPtr wParam, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)]
    struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int x; public int y; }
    [DllImport("user32.dll")]
    static extern IntPtr SetWindowsHookEx(int idHook, HookProc fn, IntPtr hMod, uint threadId);
    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    static extern int GetMessage(out MSG msg, IntPtr hwnd, uint min, uint max);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetModuleHandle(string name);

    static HookProc proc = OnKey;  // 必须保存引用，否则会被垃圾回收
    static bool[] down = new bool[256];  // 记录哪些键正按着，过滤按住不放的连发
    static int count;

    // 启动钩子线程：钩子需要消息循环才能收到事件
    public static void Start() {
        var t = new Thread(() => {
            SetWindowsHookEx(13, proc, GetModuleHandle(null), 0);  // 13 = WH_KEYBOARD_LL
            MSG msg;
            while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) { }
        });
        t.IsBackground = true;
        t.Start();
    }

    // 每次按键回调：只看是“按下”还是“松开”，计数后立即放行
    static IntPtr OnKey(int code, IntPtr wParam, IntPtr lParam) {
        if (code >= 0) {
            int vk = Marshal.ReadInt32(lParam) & 0xFF;
            int msg = (int)wParam;
            if (msg == 0x100 || msg == 0x104) {        // 按下
                if (!down[vk]) {
                    down[vk] = true;
                    Interlocked.Increment(ref count);
                    // Ctrl+Z：Z 键按下时左或右 Ctrl 正按着
                    if (vk == 0x5A && (down[0xA2] || down[0xA3] || down[0x11])) Interlocked.Increment(ref undos);
                }
            } else if (msg == 0x101 || msg == 0x105) { // 松开
                down[vk] = false;
            }
        }
        return CallNextHookEx(IntPtr.Zero, code, wParam, lParam);
    }

    static int undos;

    // 取出计数并清零
    public static int Take() { return Interlocked.Exchange(ref count, 0); }
    public static int TakeUndos() { return Interlocked.Exchange(ref undos, 0); }
}
"@

[PetKeys]::Start()
$culture = [Globalization.CultureInfo]::InvariantCulture
while ($true) {
    # 桌宠已经退出（包括崩溃）就结束自己
    if ($ParentPid -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { break }
    $idle = [Math]::Round([PetIdle]::Seconds(), 1).ToString($culture)
    $keys = [PetKeys]::Take()
    $fg = [PetForeground]::Info()
    $app = $fg[0] -replace '[\\"]', ''
    $path = $fg[1] -replace '"', '' -replace '\\', '\\'  # JSON 里反斜杠要写成 \\
    $full = if ([PetForeground]::Fullscreen()) { 'true' } else { 'false' }
    $charging = if ([PetPower]::Charging()) { 'true' } else { 'false' }
    $sound = [PetSound]::Playing() -replace '[\\"]', ''
    $soundJson = if ($sound) { '"' + ($sound -replace ',', '","') + '"' } else { '' }
    [Console]::Out.WriteLine('{"idle":' + $idle + ',"keys":' + $keys + ',"undos":' + [PetKeys]::TakeUndos() + ',"app":"' + $app + '","path":"' + $path +
        '","fullscreen":' + $full + ',"shots":' + [PetClipboard]::NewImages() +
        ',"battery":' + [PetPower]::Percent() + ',"charging":' + $charging + ',"sound":[' + $soundJson + ']}')
    [Console]::Out.Flush()
    Start-Sleep -Seconds 1
}
