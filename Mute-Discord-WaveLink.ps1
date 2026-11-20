param(
    [switch]$List,
    [switch]$Mute,
    [switch]$Unmute,
    [switch]$Install,
    [switch]$Remove,
    [string]$DeviceFilter = 'Elgato Virtual Audio',
    [int]$PollIntervalSeconds = 5,
    [int]$TimeoutSeconds = 0   # veraltet, wird ignoriert (nur fuer Kompatibilitaet alter Aufrufe)
)

# =====================================================================
# Mute-Discord-WaveLink.ps1
#
# Haelt die Audio-Sitzungen von Discord auf den virtuellen Elgato Wave
# Link Geraeten stummgeschaltet, damit die Stimmen beim Bildschirmteilen
# mit Ton nicht doppelt ankommen.
#
# Modi:
#   (ohne Parameter)   Watchdog: laeuft DAUERHAFT und voellig unsichtbar
#                      im Hintergrund und stummschaltet jede
#                      Discord-Audiospur auf den Wave-Link-Geraeten -
#                      auch Spuren, die erst spaeter entstehen
#                      (z. B. wenn Apps mit Ton gestartet werden).
#                      Spuren, die von Hand freigeschaltet wurden
#                      (Mixer oder -Unmute), werden respektiert.
#   -Mute              einmalig: alles was jetzt vorhanden ist stummschalten
#   -Unmute            einmalig: alles freischalten (Watchdog respektiert das)
#   -List              anzeigen, was auf den Geraeten laeuft
#   -Install           Autostart (geplante Aufgabe) einrichten + erster Lauf
#   -Remove            Autostart + laufenden Watchdog entfernen
#   -DeviceFilter ''   alle Geraete anzeigen (Diagnose)
# =====================================================================

$ErrorActionPreference = 'Stop'

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
        return "(unbekannt)";
    }

    static List<SessionInfo> SessionsOnDevice(IMMDevice dev, string deviceName)
    {
        var list = new List<SessionInfo>();
        IntPtr pMgr;
        Guid iid = IID_IAudioSessionManager2;
        int hr = dev.Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out pMgr);
        if (hr != 0)
            throw new COMException("Activate fehlgeschlagen fuer Geraet: " + deviceName, hr);

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
            catch { info.ProcessName = "(beendet)"; }

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
                info.ProcessName += " (kein Volume-Zugriff)";
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
                if (s.ProcessName.Contains("kein Volume-Zugriff"))
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
    Write-Host ("Aktive Ausgabegeraete im Filter '{0}':" -f $DeviceFilter)
    [AudioSessionTools]::ListDevices($DeviceFilter) | ForEach-Object { Write-Host ("  Geraet: " + $_) }
    Write-Host ""
    Write-Host "Audio-Sitzungen auf diesen Geraeten:"
    [AudioSessionTools]::GetSessions($DeviceFilter) |
        Sort-Object Device, ProcessName |
        Format-Table Device, ProcessId, ProcessName, Muted, Volume -AutoSize |
        Out-String -Width 200 | Write-Host
    return
}

if ($Remove) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
    $doneList = New-Object System.Collections.Generic.List[string]
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        $doneList.Add('Geplante Aufgabe entfernt')
    } catch {}
    if (Test-Path $LnkPath) {
        Remove-Item $LnkPath -Force -ErrorAction SilentlyContinue
        $doneList.Add('Autostart-Verknuepfung entfernt')
    }
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*Mute-Discord-WaveLink.ps1*' -and $_.ProcessId -ne $PID } |
        ForEach-Object {
            try {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
                $doneList.Add('Watchdog-Prozess beendet (PID ' + $_.ProcessId + ')')
            } catch {}
        }
    if ($doneList.Count -eq 0) {
        Write-Log 'Deinstallation: nichts gefunden (war nichts installiert).'
    } else {
        foreach ($d in $doneList) { Write-Log ('Deinstallation: ' + $d) }
    }
    Write-Log ('Die Skriptdatei selbst bleibt erhalten: ' + $PSCommandPath)
    exit 0
}

if ($Install) {
    try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}

    $devices = @([AudioSessionTools]::ListDevices($DeviceFilter))
    if ($devices.Count -eq 0) {
        Write-Log ("KEINE '{0}'-Geraete gefunden. Ist Elgato Wave Link installiert?" -f $DeviceFilter)
        exit 3
    }
    foreach ($d in $devices) { Write-Log ('Wave-Link-Geraet gefunden: ' + $d) }

    # VBS-Wrapper: startet PowerShell ueber WScript.Shell.Run mit Fensterstil 0,
    # d. h. das Konsolenfenster wird von Anfang an erzeugt und ist nie sichtbar
    # (kein Aufblitzen beim Windows-Start, kein Taskbar-Eintrag).
    $inner = ($InnerArgs -f $PSCommandPath) -replace '"', '""'
    $vbsLines = @(
        "' Startet den Discord-WaveLink-Mute-Watchdog voellig unsichtbar.",
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
        $method = 'Geplante Aufgabe (Watchdog, fensterlos, ohne Zeitlimit)'
    } catch {
        try {
            $ws  = New-Object -ComObject WScript.Shell
            $lnk = $ws.CreateShortcut($LnkPath)
            $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\wscript.exe'
            $lnk.Arguments  = ('"' + $VbsPath + '"')
            $lnk.Save()
            $method = 'Autostart-Verknuepfung (Ordner, fensterlos)'
        } catch {
            Write-Log ('Installation fehlgeschlagen: ' + $_.Exception.Message)
            exit 4
        }
    }
    Write-Log ('Autostart eingerichtet: ' + $method)
}

# ---------------- Einmaliger Durchlauf (-Mute / -Unmute / -Install) ----------------

if ($Mute -or $Unmute -or $Install) {
    $wantMute = -not [bool]$Unmute
    $stateText = if ($wantMute) { 'STUMM' } else { 'AKTIV' }

    $sessions = @()
    try { $sessions = @(Get-DiscordSessions) } catch {
        Write-Log ('Fehler beim Abfragen der Audio-Sitzungen: ' + $_.Exception.Message)
        exit 1
    }

    if ($sessions.Count -eq 0) {
        Write-Log ("Keine Discord-Audiositzung auf '{0}' gefunden - nichts zu tun." -f $DeviceFilter)
        if ($wantMute) { exit 1 } else { exit 0 }
    }

    foreach ($s in $sessions) {
        try {
            $ok = [AudioSessionTools]::SetMute($DeviceFilter, $s.ProcessId, $wantMute)
            if ($ok) {
                Write-Log ("{0} (PID {1}, Geraet '{2}') -> {3}" -f $s.ProcessName, $s.ProcessId, $s.Device, $stateText)
            }
            else {
                Write-Log ("WARNUNG: Zustand konnte fuer {0} (PID {1}, Geraet '{2}') nicht gesetzt werden." -f $s.ProcessName, $s.ProcessId, $s.Device)
            }
        }
        catch {
            Write-Log ("WARNUNG: Vorgang fehlgeschlagen fuer {0} (PID {1}, Geraet '{2}'): {3}" -f $s.ProcessName, $s.ProcessId, $s.Device, $_.Exception.Message)
        }
    }
    exit 0
}

# ---------------- Watchdog (Standardmodus, laeuft dauerhaft) ----------------

$script:WatchdogMutex = New-Object System.Threading.Mutex($false, 'Local\DiscordWaveLinkAutoMuteWatchdog')
$created = $false
try { $created = $script:WatchdogMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $created = $true }
if (-not $created) {
    Write-Log 'Watchdog laeuft in dieser Anmeldung bereits - zweiter Start wird beendet.'
    exit 0
}

$MutedByUs    = @{}   # Instanz wurde von uns stummgeschaltet
$LeftAlone    = @{}   # Instanz wurde spaeter von Hand freigeschaltet -> nicht mehr anfassen
$Warned       = @{}   # Warnung pro Instanz nur einmal loggen
$lastErrorLog = [datetime]::MinValue
$pollCount    = 0

Write-Log ('Watchdog gestartet (PID {0}, Pruefung alle {1} s, Geraete-Filter ''{2}''). Stummschaltet jede Discord-Audiospur auf den Wave-Link-Geraeten - auch nachtraeglich entstehende.' -f $PID, $PollIntervalSeconds, $DeviceFilter)

while ($true) {
    $pollCount++

    $sessions = @()
    try { $sessions = @(Get-DiscordSessions) } catch {
        if ((Get-Date) -gt $lastErrorLog.AddMinutes(5)) {
            Write-Log ('Hinweis: Abfrage der Audio-Sitzungen fehlgeschlagen ({0}) - versuche es weiter.' -f $_.Exception.Message)
            $lastErrorLog = Get-Date
        }
        Start-Sleep -Seconds $PollIntervalSeconds
        continue
    }

    foreach ($s in $sessions) {
        $key = if ($s.Instance) { $s.Instance } else { '{0}|{1}' -f $s.ProcessId, $s.Device }

        if ($s.Muted) {
            # Bereits stumm: als "gewollt stumm" uebernehmen, damit eine
            # spaetere Freischaltung (von Hand oder -Unmute) als manuelle
            # Aenderung erkannt und respektiert wird.
            if (-not $MutedByUs.ContainsKey($key) -and -not $LeftAlone.ContainsKey($key)) {
                $MutedByUs[$key] = $true
            }
            continue
        }
        if ($LeftAlone.ContainsKey($key)) { continue }

        if ($MutedByUs.ContainsKey($key)) {
            # Wir haben sie stummgeschaltet, jetzt ist sie wieder hoerbar:
            # das war von Hand (Mixer oder -Unmute) -> respektieren.
            $LeftAlone[$key] = $true
            Write-Log ("{0} (PID {1}, Geraet '{2}') ist wieder hoerbar - vermutlich von Hand freigeschaltet. Lasse es zu, bis eine neue Audiospur erscheint." -f $s.ProcessName, $s.ProcessId, $s.Device)
            continue
        }

        try { $ok = [AudioSessionTools]::SetMute($DeviceFilter, $s.ProcessId, $true) } catch {
            if (-not $Warned.ContainsKey($key)) {
                $Warned[$key] = $true
                Write-Log ("WARNUNG: Stummschalten fehlgeschlagen fuer {0} (PID {1}, Geraet '{2}'): {3}" -f $s.ProcessName, $s.ProcessId, $s.Device, $_.Exception.Message)
            }
            continue
        }

        if ($ok) {
            $MutedByUs[$key] = $true
            Write-Log ("{0} (PID {1}, Geraet '{2}') -> STUMM" -f $s.ProcessName, $s.ProcessId, $s.Device)
        }
        elseif (-not $Warned.ContainsKey($key)) {
            $Warned[$key] = $true
            Write-Log ("WARNUNG: Zustand konnte fuer {0} (PID {1}, Geraet '{2}') nicht gesetzt werden." -f $s.ProcessName, $s.ProcessId, $s.Device)
        }
    }

    if (($pollCount % 60) -eq 0) { [GC]::Collect(); [GC]::WaitForPendingFinalizers() }

    Start-Sleep -Seconds $PollIntervalSeconds
}
