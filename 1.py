import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
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
                time.sleep(3)  # 每隔 5 秒推送一次
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

        # 获取请求体的长度
        content_length = int(self.headers["Content-Length"])
        # 读取请求体
        post_data = self.rfile.read(content_length)

        # 解析 JSON 数据
        try:
            data = json.loads(post_data.decode("utf-8"))
            print("Received JSON data:", data["1"])

            # 返回响应（可选）
            response = {"status": "success", "received_data": data}
            self.wfile.write(json.dumps(response).encode("utf-8"))
        except json.JSONDecodeError:
            print("Invalid JSON received")
            self.send_error(400, "Invalid JSON")


def run(server_class=HTTPServer, handler_class=SimpleHTTPRequestHandler, port=9001):
    server_address = ("", port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting httpd on port {port}...")
    httpd.serve_forever()


if __name__ == "__main__":
    run()
