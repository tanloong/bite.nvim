#!/usr/bin/env python3

import json
import queue
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

import pynvim


class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def __init__(self, nvim, request, client_address, server):
        self.nvim = nvim
        super().__init__(request, client_address, server)

    def do_GET(self):
        if self.path == "/sse":
            # 设置 SSE 相关的头
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")  # 允许所有域
            self.end_headers()

            # 模拟实时推送数据
            counter = 0
            while True:
                counter += 1
                data = {"message": f"这是服务器推送的消息 {counter}", "timestamp": time.time()}
                # 将数据序列化为 JSON 字符串
                json_data = json.dumps(data, ensure_ascii=False)
                # SSE 数据格式：`data: <JSON 数据>\n\n`
                self.wfile.write(f"data: {json_data}\n\n".encode())
                self.wfile.flush()

        else:
            self.send_error(404, "Not Found")

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

    @pynvim.command("BdStartServer", range="", sync=False)
    def start_server(self, _):
        if self.httpd is not None:
            self.nvim.out_write("Server is already running\n")
            return

        server_address = ("", 9001)
        self.httpd = HTTPServer(server_address, lambda *args: SimpleHTTPRequestHandler(self.nvim, *args))

        # 启动服务器线程
        self.server_thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.server_thread.start()

        self.nvim.out_write("Server started on port 9001\n")

    @pynvim.command("BdStopServer", range="", sync=False)
    def stop_server(self, _):
        if self.httpd is None:
            self.nvim.out_write("Server is not running\n")
            return

        # 关闭服务器
        self.httpd.shutdown()
        self.httpd.server_close()
        self.httpd = None
        self.server_thread.join()  # 等待线程结束
        self.server_thread = None

        self.nvim.out_write("Server stopped\n")
