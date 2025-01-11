#!/usr/bin/env python3

import json
import logging
import queue
import socket
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler, ThreadingHTTPServer

import pynvim

from .consts import LOG_PATH

logging.basicConfig(
    format="%(asctime)s %(levelname)s [%(filename)s:%(lineno)d] pid:%(process)d tid:%(thread)d %(message)s",
    datefmt="%H:%M:%S",
    filename=LOG_PATH,
    level=logging.INFO,
)


class Server(SimpleHTTPRequestHandler):
    def __init__(self, nvim: pynvim.Nvim, mod, q: queue.Queue, request, client_address, server):
        self.nvim = nvim
        self.mod = mod
        self.q = q

        super().__init__(request, client_address, server)

    def do_GET(self):
        logging.info("do_GET requested")
        if self.path != "/sse":
            self.send_error(404, "Not Found")
            logging.warning("Invalid path: %s", self.path)

        # 设置 SSE 相关的头
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")  # 允许所有域
        self.end_headers()

        while True:
            data = self.q.get()

            if data is None:
                logging.info("从队列中读取到 None，退出当前 do_GET")
                self.wfile.write(b'data: [{"action": "close_sse"}]\n\n')
                return

            json_data = json.dumps(data, ensure_ascii=False)
            try:
                self.wfile.write(f"data: {json_data}\n\n".encode())
            except (BrokenPipeError, ConnectionResetError) as ex:
                logging.info("警告: 客户端已断开连接" + str(ex))
                self.q.put(data)
                return

    def do_OPTIONS(self):
        # 处理预检请求
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _close_sse(self):
        self.q.put(None)
        logging.info("收到关闭 SSE 请求，向队列中放入 None")
        self.wfile.write(json.dumps({"status": "ok", "msg": "已收到关闭 SSE 请求"}).encode("utf-8"))

    def _parse_data(self):
        content_length = int(self.headers["Content-Length"])
        post_data = self.rfile.read(content_length)
        try:
            data = json.loads(post_data.decode("utf-8"))
        except json.JSONDecodeError:
            return None
        return data

    def _log(self, data):
        cmd = f"vim.notify([[{data['msg']}]], vim.log.levels.{data['level']})"
        self.nvim.async_call(lambda: self.nvim.exec_lua(cmd))

    def do_POST(self):
        # 设置 CORS 头
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")  # 允许所有域
        self.end_headers()

        data = self._parse_data()
        if data is None:
            self.send_error(400, "Invalid JSON")
            return
        logging.info(data)

        if self.path == "/log":
            self._log(data)
        else:
            self.nvim.async_call(lambda: self.mod._H.callback(data))
            self.wfile.write(json.dumps({"status": "ok", "msg": "data已收到"}).encode("utf-8"))


@pynvim.plugin
class Bite:
    def __init__(self, nvim):
        self.q = queue.Queue()
        self.httpd_server = None
        self.thread_server = None
        self.port = 9001

        self.nvim = nvim
        # https://pynvim.readthedocs.io/en/latest/usage/python-plugin-api.html#lua-integration
        self.nvim.exec_lua("_bite = require 'bite'")
        self.mod = self.nvim.lua._bite

    @pynvim.function("BiteStartServer", sync=False)
    def start_server(self, *_):
        if self.httpd_server is not None:
            self.nvim.out_write("启动失败，服务已运行\n")
            logging.info("启动失败，服务已运行")
            return
        if not self._is_port_available(self.port):
            self.nvim.out_write(f"{self.port} 端口被占用")
            logging.info("%s 端口被占用", self.port)
            return

        self.httpd_server = ThreadingHTTPServer(
            ("", self.port), lambda *args: Server(self.nvim, self.mod, self.q, *args)
        )

        self.thread_server = threading.Thread(target=self.httpd_server.serve_forever, daemon=True)
        self.thread_server.start()

        self.nvim.out_write(f"服务已启动，端口 {self.port}\n")
        logging.info("服务已启动，端口 %s", self.port)

        self.nvim.command("hi StatusLine guibg='green' ctermbg=2")

    @pynvim.function("BiteStopServer", sync=False)
    def stop_server(self, *_):
        if self.httpd_server is None:
            self.nvim.out_write("关闭服务失败，服务未运行\n")
            logging.info("关闭服务失败，服务未运行")
            return

        self.q.put(None)  # tell thread http server to exit current while loop in do_GET
        logging.info("向队列中放入None来告诉服务器退出当前do_GET")
        self.httpd_server.shutdown()
        self.httpd_server.server_close()
        self.httpd_server = None
        self.thread_server.join()  # 等待线程结束
        self.thread_server = None

        self.nvim.out_write("服务已停止\n")
        logging.info("服务已停止")

        self.nvim.command("hi clear StatusLine")

    @pynvim.function("BiteToggleServer", sync=False)
    def do_toggle_server(self, *_):
        if self.httpd_server is None:
            self.start_server()
        else:
            self.stop_server()

    @pynvim.function("BiteSendData", sync=False)
    def send_data(self, data: dict):
        if self.httpd_server is None:
            self.nvim.out_write("数据发送失败，服务未在运行\n")
            logging.info("数据发送失败，服务未在运行")
            return

        self.q.put(data)

    def _is_port_available(self, port: int):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.settimeout(1)
                s.connect(("127.0.0.1", port))
                return False  # 端口被占用
            except OSError:
                return True  # 端口未被占用
