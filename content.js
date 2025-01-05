// content.js

console.log("content.js is running!"); // 检查脚本是否加载
const textAreas = document.querySelectorAll('textarea');
function handleInput(event) {
  // 在这里处理 input 事件
  const root = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(3) > div")
  var section, section_head, section_body, section_tail, label, containers
  var data = {}
  for (let i = 0; i < root.children.length; i++) {
    section = root.children[i].children[0];
    [section_head, section_body, section_tail] = section.children;
    // 序号，如1、2等，每大条一共约二三十个序号
    label = section_head.querySelector('span').textContent.trim();
    containers = section_body.querySelectorAll(".neeko-container");
    var subsection_text = {};
    containers.forEach(container => {
      let subsection = container.querySelector(".neeko-text")?.textContent.trim();
      let text = container.querySelector("textarea")?.textContent.trim();
      if (subsection) {subsection_text[subsection] = text;}
    });
    data[label] = subsection_text
  }
  const response = fetch('http://127.0.0.1:9001', {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(data)
  }).then(function (res) {
    console.log(res);
  })
}

textAreas.forEach(textArea => {
  textArea.addEventListener('input', handleInput);
});

//const eventSource = new EventSource('http://127.0.0.1:9001/sse',);
//// 监听服务器推送的消息
//eventSource.onmessage = function (event) {
//  const text = event.data; // 获取服务器推送的数据
//  console.log("Received text from server:", text);
//  textBox.value = text; // 将文本写入 textarea
//};
//
//// 处理错误
//eventSource.onerror = function (error) {
//  console.error("EventSource failed:", error);
//};
//
//window.addEventListener('beforeunload', () => {
//  if (eventSource) {eventSource.close();}
//});
