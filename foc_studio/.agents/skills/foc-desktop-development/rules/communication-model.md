# Backend Communication Model（后端通信模型）

## Rule: All QObject-based modules must communicate via Qt Signals/Slots.（所有QObject模块必须通过Qt信号/槽进行通信）  
Applies to:
- Transport Layer
- Service Layer
- Backend Facade

Does NOT apply to:
- Protocol Layer (pure functions only)

## Signal-Driven Architecture（信号驱动架构）
Backend modules must follow:
Event-driven model, not direct method coupling.
Prohibited:
- Service directly calling transport.write()
- Transport directly calling service method
- Cross-module method calls after initialization

Allowed:
- Signal → Slot connections only

Example:
Transport.dataReceived → Service.onBytesReceived
Service.speedUpdated → BackendFacade.speedUpdated
BackendFacade.speedUpdated → QML

## Threading Rule（线程规则）
- All signals must be Qt-safe（所有信号必须是 Qt 安全的）
- No blocking operations（无阻塞操作）
- If heavy computation is added later → move to worker thread（如果以后增加重计算 → 移动到工作线程）

## Strict Ownership Model（严格的所有权模型）
- Transport owns QSerialPort（Transport 拥有 QSerialPort）
- Service owns buffer（Service 拥有缓冲区）
- Protocol owns nothing（协议层不拥有任何资源）
- BackendFacade owns service instances（BackendFacade 拥有服务实例）

No shared mutable objects across layers.
