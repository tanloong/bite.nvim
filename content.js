// content.js

console.log("content.js is running."); // 检查脚本是否加载
//var textAreas = document.querySelectorAll('textarea');

const button1 = document.createElement('button');
button1.id = '2editor';
button1.textContent = 'To Editor';

button1.style.position = 'fixed';
button1.style.top = '10px';
button1.style.left = '10px';
button1.style.padding = '10px 20px';
button1.style.backgroundColor = '#007bff';
button1.style.color = 'white';
button1.style.border = 'none';
button1.style.borderRadius = '5px';
button1.style.cursor = 'pointer';
button1.style.zIndex = '1000'; // 确保按钮在最上层


// 创建第二个按钮：Listen Editor
const button2 = document.createElement('button');
button2.id = 'listen_editor';
button2.textContent = 'Listen Editor';
button2.style.position = 'fixed';
button2.style.top = '10px';
button2.style.left = '120px'; // 放在 To Editor 按钮旁边
button2.style.padding = '10px 20px';
button2.style.backgroundColor = '#007bff';
button2.style.color = 'white';
button2.style.border = 'none';
button2.style.borderRadius = '5px';
button2.style.cursor = 'pointer';
button2.style.zIndex = '1000'; // 确保按钮在最上层

// SSE 连接状态
let eventSource = null;
let isListening = false;

// 切换 SSE 连接
button2.addEventListener('click', () => {
  if (isListening) {
    // 如果正在监听，关闭 SSE 连接
    if (eventSource) {
      eventSource.close();
      eventSource = null;
    }
    isListening = false;
    button2.textContent = 'Listen Editor';
    button2.style.backgroundColor = '#007bff';
    console.log('SSE connection closed.');
  } else {
    // 如果未监听，建立 SSE 连接
    eventSource = new EventSource('http://127.0.0.1:9001/sse');

    // 监听服务器推送的消息
    eventSource.onmessage = function (event) {
      const text = event.data; // 获取服务器推送的数据
      console.log('Received text from server:', text);
      // 如果需要将文本写入某个 textarea，可以在这里实现
      // textBox.value = text;
    };

    // 处理错误
    eventSource.onerror = function (error) {
      console.error('EventSource failed:', error);
      // 发生错误时关闭连接
      eventSource.close();
      eventSource = null;
      isListening = false;
      button2.textContent = 'Listen Editor';
      button2.style.backgroundColor = '#007bff';
    };

    isListening = true;
    button2.textContent = 'Stop Listening';
    button2.style.backgroundColor = '#dc3545';
    console.log('SSE connection established.');
  }
});

window.addEventListener('beforeunload', () => {eventSource.close();});


// 悬停效果
button1.addEventListener('mouseenter', () => {
  button1.style.backgroundColor = '#0056b3';
});
button1.addEventListener('mouseleave', () => {
  button1.style.backgroundColor = '#007bff';
});

// 将按钮添加到页面中
document.body.appendChild(button1);
document.body.appendChild(button2);

// 绑定点击事件
button1.addEventListener('click', handleInput);


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

//textAreas.forEach(textArea => {
//  textArea.addEventListener('input', handleInput);
//});


