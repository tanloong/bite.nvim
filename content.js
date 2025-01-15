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

  sendNotification('编辑器断连')
  console.log('SSE connection closed.');
}

function notify_server_to_end_sse_session() {
  fetch('http://127.0.0.1:9001/close_sse', {
    method: 'POST'
  }).then(function (res) {
    console.log(res);
  })
}

function toggle_sse() {
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
          back(data);
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
        case "fetch_progress":
          fetch_progress(data);
          break;
        case "speed":
          speed(data);
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
      console.log('EventSource failed:', error);
      // 发生错误时关闭连接
      close_sse();
    };

    isListening = true;
    button2.textContent = 'Stop Listening';
    button2.style.backgroundColor = '#dc3545';
    sendNotification("已连接到编辑器")
    console.log('SSE connection established.');
  }
}

// 切换 SSE 连接
button2.addEventListener('click', toggle_sse);
window.addEventListener('beforeunload', () => {if (eventSource) eventSource.close();});

// 将按钮添加到页面中
document.body.appendChild(button2);
// CTRL+SHIFT+H
document.addEventListener('keydown', function (event) {
  if (event.ctrlKey && event.shiftKey && event.key === 'H') {
    event.preventDefault();
    toggle_sse();
  }
});

const inputEvent = new Event('input', {
  bubbles: true,    // 事件是否冒泡
  cancelable: true  // 事件是否可以取消
});
const clickEvent = new Event('click', {
  bubbles: true,    // 事件是否冒泡
  cancelable: true  // 事件是否可以取消
});

function editor2browser(data) {
  let root = get_root()
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

function nvim_log(msg, level = "INFO") {
  fetch('http://127.0.0.1:9001/log', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({msg: msg, level: level})
  })
}

function play(data) {
  let root = get_root()
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
  let btn = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play > svg:nth-child(3)")
  if (btn === null) {
    btn = document.querySelector("body > div:nth-child(10) > div.arco-modal-wrapper.arco-modal-wrapper-align-center > div > div > div > div > div > div.side-wrap_HG1nN9CV > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play > svg:nth-child(3)")
  }
  btn.dispatchEvent(clickEvent)
}

function back(data) {
  let btn = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play > svg:nth-child(2)")
  if (btn === null) {
    btn = document.querySelector("body > div:nth-child(10) > div.arco-modal-wrapper.arco-modal-wrapper-align-center > div > div > div > div > div > div.side-wrap_HG1nN9CV > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.btns-play > svg:nth-child(2)")
  }
  let count = Number(data['count'])
  for (let i = 1; i <= count; i++) {
    btn.dispatchEvent(clickEvent)
  }
  nvim_log(`已后退${count}秒`);
}

function init_transcripts() {
  let root = get_root()
  var section, subsection, section_head, section_body, section_tail, label, containers, elem, btn
  for (let i = 0; i < root.children.length; i++) {
    section = root.children[i].children[0];
    [section_head, section_body, section_tail] = section.children;
    btn = section_body.querySelector("button")
    btn.dispatchEvent(clickEvent)
  }
  nvim_log("英文转写已初始化");
  fetch_content();
}

function get_root() {
  let root = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(3) > div")
  if (root === null) {
    // 质检页面，如 https://aidp.bytedance.com/operation/task-v2/7455241299210948352/node/14/package/item/7460090930487201573?status=0&query=&page=1
    root = document.querySelector("body > div:nth-child(10) > div.arco-modal-wrapper.arco-modal-wrapper-align-center > div > div > div > div > div > div.side-wrap_HG1nN9CV > div > div > div > div > div > div:nth-child(3) > div")
  }
  return root
}
function get_wave() {
  let wave = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.wave-warper > div > wave");
  if (wave === null) {
    // 质检页面，如 https://aidp.bytedance.com/operation/task-v2/7455241299210948352/node/14/package/item/7460090930487201573?status=0&query=&page=1
    wave = document.querySelector("body > div:nth-child(10) > div.arco-modal-wrapper.arco-modal-wrapper-align-center > div > div > div > div > div > div.side-wrap_HG1nN9CV > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.wave-warper > div > wave")
  }
  return wave
}

function fetch_content(data) {
  let root = get_root()
  let wave = get_wave()
  var section, subsection, section_head, section_body, section_tail, label, containers, elem
  let ret = {}
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
    ret[label] = subsection_text
  }

  ret["callback"] = data["callback"]
  fetch('http://127.0.0.1:9001/fetch_content', {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(ret)
  }).then(function (res) {
    console.log(res);
  })
}

function _fetch_slice() {
  let ret = {}

  let wave = get_wave()
  let regions = wave.querySelectorAll("region");
  for (let i = 0; i < regions.length; i++) {
    let region = regions[i]
    let start = region.querySelector("handle.waver-handle.waver-handle-start").getBoundingClientRect().x;
    let end = region.querySelector("handle.waver-handle.waver-handle-end").getBoundingClientRect().x;
    start = String(start);
    end = String(end);
    ret[String(i + 1)] = {start: start, end: end}
  }
  return ret
}

function fetch_slice(data) {
  let ret = _fetch_slice()
  ret["callback"] = data["callback"]
  fetch('http://127.0.0.1:9001/fetch_slice', {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(ret)
  }).then(function (res) {
    console.log(res);
  })
}

function fetch_progress(data) {
  let wave = get_wave()
  let x = String(wave.getBoundingClientRect().right);
  let ret = {x: x, callback: data["callback"]}
  fetch('http://127.0.0.1:9001/fetch_progress', {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(ret)
  }).then(function (res) {
    console.log(res);
  })
}

function push_slice(data) {
  let section = data['section'];
  let edge = data['edge'];
  let section_edge_pos1 = data['section_edge_pos'];
  let section_edge_pos2 = _fetch_slice();

  // 如果在上一次fetch_slice之后，播放过音频，位置时间比会变化，导致要设置的边界位置与期望时间点不一致，
  // 这里获取最新的边界位置判断是否有变，若是则要求按新的位置重新设置。
  let ok = false;
  for (let section in section_edge_pos1) {
    console.log(`section_edge_pos1\nstart: ${section_edge_pos1[section]["start"]}, end: ${section_edge_pos1[section]["end"]}\n\nsection_edge_pos2\nstart: ${section_edge_pos2[section]["start"]}, end: ${section_edge_pos2[section]["end"]}`);
    if (
      section_edge_pos1[section]["start"] === section_edge_pos2[section]["start"] &&
      section_edge_pos1[section]["end"] === section_edge_pos2[section]["end"]
    ) {ok = true; break;}
  }
  if (!ok) {nvim_log("设置边界失败，原位置时间比已变更，请重新设置", "ERROR"); fetch_slice({callback: "callback_receive_slice"}); return;}

  let wave = get_wave()
  let region = wave.querySelector(`region[data-id="${section}"]`);
  let handle = region.querySelector(`handle.waver-handle.waver-handle-${edge}`);
  let rect_handle = handle.getBoundingClientRect();

  let x1 = rect_handle.x
  let y1 = rect_handle.y
  let x2 = Number(data["x"])
  let y2 = y1
  // 创建鼠标按下、移动、松开事件
  let mousedownEvent = new MouseEvent('mousedown', {bubbles: true, cancelable: true, clientX: x1, clientY: y1});
  let mousemoveEvent = new MouseEvent('mousemove', {bubbles: true, cancelable: true, clientX: x2, clientY: y2});
  let mouseupEvent = new MouseEvent('mouseup', {bubbles: true, cancelable: true, clientX: x2, clientY: y2});
  handle.dispatchEvent(mousedownEvent); handle.dispatchEvent(mousemoveEvent); handle.dispatchEvent(mouseupEvent)
  nvim_log(`Set section ${section} ${edge} as ${x2}`)
}

function speed(data) {
  let offset = Number(data["offset"])
  let combobox = document.querySelector("#conbination-wrap > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.container-speed > div.arco-select.arco-select-single.arco-select-size-default")
  if (combobox === null) {
    // 质检页面
    combobox = document.querySelector("body > div:nth-child(10) > div.arco-modal-wrapper.arco-modal-wrapper-align-center > div > div > div > div > div > div.side-wrap_HG1nN9CV > div > div > div > div > div > div:nth-child(2) > div > div > div > div:nth-child(2) > div > div.container-operation > div.container-speed > div.arco-select.arco-select-single.arco-select-size-default")
  }
  let before = combobox.querySelector("span[class='arco-select-view-value']").textContent.trim()
  let after = null

  // 点开下拉菜单
  let popup = document.querySelector("#arco-select-popup-0 > div > div")
  if (popup === null) {
    combobox.dispatchEvent(clickEvent);
    popup = document.querySelector("#arco-select-popup-0 > div > div")
  }
  // 质检页面
  if (popup === null) {popup = document.querySelector("#arco-select-popup-4 > div > div")}
  if (popup === null) {nvim_log("倍速失败，找不到下拉菜单", "ERROR"); return };

  let choices = popup.querySelectorAll("li")
  for (let i = 1; i <= choices.length; i++) {
    if (choices[i - 1].textContent.trim() === before) {
      after = i + offset;
      break;
    }
  }
  if (after === null) {nvim_log("倍速失败，找不到当前速度", "ERROR"); return };
  if (after < 1) {nvim_log(`倍速失败，${before}已最小`, "ERROR"); return };
  if (after > choices.length) {nvim_log(`倍速失败，${before}已最大`, "ERROR"); return };

  // 点击目标倍速，通知 nvim
  let li = popup.querySelector(`li:nth-child(${after})`)
  li.dispatchEvent(clickEvent);
  nvim_log(li.textContent.trim())

  // 若下拉菜单未关闭，将其关闭
  popup = document.querySelector("#arco-select-popup-0 > div > div")
  if (popup !== null) {combobox.dispatchEvent(clickEvent);};
  popup = document.querySelector("#arco-select-popup-4 > div > div")
  if (popup !== null) {combobox.dispatchEvent(clickEvent);};
}

//////////////////////////////////NOTIFICATION//////////////////////////////////

// https://segmentfault.com/a/1190000041982599
function sendNotification(title, body, icon, callback) {
  // 先检查浏览器是否支持
  if (!('Notification' in window)) {
    // IE浏览器不支持发送Notification通知!
    return;
  }

  if (Notification.permission === 'denied') {
    // 如果用户已拒绝显示通知
    return;
  }

  if (Notification.permission === 'granted') {
    //用户已授权，直接发送通知
    notify();
  } else {
    // 默认，先向用户询问是否允许显示通知
    Notification.requestPermission(function (permission) {
      // 如果用户同意，就可以直接发送通知
      if (permission === 'granted') {
        notify();
      }
    });
  }

  function notify() {
    let notification = new Notification(title, {
      icon: icon,
      body: body
    });
    notification.onclick = function () {
      callback && callback();
      //console.log('单击通知框')
    }
    //notification.onclose = function () {
    //  console.log('关闭通知框');
    //};

    // 设置1秒后自动关闭通知
    setTimeout(() => {
      notification.close();
    }, 1000); // 1000毫秒 = 1秒
  }
}
