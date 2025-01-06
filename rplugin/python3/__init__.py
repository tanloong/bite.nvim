#!/usr/bin/env python3

import json
import logging
import queue
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

import pynvim

logging.basicConfig(format="%(message)s", filename="server.log", level=logging.INFO)

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def __init__(self, nvim, q, shutdown_flag, request, client_address, server):
        self.nvim = nvim
        self.q = q
        self.shutdown_flag = shutdown_flag
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

        while True:
            time.sleep(1)

            if self.shutdown_flag.is_set():
                self.send_error(503, "Service Unavailable")
                return

            if self.q.empty():
                continue

            data = self.q.get()
            json_data = json.dumps(data, ensure_ascii=False)
            self.wfile.write(f"data: {json_data}\n\n".encode())
            self.wfile.flush()

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

        try:
            content_length = int(self.headers["Content-Length"])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode("utf-8"))
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
            response = {"status": "success"}
            self.wfile.write(json.dumps(response).encode("utf-8"))
        except json.JSONDecodeError:
            print("Invalid JSON received")
            self.send_error(400, "Invalid JSON")


@pynvim.plugin
class Bd:
    def __init__(self, nvim):
        self.nvim = nvim
        self.q = queue.Queue()
        self.shutdown_flag = threading.Event()
        self.httpd = None
        self.server_thread = None
        self.receive_data_thread = None
        self.port = 9001

    @pynvim.command("BdStartServer", range="", sync=False)
    def start_server(self, _):
        if self.httpd is not None:
            self.nvim.out_write("Server is already running\n")
            return
        if not self.is_port_available(self.port):
            self.nvim.out_write("Port 9001 is already in use\n")
            return

        self.shutdown_flag.clear()

        self.httpd = HTTPServer(
            ("", self.port), lambda *args: SimpleHTTPRequestHandler(self.nvim, self.q, self.shutdown_flag, *args)
        )

        # 启动服务器线程
        self.server_thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.server_thread.start()

        self.nvim.out_write("Server started on port 9001\n")
        self.nvim.command("hi StatusLine guibg='green' ctermbg=2")

    @pynvim.command("BdStopServer", range="", sync=False)
    def stop_server(self, _):
        if self.httpd is None:
            self.nvim.out_write("Server is not running\n")
            return

        # 关闭服务器
        self.shutdown_flag.set()
        self.httpd.shutdown()
        self.httpd.server_close()
        self.httpd = None
        self.server_thread.join()  # 等待线程结束
        self.server_thread = None

        self.nvim.command("hi clear StatusLine")

    def is_port_available(self, port: int):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.settimeout(1)
                s.connect(("127.0.0.1", port))
                return False  # 端口被占用
            except OSError:
                return True  # 端口未被占用

    @pynvim.command("BdSendData", range="", sync=False)
    def send_data(self, _):
        # 模拟发送数据到队列
        data = {"message": "这是服务器推送的消息", "timestamp": time.time()}
        self.q.put(data)
        self.nvim.out_write("Data sent to queue\n")
