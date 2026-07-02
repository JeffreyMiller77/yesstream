import asyncio, base64, ctypes, io, json, logging, os, socket, subprocess, sys, time
from ctypes import wintypes
from typing import Any
import mss, websockets
from PIL import Image
from zeroconf import ServiceInfo, Zeroconf

user32 = ctypes.windll.user32
k32 = ctypes.windll.kernel32
ctypes.windll.shcore.SetProcessDpiAwareness(1)
STD_OUT = k32.GetStdHandle(-11); mode = ctypes.c_uint(0)
if k32.GetConsoleMode(STD_OUT, ctypes.byref(mode)):
    k32.SetConsoleMode(STD_OUT, mode.value | 0x0004)

SW, SH = user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)

def m_move(x, y): user32.SetCursorPos(max(0, min(SW, int(x))), max(0, min(SH, int(y))))
def m_down(): user32.mouse_event(2, 0, 0, 0, 0)
def m_up(): user32.mouse_event(4, 0, 0, 0, 0)
def m_click(): m_down(); m_up()
def m_dclick(): m_click(); m_click()
def m_rclick(): user32.mouse_event(8, 0, 0, 0, 0); user32.mouse_event(16, 0, 0, 0, 0)
def m_scroll(dy): user32.mouse_event(0x0800, 0, 0, int(dy * 120), 0)
def m_move_rel(dx, dy): user32.mouse_event(1, int(dx), int(dy), 0, 0)

VK = {
    "return":0x0D,"enter":0x0D,"backspace":0x08,"delete":0x2E,"space":0x20,"tab":0x09,
    "escape":0x1B,"esc":0x1B,"shift":0x10,"ctrl":0x11,"alt":0x12,"cmd":0x5B,
    "up":0x26,"down":0x28,"left":0x25,"right":0x27,"home":0x24,"end":0x23,
    "pageup":0x21,"pagedown":0x22,"capslock":0x14,
}
for i in range(1,13): VK[f"f{i}"] = 0x6F+i-1

def vk(k: str) -> int:
    k = k.lower()
    if k in VK: return VK[k]
    if len(k) == 1:
        v = user32.VkKeyScanW(ord(k))
        return v & 0xFF if v != -1 else 0
    return 0

def k_down(k: str): c = vk(k); user32.keybd_event(c, 0, 0, 0) if c else None
def k_up(k: str): c = vk(k); user32.keybd_event(c, 0, 2, 0) if c else None
def k_tap(k: str): k_down(k); time.sleep(0.008); k_up(k)
def type_text(t: str):
    for c in t:
        v = user32.VkKeyScanW(ord(c))
        if v != -1:
            vb, sft = v & 0xFF, (v >> 8) & 1
            if sft: k_down("shift")
            user32.keybd_event(vb, 0, 0, 0)
            user32.keybd_event(vb, 0, 2, 0)
            if sft: k_up("shift")
        time.sleep(0.004)

SCT = mss.mss(); MON = SCT.monitors[1]
QUAL, FPS, LAST, WATCH, INPUTS = 50, 60, 0.0, False, 0
PING_TX, PING_RX = 0.0, 0.0

RES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "resources")
RES_VER_FILE = os.path.join(RES_DIR, "version")

def get_res_version() -> str:
    try:
        with open(RES_VER_FILE) as f: return f.read().strip()
    except: return "0"

def get_res_files(base: str = "") -> list[dict]:
    files = []
    pfx = os.path.join(RES_DIR, base) if base else RES_DIR
    if not os.path.isdir(pfx): return files
    for e in os.listdir(pfx):
        fp = os.path.join(pfx, e)
        rp = os.path.join(base, e) if base else e
        if os.path.isfile(fp):
            with open(fp, "rb") as f:
                files.append({"path": rp.replace(os.sep, "/"), "data": base64.b64encode(f.read()).decode()})
        elif os.path.isdir(fp):
            files.extend(get_res_files(rp))
    return files

def launch_game(exe: str):
    try:
        paths = [
            exe,
            os.path.expandvars(f"%LOCALAPPDATA%\\{exe}"),
            os.path.expandvars(f"%PROGRAMFILES%\\{exe}"),
            os.path.expandvars(f"%PROGRAMFILES(X86)%\\{exe}"),
        ]
        for p in paths:
            if os.path.exists(p):
                subprocess.Popen([p], shell=True)
                return True
        subprocess.Popen([exe], shell=True)
        return True
    except: return False

GAME_CMDS = {
    "minecraft": r"MinecraftLauncher.exe",
    "roblox": r"RobloxPlayerLauncher.exe",
}

logging.basicConfig(level=logging.INFO, format="%(message)s"); log = logging.getLogger("SS")

def dashboard():
    fps_s = "OFF" if WATCH else f"{FPS}fps"
    print(f"\033[H\033[J╔══════════════════════════════════════╗")
    print(f"║  \033[36mStream Server v3.0\033[0m {'':24s}║")
    print(f"║  \033[90m{socket.gethostname()} @ {lip()}:8765\033[0m {'':16s}║")
    print(f"╠══════════════════════════════════════╣")
    print(f"║  Screen: {SW}x{SH}{'':26s}║")
    print(f"║  Quality: {QUAL}  |  FPS: {fps_s}{'':14s}║")
    print(f"║  Mode: {'WATCH' if WATCH else 'GAME'}{'':26s}║")
    print(f"║  Inputs: {INPUTS}{'':34s}║")
    print(f"╚══════════════════════════════════════╝")

async def stream(ws):
    global LAST, QUAL, FPS
    try:
        while True:
            n = time.time(); iv = 1.0 / FPS; e = n - LAST
            if e < iv: await asyncio.sleep(iv - e)
            LAST = time.time()
            try:
                img = Image.frombytes("RGB", SCT.grab(MON).size, SCT.grab(MON).rgb)
            except: continue
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=QUAL, optimize=True)
            try:
                await ws.send(buf.getvalue())
            except websockets.exceptions.ConnectionClosed:
                break
    except asyncio.CancelledError: pass

async def handler(ws):
    global QUAL, FPS, WATCH, INPUTS, PING_TX, PING_RX
    a = ws.remote_address; log.info("Client: %s", a)
    st = None
    try:
        await ws.send(json.dumps({"type":"connected","screenWidth":SW,"screenHeight":SH}))
        st = asyncio.create_task(stream(ws))
        async for r in ws:
            try: m: dict[str,Any] = json.loads(r)
            except json.JSONDecodeError: continue
            if WATCH and m.get("type") not in ("ping","pong","check_resources","request_update","set_performance"):
                continue
            t = m.get("type")
            INPUTS += 1
            if t == "mouse_move": m_move(m["x"], m["y"])
            elif t == "mouse_move_relative": m_move_rel(m["dx"], m["dy"])
            elif t == "mouse_click": m_click()
            elif t == "mouse_doubleclick": m_dclick()
            elif t == "mouse_rightclick": m_rclick()
            elif t == "mouse_scroll": m_scroll(m["dy"])
            elif t == "key_down": k_down(m.get("key",""))
            elif t == "key_up": k_up(m.get("key",""))
            elif t == "key_tap": k_tap(m.get("key",""))
            elif t == "type_text": type_text(m.get("text",""))
            elif t == "ping":
                PING_TX = time.time()
                try: await ws.send(json.dumps({"type":"pong","ts":PING_TX}))
                except: break
            elif t == "pong":
                PING_RX = time.time() - m.get("ts", PING_RX)
            elif t == "set_performance":
                nq = m.get("quality", QUAL); nf = m.get("fps", FPS)
                if nq != QUAL or nf != FPS:
                    QUAL = max(10, min(90, nq)); FPS = max(10, min(60, nf))
                    if st: st.cancel(); st = asyncio.create_task(stream(ws))
                    dashboard()
            elif t == "set_mode":
                WATCH = m.get("watch", False)
                if WATCH:
                    QUAL = max(QUAL, 70); FPS = max(FPS, 30)
                else:
                    QUAL = min(QUAL, 50)
                if st: st.cancel(); st = asyncio.create_task(stream(ws))
                dashboard()
            elif t == "launch_game":
                game = m.get("game", "")
                if game in GAME_CMDS:
                    ok = launch_game(GAME_CMDS[game])
                    await ws.send(json.dumps({"type":"game_launched","game":game,"ok":ok}))
            elif t == "check_resources":
                cv = m.get("resource_version", "0")
                sv = get_res_version()
                if cv == sv:
                    await ws.send(json.dumps({"type":"up_to_date","resource_version":sv}))
                else:
                    files = get_res_files()
                    await ws.send(json.dumps({"type":"update_available","resource_version":sv,"fileCount":len(files)}))
            elif t == "request_update":
                sv = get_res_version(); files = get_res_files()
                if st: st.cancel(); st = None
                await ws.send(json.dumps({"type":"update_start","resource_version":sv,"fileCount":len(files)}))
                for f in files:
                    await ws.send(json.dumps({"type":"update_file","path":f["path"],"data":f["data"],"resource_version":sv}))
                await ws.send(json.dumps({"type":"update_complete","resource_version":sv}))
                st = asyncio.create_task(stream(ws))
                dashboard()
    except websockets.exceptions.ConnectionClosed: log.info("Disconnected: %s", a)
    except Exception as e: log.error("Error: %s", e)
    finally:
        if st: st.cancel()

def lip():
    try: s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(("8.8.8.8",80)); i = s.getsockname()[0]; s.close(); return i
    except: return "127.0.0.1"

def bonjour(p: int) -> Zeroconf | None:
    try:
        h = socket.gethostname(); i = lip()
        info = ServiceInfo("_stream._tcp.local.", f"{h}._stream._tcp.local.", [socket.inet_aton(i)], p, {"v":"3.0","rv":get_res_version()}, f"{h}.local.")
        z = Zeroconf(); z.register_service(info); return z
    except: return None

async def main():
    p = 8765; i = lip()
    print(f"\033[?25l", end="")
    dashboard()
    z = bonjour(p)
    try:
        async with websockets.serve(handler, "0.0.0.0", p, max_size=15_000_000, max_queue=64, write_limit=4_000_000):
            await asyncio.Future()
    finally:
        print(f"\033[?25h", end="")
        if z: z.unregister_all_services(); z.close()
        SCT.close()

if __name__ == "__main__":
    try: asyncio.run(main())
    except KeyboardInterrupt: pass
