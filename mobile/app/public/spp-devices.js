export const SERIAL_PORT_UUID='00001101-0000-1000-8000-00805f9b34fb';

// Names and cached SDP records are hints, not proof of a module model or a live link.
// An empty Android UUID cache must not hide a usable serial module.
export function describeSppDevice(device={}) {
  const name=typeof device.name==='string'&&device.name.trim()?device.name.trim():'未命名蓝牙设备';
  const leOnly=device.type===2;
  const services=Array.isArray(device.uuids)?device.uuids.map(v=>String(v).toLowerCase()):[];
  const advertised=services.includes(SERIAL_PORT_UUID);
  const family=/hc[-_ ]?0[56]/i.test(name)?'HC 串口模块（按名称提示）':/jdy[-_ ]?31/i.test(name)?'JDY 串口模块（按名称提示）':null;
  return {name,selectable:!leOnly,advertised,
    hint:leOnly?'仅 BLE，不能连接经典蓝牙 SPP':advertised?'已缓存 SPP 串口服务':family||'串口服务将在连接时验证'};
}
