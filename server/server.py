import asyncio, base64, io, json, logging, os, socket, time
from typing import Any
import mss, pyautogui, websockets
from PIL import Image
from pynput.keyboard import Controller as K, Key
from zeroconf import ServiceInfo, Zeroconf

logging.basicConfig(level=logging.INFO); log = logging.getLogger("SS")
KBD = K(); M = pyautogui; M.FAILSAFE = False; M.PAUSE = 0; M.MINIMUM_DURATION = 0
SW, SH = M.size()

KM: dict[str, Key] = {
    "return": Key.enter, "enter": Key.enter, "backspace": Key.backspace,
    "delete": Key.delete, "space": Key.space, "tab": Key.tab, "escape": Key.esc,
    "esc": Key.esc, "shift": Key.shift_l, "ctrl": Key.ctrl_l, "alt": Key.alt_l,
    "cmd": Key.cmd_l, "up": Key.up, "down": Key.down, "left": Key.left, "right": Key.right,
    "home": Key.home, "end": Key.end, "pageup": Key.page_up, "pagedown": Key.page_down,
    "capslock": Key.caps_lock,
}

def pk(k: str):
    k = k.lower()
    if len(k) == 1: KBD.press(k)
    elif k in KM: KBD.press(KM[k])
    elif k.startswith("f") and k[1:].isdigit():
        fk = getattr(Key, f"f{int(k[1:])}", None)
        if fk: KBD.press(fk)

def rk(k: str):
    k = k.lower()
    if len(k) == 1: KBD.release(k)
    elif k in KM: KBD.release(KM[k])
    elif k.startswith("f") and k[1:].isdigit():
        fk = getattr(Key, f"f{int(k[1:])}", None)
        if fk: KBD.release(fk)

def tk(k: str): pk(k); time.sleep(0.015); rk(k)

SCT = mss.mss(); MON = SCT.monitors[1]; QUAL = 50; FPS = 60; LAST = 0.0

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

async def stream(ws):
    global LAST
    try:
        while True:
            n = time.time(); iv = 1.0 / FPS; e = n - LAST
            if e < iv: await asyncio.sleep(iv - e)
            LAST = time.time()
            buf = io.BytesIO()
            Image.frombytes("RGB", SCT.grab(MON).size, SCT.grab(MON).rgb).save(buf, format="JPEG", quality=QUAL, optimize=True)
            try: await ws.send(buf.getvalue())
            except websockets.exceptions.ConnectionClosed: break
    except asyncio.CancelledError: pass

async def handler(ws):
    global QUAL, FPS
    a = ws.remote_address; log.info("Client: %s", a)
    st = None
    try:
        await ws.send(json.dumps({"type":"connected","screenWidth":SW,"screenHeight":SH}))
        st = asyncio.create_task(stream(ws))
        async for r in ws:
            try: m: dict[str,Any] = json.loads(r)
            except json.JSONDecodeError: continue
            t = m.get("type")
            if t == "mouse_move": M.moveTo(max(0,min(SW,m["x"])), max(0,min(SH,m["y"])), duration=0)
            elif t == "mouse_move_relative": M.moveRel(m["dx"], m["dy"], duration=0)
            elif t == "mouse_click": M.click()
            elif t == "mouse_doubleclick": M.doubleClick()
            elif t == "mouse_rightclick": M.rightClick()
            elif t == "mouse_scroll": M.scroll(0, m["dy"])
            elif t == "key_down": pk(m.get("key",""))
            elif t == "key_up": rk(m.get("key",""))
            elif t == "key_tap": tk(m.get("key",""))
            elif t == "type_text": KBD.type(m.get("text",""))
            elif t == "ping":
                try: await ws.send(json.dumps({"type":"pong"}))
                except: break
            elif t == "set_performance":
                nq = m.get("quality", QUAL); nf = m.get("fps", FPS)
                if nq != QUAL or nf != FPS:
                    QUAL = max(10, min(90, nq)); FPS = max(10, min(60, nf))
                    log.info("Perf: q=%s fps=%s", QUAL, FPS)
                    if st: st.cancel(); st = asyncio.create_task(stream(ws))
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
        z = Zeroconf(); z.register_service(info); log.info("Bonjour: %s @ %s:%s", h, i, p); return z
    except Exception as e: log.warning("Bonjour: %s", e); return None

async def main():
    p = 8765; i = lip()
    print(); log.info("="*42); log.info("  Stream Server v3.0"); log.info("  IP: %s:%s", i, p); log.info("  Screen: %sx%s", SW, SH); log.info("  Up to 60 FPS"); log.info("="*42); print()
    z = bonjour(p)
    try:
        async with websockets.serve(handler, "0.0.0.0", p, max_size=15_000_000, max_queue=64, write_limit=4_000_000):
            log.info("Ready..."); await asyncio.Future()
    finally:
        if z: z.unregister_all_services(); z.close()
        SCT.close()

if __name__ == "__main__":
    try: asyncio.run(main())
    except KeyboardInterrupt: log.info("Stopped")
