param(
    [switch]$List,
    [switch]$Mute,
    [switch]$Unmute,
    [switch]$Install,
    [switch]$Remove,
    [ValidateSet('auto','en','de')]
    [string]$Language = 'auto',
    [string]$DeviceFilter = 'Elgato Virtual Audio',
    [int]$PollIntervalSeconds = 5,
    [int]$TimeoutSeconds = 0   # deprecated and ignored (kept for compatibility with old shortcuts)
)

# =====================================================================
# Mute-Discord-WaveLink.ps1
#
# Keeps Discord's audio sessions muted on the virtual Elgato Wave Link
# devices so that call voices are not heard twice when screen sharing
# with sound (Discord captures the default output device, which on Wave
# Link setups often carries the call voices too).
#
# Output language:
#   Automatic by default - German on German Windows, English otherwise.
#   Use -Language en / -Language de to force a language.
#
# Modes:
#   (no parameters)    Watchdog: runs PERMANENTLY and fully invisible in
#                      the background and mutes every Discord audio
#                      session on the Wave Link devices - including
#                      sessions that appear later (e.g. when apps with
#                      sound are opened). Sessions unmuted by hand
#                      (mixer or -Unmute) are respected.
#   -Mute              one-shot: mute everything currently present
#   -Unmute            one-shot: unmute everything (the watchdog honors it)
#   -List              show what is running on the devices
#   -Install           set up invisible autostart (scheduled task) + first run
#   -Remove            remove autostart + running watchdog
#   -DeviceFilter ''   list all devices (diagnostics)
# =====================================================================

$ErrorActionPreference = 'Stop'

# Output language: automatic by default (German on German Windows, English otherwise).
$script:Lang = if ($Language -eq 'auto') {
    if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' }
} else {
    $Language
}

function T([string]$en, [string]$de) {
    if ($script:Lang -eq 'de') { return $de }
    return $en
}

$LogDir = Join-Path $env:LOCALAPPDATA 'DiscordMuteAutomation'
$LogFile = Join-Path $LogDir 'log.txt'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    for ($i = 0; $i -lt 3; $i++) {
        try { Add-Content -Path $LogFile -Value $line -Encoding UTF8; break } catch { Start-Sleep -Milliseconds 120 }
    }
    Write-Host $line
}

if (-not ('AudioSessionTools' -as [type])) {
    $src = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class AudioSessionTools
{
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorCom {}

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice endpoint);
        int RegisterEndpointNotificationCallback(IntPtr client);
        int UnregisterEndpointNotificationCallback(IntPtr client);
    }

    [Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceCollection
    {
        int GetCount(out int count);
        int Item(int index, out IMMDevice device);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, out IntPtr iface);
        int OpenPropertyStore(int access, out IPropertyStore properties);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetState(out int state);
    }

    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore
    {
        int GetCount(out int count);
        int GetAt(int index, out PropertyKey key);
        int GetValue(ref PropertyKey key, out PropVariant value);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropertyKey { public Guid fmtid; public int pid; }

    [StructLayout(LayoutKind.Explicit)]
    public struct PropVariant
    {
        [FieldOffset(0)] public short vt;
        [FieldOffset(8)] public IntPtr pointerValue;
    }

    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionManager2
    {
        int GetAudioSessionControl(IntPtr audioSessionGuid, int streamFlags, out IntPtr sessionControl);
        int GetSimpleAudioVolume(IntPtr audioSessionGuid, int streamFlags, out IntPtr audioVolume);
        int GetSessionEnumerator(out IAudioSessionEnumerator sessionEnumerator);
        int RegisterSessionNotification(IntPtr sessionNotification);
        int UnregisterSessionNotification(IntPtr sessionNotification);
        int RegisterDuckNotification(IntPtr deviceId, IntPtr duckNotification);
        int UnregisterDuckNotification(IntPtr duckNotification);
    }

    [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionEnumerator
    {
        int GetCount(out int sessionCount);
        int GetSession(int index, out IAudioSessionControl2 session);
    }

    [Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl2
    {
        int GetState(out int state);
        int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string displayName);
        int SetDisplayName(IntPtr displayName, IntPtr eventContext);
        int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string iconPath);
        int SetIconPath(IntPtr iconPath, IntPtr eventContext);
        int GetGroupingParam(out Guid groupingParam);
        int SetGroupingParam(IntPtr overrideParam, IntPtr eventContext);
        int RegisterAudioSessionNotification(IntPtr notifications);
        int UnregisterAudioSessionNotification(IntPtr notifications);
        int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string retVal);
        int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string retVal);
        int GetProcessId(out int processId);
        int IsSystemSoundsSession();
        int SetDuckingPreference(int optOut);
    }

    [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ISimpleAudioVolume
    {
        int SetMasterVolume(float level, IntPtr eventContext);
        int GetMasterVolume(out float level);
        int SetMute(int mute, IntPtr eventContext);
        int GetMute(out int mute);
    }

    public class SessionInfo
    {
        public string Device;
        public int ProcessId;
        public string ProcessName;
        public bool Muted;
        public double Volume;
        public string Instance;
    }

    const int eRender = 0;
    const int DEVICE_STATE_ACTIVE = 1;
    const int CLSCTX_ALL = 23;
    const int STGM_READ = 0;

    static readonly Guid IID_IAudioSessionManager2 = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F");
    static PropertyKey PKEY_FriendlyName = new PropertyKey { fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), pid = 14 };

    static string ReadFriendlyName(IMMDevice dev)
    {
        try
        {
            IPropertyStore store;
            dev.OpenPropertyStore(STGM_READ, out store);
            PropVariant v;
            PropertyKey k = PKEY_FriendlyName;
            store.GetValue(ref k, out v);
            if (v.vt == 31 && v.pointerValue != IntPtr.Zero)
                return Marshal.PtrToStringUni(v.pointerValue);
        }
        catch {}
        return "(unknown)";
    }

    static List<SessionInfo> SessionsOnDevice(IMMDevice dev, string deviceName)
    {
        var list = new List<SessionInfo>();
        IntPtr pMgr;
        Guid iid = IID_IAudioSessionManager2;
        int hr = dev.Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out pMgr);
        if (hr != 0)
            throw new COMException("Activate failed for device: " + deviceName, hr);

        var mgr = (IAudioSessionManager2)Marshal.GetObjectForIUnknown(pMgr);
        Marshal.Release(pMgr);

        IAudioSessionEnumerator sessEnum;
        mgr.GetSessionEnumerator(out sessEnum);

        int sessCount;
        sessEnum.GetCount(out sessCount);

        for (int s = 0; s < sessCount; s++)
        {
            IAudioSessionControl2 ctl;
            sessEnum.GetSession(s, out ctl);

            int pid;
            ctl.GetProcessId(out pid);

            var info = new SessionInfo { Device = deviceName, ProcessId = pid, Instance = "" };
            try { string inst; ctl.GetSessionInstanceIdentifier(out inst); info.Instance = inst ?? ""; } catch {}

            try { info.ProcessName = Process.GetProcessById(pid).ProcessName; }
            catch { info.ProcessName = "(terminated)"; }

            try
            {
                ISimpleAudioVolume vol = (ISimpleAudioVolume)ctl;
                int muted;
                float level;
                vol.GetMute(out muted);
                vol.GetMasterVolume(out level);
                info.Muted = (muted != 0);
                info.Volume = Math.Round((double)level, 2);
            }
            catch
            {
                info.ProcessName += " (no volume access)";
            }

            list.Add(info);
        }
        return list;
    }

    public static List<SessionInfo> GetSessions(string deviceSubstring)
    {
        var result = new List<SessionInfo>();
        var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDeviceCollection coll;
        en.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, out coll);

        int count;
        coll.GetCount(out count);

        for (int i = 0; i < count; i++)
        {
            IMMDevice dev;
            coll.Item(i, out dev);
            string name = ReadFriendlyName(dev);
            if (deviceSubstring != null && name.IndexOf(deviceSubstring, StringComparison.OrdinalIgnoreCase) < 0)
                continue;
            result.AddRange(SessionsOnDevice(dev, name));
        }
        return result;
    }

    public static List<string> ListDevices(string deviceSubstring)
    {
        var names = new List<string>();
        var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDeviceCollection coll;
        en.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, out coll);

        int count;
        coll.GetCount(out count);

        for (int i = 0; i < count; i++)
        {
            IMMDevice dev;
            coll.Item(i, out dev);
            string name = ReadFriendlyName(dev);
            if (deviceSubstring != null && name.IndexOf(deviceSubstring, StringComparison.OrdinalIgnoreCase) < 0)
                continue;
            names.Add(name);
        }
        return names;
    }

    public static bool SetMute(string deviceSubstring, int processId, bool mute)
    {
        bool changed = false;
        var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDeviceCollection coll;
        en.EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, out coll);

        int count;
        coll.GetCount(out count);

        for (int i = 0; i < count; i++)
        {
            IMMDevice dev;
            coll.Item(i, out dev);
            string name = ReadFriendlyName(dev);
            if (deviceSubstring != null && name.IndexOf(deviceSubstring, StringComparison.OrdinalIgnoreCase) < 0)
                continue;

            foreach (var s in SessionsOnDevice(dev, name))
            {
                if (s.ProcessId != processId)
                    continue;
                if (s.ProcessName.Contains("no volume access"))
                    continue;

                IntPtr pMgr;
                Guid iid = IID_IAudioSessionManager2;
                dev.Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out pMgr);
                var mgr = (IAudioSessionManager2)Marshal.GetObjectForIUnknown(pMgr);
                Marshal.Release(pMgr);

                IAudioSessionEnumerator sessEnum;
                mgr.GetSessionEnumerator(out sessEnum);

                int sessCount;
                sessEnum.GetCount(out sessCount);
                for (int s2 = 0; s2 < sessCount; s2++)
                {
                    IAudioSessionControl2 ctl;
                    sessEnum.GetSession(s2, out ctl);
                    int pid;
                    ctl.GetProcessId(out pid);
                    if (pid != processId) continue;

                    ISimpleAudioVolume vol = (ISimpleAudioVolume)ctl;
                    vol.SetMute(mute ? 1 : 0, IntPtr.Zero);
                    int nowMuted;
                    vol.GetMute(out nowMuted);
                    if ((nowMuted != 0) == mute)
                        changed = true;
                }
            }
        }
        return changed;
    }
}
'@
    Add-Type -TypeDefinition $src -Language CSharp
}

# ---------------------------------------------------------------------

$TaskName  = 'Discord-WaveLink-AutoMute'
$LnkPath   = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Discord WaveLink Mute.lnk'
$InnerArgs = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"'
$VbsPath   = Join-Path $PSScriptRoot 'Start-DiscordMuteWatchdog.vbs'
$pattern   = '^(Discord|DiscordCanary|DiscordPTB)$'

function Get-DiscordSessions {
    @([AudioSessionTools]::GetSessions($DeviceFilter) | Where-Object { $_.ProcessName -match $pattern })
}

if ($List) {
    Write-Host ((T "Active output devices matching '{0}':" "Aktive Ausgabegeraete passend zu '{0}':") -f $DeviceFilter)
    [AudioSessionTools]::ListDevices($DeviceFilter) | ForEach-Object { Write-Host ((T '  Device: ' '  Geraet: ') + $_) }
    Write-Host ""
    Write-Host (T 'Audio sessions on these devices:' 'Audiospuren auf diesen Geraeten:')
    $rows = @([AudioSessionTools]::GetSessions($DeviceFilter) | Sort-Object Device, ProcessName)
    if ($script:Lang -eq 'de') {
        $rows |
            Select-Object @{n='Geraet';e={$_.Device}}, @{n='Prozess-ID';e={$_.ProcessId}}, @{n='Prozess';e={$_.ProcessName}}, @{n='Stumm';e={$_.Muted}}, @{n='Lautstaerke';e={$_.Volume}} |
            Format-Table -AutoSize |
            Out-String -Width 200 | Write-Host
    } else {
        $rows |
            Format-Table Device, ProcessId, ProcessName, Muted, Volume -AutoSize |
            Out-String -Width 200 | Write-Host
    }
    return
}

if ($Remove) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
    $doneList = New-Object System.Collections.Generic.List[string]
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        $doneList.Add((T 'Removed scheduled task' 'Geplante Aufgabe entfernt'))
    } catch {}
    if (Test-Path $LnkPath) {
        Remove-Item $LnkPath -Force -ErrorAction SilentlyContinue
        $doneList.Add((T 'Removed startup shortcut' 'Autostart-Verknuepfung entfernt'))
    }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*Mute-Discord-WaveLink.ps1*' -and $_.ProcessId -ne $PID } |
        ForEach-Object {
            try {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
                $doneList.Add(((T 'Stopped watchdog process (PID {0})' 'Watchdog-Prozess beendet (PID {0})') -f $_.ProcessId))
            } catch {}
        }
    if ($doneList.Count -eq 0) {
        Write-Log (T 'Uninstall: nothing found (nothing was installed).' 'Deinstallation: nichts gefunden (es war nichts installiert).')
    } else {
        foreach ($d in $doneList) { Write-Log ((T 'Uninstall: ' 'Deinstallation: ') + $d) }
    }
    Write-Log ((T 'The script file itself is kept: ' 'Die Skriptdatei selbst bleibt erhalten: ') + $PSCommandPath)
    exit 0
}

if ($Install) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}

    $devices = @([AudioSessionTools]::ListDevices($DeviceFilter))
    if ($devices.Count -eq 0) {
        Write-Log ((T "No devices matching '{0}' found. Is Elgato Wave Link installed?" "Keine Geraete passend zu '{0}' gefunden. Ist Elgato Wave Link installiert?") -f $DeviceFilter)
        exit 3
    }
    foreach ($d in $devices) { Write-Log ((T 'Wave Link device found: ' 'Wave-Link-Geraet gefunden: ') + $d) }

    # VBS wrapper: starts PowerShell via WScript.Shell.Run with window style 0,
    # i.e. the console window is created hidden from the start (no flash at
    # Windows logon, no taskbar entry).
    $inner = ($InnerArgs -f $PSCommandPath) -replace '"', '""'
    $vbsLines = @(
        "' Starts the Discord-WaveLink mute watchdog completely invisible.",
        ('CreateObject("WScript.Shell").Run "' + $inner + '", 0, False'),
        ''
    )
    Set-Content -Path $VbsPath -Value $vbsLines -Encoding Ascii

    $method = ''
    try {
        $action    = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\wscript.exe') -Argument ('"' + $VbsPath + '"')
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Seconds 0)
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        try { Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop } catch {}
        $method = T 'Scheduled task (watchdog, windowless, no time limit)' 'Geplante Aufgabe (Watchdog, fensterlos, kein Zeitlimit)'
    } catch {
        try {
            $ws  = New-Object -ComObject WScript.Shell
            $lnk = $ws.CreateShortcut($LnkPath)
            $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
            $lnk.Arguments  = ('"' + $VbsPath + '"')
            $lnk.Save()
            $method = T 'Startup folder shortcut (windowless)' 'Autostart-Verknuepfung (fensterlos)'
        } catch {
            Write-Log ((T 'Installation failed: ' 'Installation fehlgeschlagen: ') + $_.Exception.Message)
            exit 4
        }
    }
    Write-Log ((T 'Autostart configured: ' 'Autostart eingerichtet: ') + $method)
}

# ---------------- One-shot pass (-Mute / -Unmute / -Install) ----------------

if ($Mute -or $Unmute -or $Install) {
    $wantMute = -not [bool]$Unmute
    $stateText = if ($wantMute) { T 'MUTED' 'STUMM' } else { T 'UNMUTED' 'AKTIV' }

    $sessions = @()
    try { $sessions = @(Get-DiscordSessions) } catch {
        Write-Log ((T 'Error while querying audio sessions: ' 'Fehler beim Abfragen der Audiospuren: ') + $_.Exception.Message)
        exit 1
    }

    if ($sessions.Count -eq 0) {
        Write-Log ((T "No Discord audio session on '{0}' found - nothing to do." "Keine Discord-Audiospur auf '{0}' gefunden - nichts zu tun.") -f $DeviceFilter)
        if ($wantMute) { exit 1 } else { exit 0 }
    }

    foreach ($s in $sessions) {
        try {
            $ok = [AudioSessionTools]::SetMute($DeviceFilter, $s.ProcessId, $wantMute)
            if ($ok) {
                Write-Log ((T "{0} (PID {1}, device '{2}') -> {3}" "{0} (PID {1}, Geraet '{2}') -> {3}") -f $s.ProcessName, $s.ProcessId, $s.Device, $stateText)
            }
            else {
                Write-Log ((T "WARNING: Could not set state for {0} (PID {1}, device '{2}')." "WARNUNG: Zustand konnte fuer {0} (PID {1}, Geraet '{2}') nicht gesetzt werden.") -f $s.ProcessName, $s.ProcessId, $s.Device)
            }
        }
        catch {
            Write-Log ((T "WARNING: Operation failed for {0} (PID {1}, device '{2}'): {3}" "WARNUNG: Vorgang fehlgeschlagen fuer {0} (PID {1}, Geraet '{2}'): {3}") -f $s.ProcessName, $s.ProcessId, $s.Device, $_.Exception.Message)
        }
    }
    exit 0
}

# ---------------- Watchdog (default mode, runs permanently) ----------------

$script:WatchdogMutex = New-Object System.Threading.Mutex($false, 'Local\DiscordWaveLinkAutoMuteWatchdog')
$created = $false
try { $created = $script:WatchdogMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $created = $true }
if (-not $created) {
    Write-Log (T 'A watchdog is already running in this logon session - exiting second instance.' 'Ein Watchdog laeuft in dieser Anmeldesitzung bereits - zweite Instanz wird beendet.')
    exit 0
}

$MutedByUs    = @{}   # session instance was muted by us
$LeftAlone    = @{}   # session instance was unmuted by hand later -> do not touch it again
$Warned       = @{}   # log a warning only once per instance
$lastErrorLog = [datetime]::MinValue
$pollCount    = 0

Write-Log ((T 'Watchdog started (PID {0}, checking every {1} s, device filter ''{2}''). Muting every Discord audio session on the Wave Link devices - including sessions that appear later.' 'Watchdog gestartet (PID {0}, Pruefung alle {1} s, Geraetefilter ''{2}''). Jede Discord-Audiospur auf den Wave-Link-Geraeten wird stummgeschaltet - auch Spuren, die spaeter entstehen.') -f $PID, $PollIntervalSeconds, $DeviceFilter)

while ($true) {
    $pollCount++

    $sessions = @()
    try { $sessions = @(Get-DiscordSessions) } catch {
        if ((Get-Date) -gt $lastErrorLog.AddMinutes(5)) {
            Write-Log ((T 'Note: Failed to query audio sessions ({0}) - will keep trying.' 'Hinweis: Audiospuren konnten nicht abgefragt werden ({0}) - es wird weiter versucht.') -f $_.Exception.Message)
            $lastErrorLog = Get-Date
        }
        Start-Sleep -Seconds $PollIntervalSeconds
        continue
    }

    foreach ($s in $sessions) {
        $key = if ($s.Instance) { $s.Instance } else { '{0}|{1}' -f $s.ProcessId, $s.Device }

        if ($s.Muted) {
            # Already muted: adopt it as "intentionally muted" so that a later
            # unmute (by hand or -Unmute) is detected and respected.
            if (-not $MutedByUs.ContainsKey($key) -and -not $LeftAlone.ContainsKey($key)) {
                $MutedByUs[$key] = $true
            }
            continue
        }
        if ($LeftAlone.ContainsKey($key)) { continue }

        if ($MutedByUs.ContainsKey($key)) {
            # We muted it, now it is audible again: this was done by hand
            # (mixer or -Unmute) -> respect it.
            $LeftAlone[$key] = $true
            Write-Log ((T "{0} (PID {1}, device '{2}') is audible again - probably unmuted manually. Leaving it alone until a new audio session appears." "{0} (PID {1}, Geraet '{2}') ist wieder hoerbar - wahrscheinlich manuell freigeschaltet. Wird in Ruhe gelassen, bis eine neue Audiospur erscheint.") -f $s.ProcessName, $s.ProcessId, $s.Device)
            continue
        }

        try { $ok = [AudioSessionTools]::SetMute($DeviceFilter, $s.ProcessId, $true) } catch {
            if (-not $Warned.ContainsKey($key)) {
                $Warned[$key] = $true
                Write-Log ((T "WARNING: Muting failed for {0} (PID {1}, device '{2}'): {3}" "WARNUNG: Stummschalten fehlgeschlagen fuer {0} (PID {1}, Geraet '{2}'): {3}") -f $s.ProcessName, $s.ProcessId, $s.Device, $_.Exception.Message)
            }
            continue
        }

        if ($ok) {
            $MutedByUs[$key] = $true
            Write-Log ((T "{0} (PID {1}, device '{2}') -> MUTED" "{0} (PID {1}, Geraet '{2}') -> STUMM") -f $s.ProcessName, $s.ProcessId, $s.Device)
        }
        elseif (-not $Warned.ContainsKey($key)) {
            $Warned[$key] = $true
            Write-Log ((T "WARNING: Could not set state for {0} (PID {1}, device '{2}')." "WARNUNG: Zustand konnte fuer {0} (PID {1}, Geraet '{2}') nicht gesetzt werden.") -f $s.ProcessName, $s.ProcessId, $s.Device)
        }
    }

    if (($pollCount % 60) -eq 0) { [GC]::Collect(); [GC]::WaitForPendingFinalizers() }

    Start-Sleep -Seconds $PollIntervalSeconds
}
