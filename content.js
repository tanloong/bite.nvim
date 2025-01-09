// content.js

console.log("content.js is running."); // 检查脚本是否加载

// 创建第二个按钮：Listen Editor
const button2 = document.createElement('button');
button2.id = 'listen_editor';
button2.textContent = 'Listen Editor';
button2.style.position = 'fixed';
button2.style.top = '10px';
button2.style.left = '10px'; // 放在 To Editor 按钮旁边
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

function close_sse() {
  eventSource.close();
  eventSource = null;
  isListening = false;
  button2.textContent = 'Listen Editor';
  button2.style.backgroundColor = '#007bff';

  console.log('SSE connection closed.');
}

function notify_server_to_end_sse_session() {
  fetch('http://127.0.0.1:9001/close_sse', {
    method: 'POST'
  }).then(function (res) {
    console.log(res);
  })
}

// 切换 SSE 连接
button2.addEventListener('click', () => {
  if (isListening) {
    // 如果正在监听，关闭 SSE 连接
    if (eventSource) {
      close_sse();
      notify_server_to_end_sse_session()
    }
  } else {
    // 如果未监听，建立 SSE 连接
    eventSource = new EventSource('http://127.0.0.1:9001/sse');

    // 监听服务器推送的消息
    eventSource.onmessage = function (event) {
      console.log(event.data);
      let data = JSON.parse(event.data)[0]
      switch (data["action"]) {//{{{
        case "play":
          play(data);
          break;
        case "toggle":
          toggle();
          break;
        case "back":
          back();
          break;
        case "put":
          editor2browser(data);
          break;
        case "init_transcripts":
          init_transcripts();
          break;
        case "push_slice":
          push_slice(data);
          break;
        case "fetch_slice":
          fetch_slice(data);
          break;
        case "close_sse":
          close_sse();
          break;
        case "fetch_content":
          fetch_content(data);
          break;
        default:
          console.log('Unknown action:', data["action"]);
          break;
      };
      editor2browser(data);
    }//}}}

    // 处理错误
    eventSource.onerror = function (error) {
      console.error('EventSource failed:', error);
      // 发生错误时关闭连接
      close_sse();
    };

    isListening = true;
    button2.textContent = 'Stop Listening';
    button2.style.backgroundColor = '#dc3545';
    console.log('SSE connection established.');
  }
});

window.addEventListener('beforeunload', () => {if (eventSource) eventSource.close();});

// 将按钮添加到页面中
document.body.appendChild(button2);

const inputEvent = new Event('input', {
  bubbles: true,    // 事件是否冒泡
  cancelable: true  // 事件是否可以取消
});
const clickEvent = new Event('click', {
  bubbles: true,    // 事件是否冒泡
  cancelable: true  // 事件是否可以取消
});


function editor2browser(data) {
  let root = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(3) > div")
  var section, subsection, section_head, section_body, section_tail, label, containers, elem
  // 创建一个 input 事件
  for (let i = 0; i < root.children.length; i++) {
    section = root.children[i].children[0];
    [section_head, section_body, section_tail] = section.children;
    label = section_head.querySelector('span').textContent.trim();
    if (label in data) { // find target section
      containers = section_body.querySelectorAll(".neeko-container");
      containers.forEach(container => {
        if (container.querySelectorAll(".neeko-text").length !== 2) {return;}

        subsection = container.querySelector(".neeko-text")?.textContent.trim();
        if (subsection in data[label]) { // find target subsection
          elem = container.querySelector("textarea");
          if (typeof elem == 'undefined' || elem == null) {return;}
          elem.value = data[label][subsection];
          // 触发输入事件，模拟手输
          elem.dispatchEvent(inputEvent);
        }
      });
    }
  };
}

function play(data) {
  //let wave = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.wave-warper > div > wave");
  //let region = wave.querySelector(`region[data-id="${data['section']}"]`);
  //console.log(region);
  //region.dispatchEvent(clickEvent);
  //let btns = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play")
  //let btn = btns.querySelector("[id^='play-slice_svg']")
  //if (btn === null) {
  //  btn = btns.querySelector("svg:nth-child(4)")
  //}
  //btn.dispatchEvent(clickEvent);

  let root = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(3) > div")
  var section, subsection, section_head, section_body, section_tail, label, containers, elem
  for (let i = 0; i < root.children.length; i++) {
    section = root.children[i].children[0];
    [section_head, section_body, section_tail] = section.children;
    label = section_head.querySelector('span').textContent.trim();
    if (label === data["section"]) {
      section_head.querySelector("button").dispatchEvent(clickEvent);
      break;
    }
  }
}

function toggle() {
  let btn = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play > svg:nth-child(4)")
  btn.dispatchEvent(clickEvent)
}

function back() {
  let btn = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play > svg:nth-child(2)")
  btn.dispatchEvent(clickEvent)
}

function init_transcripts() {
  let root = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(3) > div")
  var section, subsection, section_head, section_body, section_tail, label, containers, elem, btn
  for (let i = 0; i < root.children.length; i++) {
    section = root.children[i].children[0];
    [section_head, section_body, section_tail] = section.children;
    btn = section_body.querySelector("button")
    btn.dispatchEvent(clickEvent)
  }
}

function fetch_content(event) {
  let root = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(3) > div")
  let wave = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.wave-warper > div > wave");

  var section, subsection, section_head, section_body, section_tail, label, containers, elem
  let data = {}
  for (let i = 0; i < root.children.length; i++) {
    // 1. 收集文本框内容
    section = root.children[i].children[0];
    [section_head, section_body, section_tail] = section.children;
    //  // 序号，如1、2等，每大条一共约二三十个序号
    label = section_head.querySelector('span').textContent.trim();
    containers = section_body.querySelectorAll(".neeko-container");
    var subsection_text = {};
    // containers.forEach(c => {console.log(c.querySelectorAll(".neeko-text").length)}) 返回
    // 3个12 (抛弃 3 个只读文本框，模型识别文本、模型识别文本和顺滑、模型预翻译文本)、6个2 (这 6 个才是需要的)、2个0
    containers.forEach(container => {
      if (container.querySelectorAll(".neeko-text").length !== 2) {return;}

      subsection = container.querySelector(".neeko-text")?.textContent.trim();
      if (typeof subsection == 'undefined' || subsection == null) {return;}

      elem = container.querySelector("textarea")
      if (typeof elem == 'undefined' || elem == null) {return;}

      let text = elem.textContent.trim();
      subsection_text[subsection] = text;
    });
    // 2. 收集起止时间
    let region = wave.querySelector(`region[data-id="${i + 1}"`);
    let start = region.querySelector("handle.waver-handle.waver-handle-start").getBoundingClientRect().x;
    let end = region.querySelector("handle.waver-handle.waver-handle-end").getBoundingClientRect().x;
    subsection_text['start'] = start;
    subsection_text['end'] = end;
    // 3. 保存到 data
    data[label] = subsection_text
  }
  const response = fetch('http://127.0.0.1:9001/fetch_content', {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(data)
  }).then(function (res) {
    console.log(res);
  })
}

function fetch_slice() {
  let data = {}
  let wave = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.wave-warper > div > wave");
  let regions = wave.querySelectorAll("region");
  for (let i = 0; i < regions.length; i++) {
    let region = regions[i]
    let start = region.querySelector("handle.waver-handle.waver-handle-start").getBoundingClientRect().x;
    let end = region.querySelector("handle.waver-handle.waver-handle-end").getBoundingClientRect().x;
    data[String(i + 1)] = {start: start, end: end}
  }
  fetch('http://127.0.0.1:9001/fetch_slice', {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(data)
  }).then(function (res) {
    console.log(res);
  })
}

function push_slice(data) {
  let section = data['section'];
  let edge = data['edge'];

  let wave = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.wave-warper > div > wave");
  let region = wave.querySelector(`region[data-id="${section}"]`);
  let handle = region.querySelector(`handle.waver-handle.waver-handle-${edge}`);
  let rect_handle = handle.getBoundingClientRect();

  let x1 = rect_handle.x
  let y1 = rect_handle.y
  let x2 = Number(data["x"])
  let y2 = y1
  // 创建鼠标按下事件
  let mousedownEvent = new MouseEvent('mousedown', {bubbles: true, cancelable: true, clientX: x1, clientY: y1});
  // 创建鼠标移动事件
  let mousemoveEvent = new MouseEvent('mousemove', {bubbles: true, cancelable: true, clientX: x2, clientY: y2});
  // 创建鼠标松开事件
  let mouseupEvent = new MouseEvent('mouseup', {bubbles: true, cancelable: true, clientX: x2, clientY: y2});
  handle.dispatchEvent(mousedownEvent); handle.dispatchEvent(mousemoveEvent); handle.dispatchEvent(mouseupEvent)
}
