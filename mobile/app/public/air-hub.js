export function airHub({header,icon,ready,native}){
 return `${header('空中演奏','指尖之外，自由发生。')}
 <section class="air-hub-hero">
  <span class="air-hub-eyebrow">PIANO / GESTURE GUITAR</span>
  <div class="air-hub-hands" aria-hidden="true"><span>${icon('hand',57)}</span><span>${icon('hand',57)}</span></div>
  <h2>把旋律，交给双手</h2><p>让指尖轻触悬浮琴键<br>每一个动作，都成为一段旋律。</p>
  <div class="air-hub-keys" aria-hidden="true">${Array.from({length:8},(_,i)=>`<i class="${[1,3,6].includes(i)?'short':''} ${i===2?'blue':i===5?'orange':''}"><span>${['C','C♯','D','D♯','E','F','F♯','G'][i]}</span></i>`).join('')}</div>
  <div class="air-hub-actions"><button class="air-hub-start" data-action="air-piano">${icon('play',15)}手势钢琴</button><button class="air-hub-start guitar-entry" data-action="air-guitar">${icon('music',15)}手势吉他</button></div>
  <small>指尖触键 · 双手和弦 · FPGA 实时发声</small>
 </section>
 <div class="air-hub-connection"><i class="${ready?'connected':''}"></i><span>${ready?'FPGA 已连接 · 声音由电子琴播放':native?'先在“设备”页连接电子琴，再开始演奏':'浏览器可直接试听，连接电子琴后由 FPGA 发声'}</span></div>
 <div class="air-hub-guide"><div><b>01</b><span>连接电子琴<small>吉他使用配套固件</small></span></div><div><b>02</b><span>开启摄像头<small>双手进入画面</small></span></div><div><b>03</b><span>选择乐器<small>钢琴触键／吉他手势</small></span></div></div>`;
}
