# JW 历史协议测试向量

`jw_history_vectors_v1.json` 提供 13 组独立的历史记录预期值，覆盖步数、睡眠、心率/温度、血压、血氧、运动、HRV、压力、代谢和 readiness。它们是离线测试输入，不能作为真机数据或已完成产品验收的证明。

记录载荷来自 V101 固件基线 `91dc0a6` 的 portable C packer、传统 bitfield 结构及运动序列化块，输入和预期字段独立指定；不得用待测 Dart decoder 反算 expected。源文件与生成结果的 SHA-256 保留在 JSON provenance 中。L1/L2 由独立实现组装，CRC16/ARC 校验向量为 `123456789 -> BB3D`。fixture 的 L1 noAck 选择不约束客户端出站标志。

时间基数为本地 `2000-01-01`，测试日期为 `2026-10-04`：10:15:00 对应 844424100；兼容 Unix offset 为 946656000，HRV 线上值为 1791080100。原始 hex 是权威输入；expected 中的 null 表示质量标志决定的缺失值，不能转换为 0。

运行相关校验：

```powershell
flutter test --no-pub test/services/jw/jw_history_decoder_test.dart
```

同目录的 configuration、readonly 和 observation 向量分别供配置、只读查询及观察接口测试使用。修改协议向量时须保持原始载荷、预期字段和独立来源一致。
