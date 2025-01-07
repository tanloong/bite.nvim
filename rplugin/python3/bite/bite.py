#!/usr/bin/env python3

import json
import logging
import queue
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pynvim

logging.basicConfig(format="%(message)s", filename="server.log", level=logging.INFO)


class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def __init__(self, nvim, q: queue.Queue, close_sse, request, client_address, server):
        self.nvim = nvim
        self.q = q
        self.close_sse = close_sse
        super().__init__(request, client_address, server)

    def do_GET(self):
        if self.path != "/sse":
            self.send_error(404, "Not Found")

        # 设置 SSE 相关的头
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")  # 允许所有域
        self.end_headers()

        self.close_sse.clear()

        while True:
            # time.sleep(1)
            #
            # if self.q.empty():
            #     continue

            data = self.q.get()

            if self.close_sse.is_set():
                self.q.put(data)
                return

            json_data = json.dumps(data, ensure_ascii=False)
            try:
                self.wfile.write(f"data: {json_data}\n\n".encode())
            except (BrokenPipeError, ConnectionResetError) as ex:
                # 客户端已关闭连接
                logging.info("警告: 客户端已断开连接" + str(ex))
                self.q.put(data)
                return  # 退出函数，处理下一个请求

    def do_OPTIONS(self):
        # 处理预检请求
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        # 设置 CORS 头
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")  # 允许所有域
        self.end_headers()

        if self.path == "/close-sse":
            self.close_sse.set()
            self.wfile.write(json.dumps({"status": "ok", "msg": "已收到关闭 SSE 请求"}).encode("utf-8"))
            return

        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        try:
            data = json.loads(post_data.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return
        subsections = (
            "人工英文转写结果",
            "人工英文断句结果",
            "人工同传中文结果",
            "人工同传中文断句结果",
            "人工英文顺滑结果",
            "人工英文顺滑断句结果",
        )
        subsection_lines = []
        for k in sorted(data.keys(), key=lambda s: int(s)):
            subsection_lines.append("# " + k)
            subsection_lines.append("")
            for subsection in subsections:
                subsection_lines.append("## " + subsection)
                subsection_lines.append("")
                subsection_lines.append(data[k][subsection])
                subsection_lines.append("")
        self.nvim.async_call(lambda: self.nvim.current.buffer.append(subsection_lines))
        self.wfile.write(json.dumps({"status": "ok", "msg": "已收到数据"}).encode("utf-8"))


@pynvim.plugin
class Bite:
    def __init__(self, nvim):
        self.nvim = nvim
        self.q = queue.Queue()
        self.close_sse = threading.Event()
        self.httpd = None
        self.server_thread = None
        self.receive_data_thread = None
        self.port = 9001

    @pynvim.function("BiteStartServer", sync=False)
    def start_server(self, *_):
        if self.httpd is not None:
            self.nvim.out_write("Server is already running\n")
            return
        if not self._is_port_available(self.port):
            self.nvim.out_write("Port 9001 is already in use\n")
            return

        self.close_sse.clear()

        self.httpd = ThreadingHTTPServer(
            ("", self.port), lambda *args: SimpleHTTPRequestHandler(self.nvim, self.q, self.close_sse, *args)
        )

        # 启动服务器线程
        self.server_thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.server_thread.start()

        self.nvim.out_write("Server started on port 9001\n")
        self.nvim.command("hi StatusLine guibg='green' ctermbg=2")

    @pynvim.function("BiteStopServer", sync=False)
    def do_stop_server(self, *_):
        if self.httpd is None:
            self.nvim.out_write("Server is not running\n")
            return

        # 关闭服务器
        self.close_sse.set()
        self.httpd.shutdown()
        self.httpd.server_close()
        self.httpd = None
        self.server_thread.join()  # 等待线程结束
        self.server_thread = None

        self.nvim.command("hi clear StatusLine")

    @pynvim.function("BiteSendData", sync=False)
    def do_send_data(self, data: dict):
        if self.httpd is None:
            self.nvim.out_write("Server is not running\n")
            return

        self.q.put(data)
        self.nvim.out_write("Data sent to queue\n")

    def _is_port_available(self, port: int):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.settimeout(1)
                s.connect(("127.0.0.1", port))
                return False  # 端口被占用
            except OSError:
                return True  # 端口未被占用
